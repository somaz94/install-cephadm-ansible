#!/bin/bash

# Define variables(Modify)
SSH_KEY="/home/somaz/.ssh/id_rsa_ansible" # SSH KEY Path
INVENTORY_FILE="inventory.ini" # Inventory Path
CEPHADM_PREFLIGHT_PLAYBOOK="cephadm-preflight.yml"
CEPHADM_CLIENTS_PLAYBOOK="cephadm-clients.yml"
CEPHADM_DISTRIBUTE_SSHKEY_PLAYBOOK="cephadm-distribute-ssh-key.yml"
HOST_GROUP=(test-server test-server-agent test-server-storage) # All host group
ADMIN_HOST="test-server" # Admin host name
OSD_HOST="test-server-storage" # Osd host name
HOST_IPS=("10.77.101.47" "10.77.101.43" "10.77.101.48") # Corresponding IPs and Select the first IP address for MON_IP
OSD_DEVICES=("sdb" "sdc" "sde") # OSD devices, without /dev/ prefix
CLUSTER_NETWORK="10.77.101.0/24" # Cluster network CIDR
SSH_USER="somaz" # SSH user
CLEANUP_CEPH="false" # Ensure this is reset based on user input
