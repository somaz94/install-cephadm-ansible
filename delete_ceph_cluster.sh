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
