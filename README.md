# ![Ceph](https://img.shields.io/badge/-Ceph-E24C27?style=flat-square&logo=ceph&logoColor=white) Ceph and Ceph-CSI Installation Guide
This guide provides a comprehensive walkthrough for installing Ceph with the Ceph-CSI plugin, enabling dynamic volume provisioning in Kubernetes environments.

<br/>

## 📋 Prerequisites
Access to a terminal with SSH capabilities.
Generate SSH Keys (if needed).
  ```bash
  ssh-keygen 
  ```
Copy SSH Public Key to Your Server.
  ```bash
  ssh-copy-id your_user@server_ip
  ```
Update `/etc/hosts` for Easy Access.
  ```bash
  vi /etc/hosts
  server_ip your_hostname
  ```

<br/>

## 🛠️ Installation Steps

### Step 1: Install Python & Clone cephadm-ansible
Clone the `cephadm-ansible` repository to your local machine and set up a virtual environment for Python.
```bash
# For Debian/Ubuntu (Check if Python 3.10 is available in default repos first)
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt-get -y update
sudo apt install -y python3.10 python3-pip git python3.10-venv

# For RedHat/CentOS 8
sudo dnf module enable python310 -y
sudo dnf install -y python310 git python3-pip python3.10-venv

# Clone cephadm-ansible
git clone https://github.com/somaz94/install-cephadm-ansible.git
VENVDIR=cephadm-venv
CEPHADMDIR=install-cephadm-script
python3.10 -m venv $VENVDIR
source $VENVDIR/bin/activate
cd $CEPHADMDIR
pip install -U -r requirements.txt
```

### Step 2: Prepare Your Inventory and group_vars
Edit the `inventory.ini` file and `group_vars/all.yml` to specify your cluster configuration.

### Step3: Confirm Ansible
```bash
# Check Version
ansible --version

# Check Ansible Ping
ansible all -i inventory.ini -m ping
```

### Step4: Playbook Ansible
```bash
# Create Cluster
ansible-playbook -i inventory.ini playbooks/site.yml

# Create Cluster Options(Roles)
ansible-playbook -i inventory.ini playbooks/site.yml -e "run_ceph_common=true run_ceph_deploy=false"
ansible-playbook -i inventory.ini playbooks/site.yml -e "run_ceph_common=false run_ceph_deploy=true"

# Delete Cluster
ansible-playbook -i inventory.ini playbooks/reset.yml

```

<br/>

## Reference
- [Cephadm-Ansible GitHub](https://github.com/ceph/cephadm-ansible)
- [Ceph-CSI GitHub](https://github.com/ceph/ceph-csi)

<br/>

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
