#!/bin/bash

# Load functions from ceph_functions.sh and ceph_vars.sh
source ceph_vars.sh
source ceph_functions.sh

read -p "Do you want to cleanup existing Ceph cluster? (yes/no): " user_confirmation
if [[ "$user_confirmation" == "yes" ]]; then
    CLEANUP_CEPH="true"
else
    CLEANUP_CEPH="false"
fi

# Start setup
echo "Starting Ceph cluster setup..."

# Check for existing SSH key and generate if it does not exist
if [ ! -f "$SSH_KEY" ]; then
    echo "Generating SSH key..."
    ssh-keygen -f "$SSH_KEY" -N '' # No passphrase
    echo "SSH key generated successfully."
else
    echo "SSH key already exists. Skipping generation."
fi

# Copy SSH key to each host in the group
for host in "${HOST_GROUP[@]}"; do
    echo "Copying SSH key to $host..."
    ssh-copy-id -i "${SSH_KEY}.pub" "$host" && \
    echo "SSH key copied successfully to $host." || \
    echo "Failed to copy SSH key to $host."
done

# Cleanup existing Ceph setup if confirmed
cleanup_ceph_cluster

# Wipe OSD devices
echo "Wiping OSD devices on $OSD_HOST..."
for device in ${OSD_DEVICES[@]}; do
    if ssh $OSD_HOST "sudo wipefs --all /dev/$device"; then
        echo "Wiped $device successfully."
    else
        echo "Failed to wipe $device."
    fi
done

# Run cephadm-ansible preflight playbook
echo "Running cephadm-ansible preflight setup..."
run_ansible_playbook $CEPHADM_PREFLIGHT_PLAYBOOK ""

# Create a temporary Ceph configuration file for initial settings
TEMP_CONFIG_FILE=$(mktemp)
echo "[global]
osd crush chooseleaf type = 0
osd_pool_default_size = 1" > $TEMP_CONFIG_FILE

# Bootstrap the Ceph cluster
MON_IP="${HOST_IPS[0]}"  # Select the first IP address for MON_IP
echo "Bootstrapping Ceph cluster with MON_IP: $MON_IP"
add_to_known_hosts $MON_IP
sudo cephadm bootstrap --mon-ip $MON_IP --cluster-network $CLUSTER_NETWORK --ssh-user $SSH_USER -c $TEMP_CONFIG_FILE --allow-overwrite --log-to-file
rm -f $TEMP_CONFIG_FILE

# Distribute Cephadm SSH keys to all hosts
echo "Distributing Cephadm SSH keys to all hosts..."
run_ansible_playbook $CEPHADM_DISTRIBUTE_SSHKEY_PLAYBOOK \
                "-e cephadm_ssh_user=$SSH_USER -e admin_node=$ADMIN_HOST -e cephadm_pubkey_path=$SSH_KEY.pub"

# Fetch FSID of the Ceph cluster
FSID=$(sudo ceph fsid)
echo "Ceph FSID: $FSID"

# Add and label hosts in the Ceph cluster
echo "Adding and labeling hosts in the cluster..."
for i in "${!HOST_GROUP[@]}"; do
    host="${HOST_GROUP[$i]}"
    ip="${HOST_IPS[$i]}"

    # Add the public key of the Ceph cluster to each host
    ssh-copy-id -f -i /etc/ceph/ceph.pub $host

    # Add host to Ceph cluster
    sudo ceph orch host add $host $ip

    # Label host accordingly and verify
    if [[ "$host" == "$ADMIN_HOST" ]]; then
        # Apply 'mon' and 'mgr' labels to the admin host
        sudo ceph orch host label add $host mon && \
        sudo ceph orch host label add $host mgr && \
        echo "Labels 'mon' and 'mgr' added to $host." || \
        echo "Failed to add labels to $host."
    elif [[ "$host" == "$OSD_HOST" ]]; then
        # Apply 'osd' label to the OSD host
        sudo ceph orch host label add $host osd && \
        echo "Label 'osd' added to $host." || \
        echo "Failed to add label to $host."
    else
        # Skip labeling for other hosts or handle differently
        echo "No specific labels to apply for $host."
    fi

    # Verify the labels have been applied
    labels=$(sudo ceph orch host ls --format=json | jq -r '.[] | select(.hostname == "'$host'") | .labels[]')
    echo "Current labels for $host: $labels"
done

# Prepare and add OSDs
sleep 60
add_osds_and_wait

# Check Ceph cluster status and OSD creation
check_osd_creation

echo "Ceph cluster setup and client configuration completed successfully."
