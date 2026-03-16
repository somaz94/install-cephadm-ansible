# install-cephadm-ansible

[![License](https://img.shields.io/github/license/somaz94/install-cephadm-ansible)](LICENSE)

Ansible playbook for automating Ceph cluster deployment via cephadm, with optional Ceph-CSI integration for Kubernetes.

<br/>

## Key Features

- **Variable Validation**: Validates all necessary variables before deployment
- **Dynamic Repository Configuration**: Supports RHCS, community, IBM, Shaman (dev), and custom repositories
- **OS Compatibility**: RHEL/CentOS and Ubuntu support
- **Container Engine Setup**: Automatic podman/docker configuration
- **Ceph-CSI Integration**: Includes templates for Kubernetes CSI driver setup

<br/>

## Project Structure

```
├── playbooks/
│   ├── site.yml              # Main deployment playbook
│   └── reset.yml             # Cluster cleanup playbook
├── roles/
│   ├── ceph-common/          # Environment prep, package installation
│   ├── ceph-deploy/          # Cluster bootstrap and expansion
│   └── ceph-cleanup/         # Tear-down and removal
├── library/                  # Custom Ansible modules
├── module_utils/             # Shared Python utilities
├── ceph_defaults/            # Default variables role
├── group_vars/               # Group variables
├── validate/                 # Variable validation tasks
├── ceph-csi-test/            # Kubernetes Ceph-CSI test resources
├── inventory.ini             # Template inventory
└── ansible.cfg               # Ansible configuration
```

<br/>

## Prerequisites

- SSH access to all target nodes
- Python 3.10+

```bash
# Generate SSH keys (if needed)
ssh-keygen

# Copy SSH key to target nodes
ssh-copy-id your_user@server_ip

# Update /etc/hosts
echo "server_ip your_hostname" | sudo tee -a /etc/hosts
```

<br/>

## Installation

### 1. Install Python and Clone Repository

```bash
# Ubuntu 22.04
sudo apt-get -y update
sudo apt install -y python3 python3-venv python3-pip git

# Ubuntu 20.04
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt-get -y update
sudo apt install -y python3.10 python3-pip git python3.10-venv

# RHEL/CentOS 8+
dnf install tar curl gcc openssl-devel bzip2-devel libffi-devel zlib-devel wget make git -y
```

```bash
git clone https://github.com/somaz94/install-cephadm-ansible.git
VENVDIR=cephadm-venv
CEPHADMDIR=install-cephadm-ansible
python3 -m venv $VENVDIR
source $VENVDIR/bin/activate
cd $CEPHADMDIR
pip install -U -r requirements.txt
```

### 2. Configure Inventory and Variables

Edit `inventory.ini` and `group_vars/all.yml` for your cluster configuration.

### 3. Verify Ansible

```bash
ansible --version
ansible all -i inventory.ini -m ping
```

### 4. Deploy Cluster

```bash
# Full deployment
ansible-playbook -i inventory.ini playbooks/site.yml

# Selective role execution
ansible-playbook -i inventory.ini playbooks/site.yml -e "run_ceph_common=true run_ceph_deploy=false"
ansible-playbook -i inventory.ini playbooks/site.yml -e "run_ceph_common=false run_ceph_deploy=true"

# Use RHCS repository
ansible-playbook -i inventory.ini playbooks/site.yml --extra-vars "ceph_origin=rhcs"

# Cleanup cluster
ansible-playbook -i inventory.ini playbooks/reset.yml
```

### 5. Verify Cluster

```bash
ceph orch host ls
ceph -s
ceph osd tree
ceph orch ls --service-type mon
ceph orch ls --service-type mgr
ceph orch ls --service-type osd
ceph df
```

<br/>

## Ceph-CSI Integration (Optional)

> **Note**: Ensure your Kubernetes cluster is fully operational before installing the Ceph cluster.

### 1. Create a Ceph Pool

```bash
# Create pool
ceph osd pool create kube 128

# Modify pool replica (optional)
ceph osd pool get <pool-name> size
ceph osd pool set <pool-name> size 2
```

### 2. Install Ceph-CSI

```bash
helm repo add ceph-csi https://ceph.github.io/csi-charts
helm repo update

# For RBD
helm install ceph-csi-rbd ceph-csi/ceph-csi-rbd \
  --namespace ceph-csi --create-namespace \
  --version <chart_version>

# For CephFS
helm install ceph-csi-cephfs ceph-csi/ceph-csi-cephfs \
  --namespace ceph-csi --create-namespace \
  --version <chart_version>
```

### 3. Configure Ceph-CSI

```bash
# Get cluster FSID
ceph fsid

# Check monitor port
ss -nlpt | grep 6789

# Get auth key
ceph auth list | grep client.admin -A5
```

### 4. Deploy CSI Resources

```bash
kubectl apply -f ceph-csi-test/ceph-csi-values.yaml
kubectl apply -f ceph-csi-test/ceph-csi-storageclass.yaml
kubectl apply -f ceph-csi-test/test-pod.yaml
```

<br/>

## Reference

- [cephadm-ansible](https://github.com/ceph/cephadm-ansible)
- [Ceph-CSI](https://github.com/ceph/ceph-csi)

<br/>

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
