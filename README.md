# ![Ceph](https://img.shields.io/badge/-Ceph-E24C27?style=flat-square&logo=ceph&logoColor=white) Ceph and Ceph-CSI Installation Guide
This guide provides a comprehensive walkthrough for installing Ceph with the Ceph-CSI plugin, enabling dynamic volume provisioning in Kubernetes environments.

<br/>

## 📋 Prerequisites
- Access to a terminal with SSH capabilities.
- Generate SSH Keys (if needed).
```bash
ssh-keygen 
```
- Copy SSH Public Key to Your Server.
```bash
ssh-copy-id your_user@server_ip
```
- Update `/etc/hosts` for Easy Access.
```bash
vi /etc/hosts
server_ip your_hostname
```

<br/>

## 🚨 Important Consideration
If you plan to use Ceph as the CSI Driver for a Kubernetes cluster, ensure that your Kubernetes cluster is fully set up and operational before installing the Ceph cluster. This preparation helps avoid potential integration challenges, ensuring a smoother setup for dynamic volume provisioning.

<br/>

## 🛠️ Installation Steps

### Step 1: Install Python & Clone install-cephadm-ansible
Clone the `install-cephadm-ansible` repository to your local machine and set up a Python virtual environment.
```bash
# For Debian/Ubuntu (Check if Python 3.10 is available in default repos first)
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt-get -y update
sudo apt install -y python3.10 python3-pip git python3.10-venv

# For RedHat/CentOS 8
sudo dnf module enable python310 -y
sudo dnf install -y python310 git python3-pip python3.10-venv

# Clone install-cephadm-ansible
git clone https://github.com/somaz94/install-cephadm-ansible.git
VENVDIR=cephadm-venv
CEPHADMDIR=install-cephadm-ansible
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

# Repo Options(Enable Red Hat Ceph Storage Tools Repository)
ansible-playbook -i inventory.ini playbooks/site.yml --extra-vars "ceph_origin=rhcs" 

# Delete Cluster
ansible-playbook -i inventory.ini playbooks/reset.yml

```

### Step5: Check Ceph Cluster
```bash
 ceph orch host ls
ceph -s
ceph osd tree
ceph orch ls --service-type mon
ceph orch ls --service-type mgr
ceph orch ls --service-type osd
ceph df
```
### Setp 6: (Optional) Create a Ceph Pool

Create a storage pool in Ceph if required.
```bash
# Create pool
ex. ceph osd pool create {pool-name} {pg-num} [{pgp-num}] [replicated] [crush-rule-name] [expected-num-objects]
ceph osd pool create kube 128

# Confirm
ceph df
```

### Step 7: (Optional Kubernetes Installed) Install Ceph-CSI

Add the Ceph-CSI Helm repository and update your Helm repo listings.
```bash
helm repo add ceph-csi https://ceph.github.io/csi-charts
helm repo update
```

Choose either the RBD or CephFS driver based on your needs and install it using Helm.

```bash
# Search Ceph-csi Version
helm search repo ceph-csi

# For RBD:
helm install ceph-csi-rbd ceph-csi/ceph-csi-rbd --namespace ceph-csi --create-namespace --version <chart_version>

# For CephFS:
helm install ceph-csi-cephfs ceph-csi/ceph-csi-cephfs --namespace ceph-csi --create-namespace --version <chart_version>
```

### Step 8: (Optional Kubernetes Installed) Configure Ceph-CSI
Create a ceph-csi-values.yaml file with your Ceph cluster's configuration details.

```bash
# Confirm Ceph fsid
ceph fsid

# Check 6789 Port
ss -nlpt | grep 6789

# Example: ceph-csi-values.yaml
csiConfig:
  - clusterID: "<your_ceph_fsid>" # Use `sudo ceph fsid` to find your Ceph fsid
    monitors:
      - "<monitor_ip>:6789"
provisioner:
  replicaCount: 1
```

### Step 9: (Optional Kubernetes Installed) Deploy the Ceph-CSI Driver
```bash
# Create Namespace 
kubectl create namespace ceph-csi

# Install Ceph-csi Driver
helm install -n ceph-csi ceph-csi ceph-csi/ceph-csi-rbd -f ceph-csi-values.yaml

# Confirm Ceph-csi Driver
k get all -n ceph-csi
NAME                                                    READY   STATUS    RESTARTS   AGE
pod/ceph-csi-ceph-csi-rbd-nodeplugin-76k5s              3/3     Running   0          3s
pod/ceph-csi-ceph-csi-rbd-provisioner-5d5dc6cc4-62dzb   7/7     Running   0          3s

NAME                                                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/ceph-csi-ceph-csi-rbd-nodeplugin-http-metrics    ClusterIP   10.233.37.117   <none>        8080/TCP   3s
service/ceph-csi-ceph-csi-rbd-provisioner-http-metrics   ClusterIP   10.233.41.120   <none>        8080/TCP   3s

NAME                                              DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/ceph-csi-ceph-csi-rbd-nodeplugin   1         1         1       1            1           <none>          3s

NAME                                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ceph-csi-ceph-csi-rbd-provisioner   1/1     1            1           3s

NAME                                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/ceph-csi-ceph-csi-rbd-provisioner-5d5dc6cc4   1         1         1       3s
```

### Step 10: (Optional Kubernetes Installed) Create a StorageClass
Create a StorageClass to use with Ceph-CSI for dynamic provisioning.

```bash
# Confirm Ceph authentication details
ceph auth list |grep client.admin -A5
client.admin
        key: AQAYINNlW7qOEhAAO++/Hvc6HBO+whoSJRT6eg==
        caps: [mds] allow *
        caps: [mgr] allow *
        caps: [mon] allow *
        caps: [osd] allow *

# Apply the StorageClass configuration
k apply -f ceph-csi-storageclass.yaml 

# Confirm
k get sc
NAME            PROVISIONER        RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rbd (default)   rbd.csi.ceph.com   Delete          Immediate           true      
```

<br/>

## Reference
- [Cephadm-Ansible GitHub](https://github.com/ceph/cephadm-ansible)
- [Ceph-CSI GitHub](https://github.com/ceph/ceph-csi)

<br/>

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
