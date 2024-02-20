#!/bin/bash

stop_all_ceph_services() {
    echo "Stopping all Ceph services..."
    local services=$(sudo ceph orch ls --format=json | jq -r '.[].service_name')
    for service in $services; do
        # Skip attempting to stop 'mgr', 'mon', and 'osd' services
        if [[ "$service" != "mgr" && "$service" != "mon" && "$service" != "osd" ]]; then
            echo "Stopping $service..."
            sudo ceph orch stop $service
        else
            echo "Skipping $service (cannot be stopped directly)."
        fi
    done
}

remove_osds_and_cleanup_lvm() {
    echo "Checking for existing OSDs and cleaning them up..."
    osd_ids=$(sudo ceph osd ls)
    if [ -z "$osd_ids" ]; then
        echo "No OSDs to remove."
    else
        for osd_id in $osd_ids; do
            echo "Removing OSD.$osd_id..."
            # Stop the OSD
            sudo ceph orch daemon stop osd.$osd_id
            sleep 10
            # Mark the OSD out
            sudo ceph osd out $osd_id
            sleep 10
            # Remove the OSD
            sudo ceph osd rm $osd_id
            # Wait a bit to ensure the OSD is fully purged
            sleep 10
        done
    fi

    echo "Cleaning up LVM volumes on $OSD_HOST..."
    ssh $OSD_HOST <<'EOF'
        sudo lvscan | awk '/ceph/ {print $2}' | xargs -I{} sudo lvremove -y {}
        sleep 5
        sudo vgscan | awk '/ceph/ {print $4}' | xargs -I{} sudo vgremove -y {}
        sleep 5
        sudo pvscan | grep '/dev/sd' | awk '{print $2}' | xargs -I{} sudo pvremove -y {}
EOF
}

# Function to cleanup existing Ceph cluster
cleanup_ceph_cluster() {
    if [ "$CLEANUP_CEPH" == "true" ]; then
        echo "Initiating Ceph cluster cleanup..."

        # Stop all Ceph services managed by cephadm
        stop_all_ceph_services

        # Wait a bit to ensure all services are stopped
        sleep 10

        # Remove OSDs and clean up LVM before removing the cluster
        remove_osds_and_cleanup_lvm

        # Proceed with cluster cleanup
        if sudo test -d /var/lib/ceph; then
            echo "Cleaning up existing Ceph cluster..."
            sudo cephadm rm-cluster --fsid=$(sudo ceph fsid) --force
            echo "Ceph cluster removed successfully."
        else
            echo "No existing Ceph cluster found to clean up."
        fi

        # Dynamically determine whether to use Docker or Podman for container cleanup
        echo "Removing any leftover Ceph containers..."
        for host in "${HOST_GROUP[@]}"; do
            echo "Cleaning up containers on $host..."
            ssh "$SSH_USER@$host" '
            if command -v docker &> /dev/null; then
                container_runtime="docker"
            elif command -v podman &> /dev/null; then
                container_runtime="podman"
            else
                echo "No container runtime (Docker or Podman) found on '"$host"'. Skipping container cleanup."
                exit 1 # Exit the SSH command with an error status
            fi

            # Remove Ceph containers using the detected container runtime
            sudo $container_runtime ps -a | grep ceph | awk '"'"'{print $1}'"'"' | xargs -I {} sudo $container_runtime rm -f {}
            '
            if [ $? -ne 0 ]; then
                echo "Error cleaning up containers on $host"
            else
                echo "Leftover Ceph containers removed successfully on $host."
            fi
        done
    else
        echo "Skipping Ceph cluster cleanup as per user's choice."
    fi
}

# Function to execute ansible playbook
run_ansible_playbook() {
    playbook=$1
    extra_vars=$2
    ansible-playbook -i $INVENTORY_FILE $playbook $extra_vars --become
    if [ $? -ne 0 ]; then
        echo "Execution of playbook $playbook failed. Exiting..."
        exit 1
    fi
}

# Function to add SSH key to known hosts
add_to_known_hosts() {
    host_ip=$1
    ssh-keyscan -H $host_ip >> ~/.ssh/known_hosts
}

# Function to add OSDs and wait for them to be ready
add_osds_and_wait() {
    for device in "${OSD_DEVICES[@]}"; do
        echo "Attempting to add OSD on /dev/$device..."
        # Attempt to add an OSD and capture the output
        output=$(sudo /usr/bin/ceph orch daemon add osd $OSD_HOST:/dev/$device 2>&1)
        retval=$?

        if [ $retval -ne 0 ]; then
            echo "Command to add OSD on /dev/$device failed. Please check logs for errors. Output: $output"
            continue # If the command failed, move to the next device.
        fi

        # Since OSD ID might not be immediately available, wait a few seconds before checking
        echo "Waiting a moment for OSD to be registered..."
        sleep 10

        # Attempt to find the OSD ID using the ceph osd tree command, assuming it will be listed there if creation was successful
        osd_id=$(sudo /usr/bin/ceph osd tree | grep -oP "/dev/$device.*osd.\K[0-9]+")

        if [ -z "$osd_id" ]; then
            echo "Unable to find OSD ID for /dev/$device. It might take a moment for the OSD to be visible in the cluster."
        else
            echo "OSD with ID $osd_id has been added on /dev/$device."
        fi

        echo "Monitoring the readiness of OSD.$osd_id on /dev/$device..."

        # Initialize success flag
        success=false
        for attempt in {1..12}; do
            # Directly check if the OSD is "up" and "in"
            if sudo /usr/bin/ceph osd tree | grep "osd.$osd_id" | grep -q "up" && sudo /usr/bin/ceph osd tree | grep "osd.$osd_id"; then
                echo "OSD.$osd_id on /dev/$device is now ready."
                success=true
                break
            else
                echo "Waiting for OSD.$osd_id on /dev/$device to become ready..."
                sleep 10
            fi
        done

        if ! $success; then
            echo "Timeout waiting for OSD.$osd_id on /dev/$device to become ready. Please check Ceph cluster status."
        fi
    done
}


# Function to check OSD creation and cluster status
check_osd_creation() {
    echo "Checking Ceph cluster status and OSD creation..."
    sudo ceph -s
    sudo ceph osd tree
}

# Add and label hosts in the Ceph cluster
add_host_and_label() {
  echo "Adding and labeling hosts in the cluster..."
  for i in "${!HOST_GROUP[@]}"; do
      host="${HOST_GROUP[$i]}"
      ip="${HOST_IPS[$i]}"

      # Add the public key of the Ceph cluster to each host
      ssh-copy-id -f -i /etc/ceph/ceph.pub $host

      # Add host to Ceph cluster
      sudo ceph orch host add $host $ip

      # Apply 'mon' and 'mgr' labels to the admin host
      if [[ "$host" == "$ADMIN_HOST" ]]; then
          sudo ceph orch host label add $host mon && \
          sudo ceph orch host label add $host mgr && \
          echo "Labels 'mon' and 'mgr' added to $host."
      fi

      # Apply 'osd' label to the OSD host
      if [[ "$host" == "$OSD_HOST" ]]; then
          sudo ceph orch host label add $host osd && \
          echo "Label 'osd' added to $host."
      fi

      # Apply '_no_schedule' label only to hosts that are neither ADMIN_HOST nor OSD_HOST
      if [[ "$host" != "$ADMIN_HOST" ]] && [[ "$host" != "$OSD_HOST" ]]; then
          sudo ceph orch host label add $host _no_schedule && \
          echo "Label '_no_schedule' added to $host."
      fi

      # Verify the labels have been applied
      labels=$(sudo ceph orch host ls --format=json | jq -r '.[] | select(.hostname == "'$host'") | .labels[]')
      echo "Current labels for $host: $labels"
  done
}

# Function to label all OSD hosts with '_no_schedule'
label_osd_hosts_no_schedule() {
    echo "Applying '_no_schedule' label to all OSD hosts..."
    # Assuming OSD_HOST could be a single host or an array of hosts
    # Convert OSD_HOST to an array if it's not already one
    if [[ ! "${OSD_HOST[@]}" ]]; then
        osd_hosts=($OSD_HOST) # Convert single host to an array
    else
        osd_hosts=("${OSD_HOST[@]}") # Use the array as is
    fi

    for osd_host in "${osd_hosts[@]}"; do
        sudo ceph orch host label add $osd_host _no_schedule && \
        echo "Label '_no_schedule' added to $osd_host."
    done
}