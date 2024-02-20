# ![Ceph](https://img.shields.io/badge/-Ceph-E24C27?style=flat-square&logo=ceph&logoColor=white) Ceph and Ceph-CSI Installation Guide
This guide provides a comprehensive walkthrough for installing Ceph with the Ceph-CSI plugin, enabling dynamic volume provisioning in Kubernetes environments.

<br/>

## 📋 Prerequisites
A running Kubernetes cluster.
Helm 3 installed.
Access to a terminal with SSH capabilities.

<br/>

## 🛠️ Installation Steps

<br/>

### Step 1: Clone cephadm-ansible
Clone the `cephadm-ansible` repository to your local machine and set up a virtual environment for Python.
```bash
git clone https://github.com/ceph/cephadm-ansible
VENVDIR=cephadm-venv
CEPHADMDIR=cephadm-ansible
python3.10 -m venv $VENVDIR
source $VENVDIR/bin/activate
cd $CEPHADMDIR
pip install -U -r requirements.txt
```

### Step 2: Copy All files
Copy the necessary files into the cephadm-ansible directory.
```bash
cp * cephadm-ansible
cd cephadm-ansbile
```

### Step 3: Prepare Your Inventory
Edit the `inventory.ini` file to specify your cluster configuration.
```bash
[all]
# node1 ansible_host=95.54.0.14
# node2 ansible_host=95.54.0.15
# node3 ansible_host=95.54.0.16

# Ceph Client Nodes (Kubernetes nodes that require access to Ceph storage)
[clients]
# node1
# node2
# node3

# Admin Node (Usually the first monitor node)
[admin]
# node1
```

### Step 4: Edit Variables Script
The `ceph_vars.sh` script, which contains important environment variables for the Ceph installation, has already been copied to your directory. Now, you need to edit this script to match your specific setup.

Open `ceph_vars.sh` with your preferred text editor and adjust the variables accordingly:
  - SSH_KEY: Path to your SSH key.
  - HOST_GROUP: Array of your hostnames.
  - ADMIN_HOST: Hostname of your admin node.
  - OSD_HOST: Hostname for the OSD node.
  - HOST_IPS: Array of IP addresses corresponding to your hosts.
  - OSD_DEVICES: List of devices for OSDs, without the /dev/ prefix.
  - CLUSTER_NETWORK: CIDR of your cluster network.
  - SSH_USER: Your SSH username.


### Step 5: Install Ceph
Execute the setup script to deploy Ceph across your cluster.
```bash
chmod +x *.sh
./setup_ceph_cluster.sh
```

### Step 6: Verify Ceph Installation

Check the status of your Ceph installation using the following commands:
```bash
ceph orch host ls
ceph -s
ceph osd tree
ceph orch ls --service-type mon
ceph orch ls --service-type mgr
ceph orch ls --service-type osd
ceph df
```

### Setp 7: (Optional) Create a Ceph Pool

Create a storage pool in Ceph if required.
```bash
# Create pool
ex. ceph osd pool create {pool-name} {pg-num} [{pgp-num}] [replicated] [crush-rule-name] [expected-num-objects]
ceph osd pool create kube 128

# Confirm
ceph df
```

### Step 8: Install Ceph-CSI

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

### Step 9: Configure Ceph-CSI
Create a ceph-csi-values.yaml file with your Ceph cluster's configuration details.

```bash
# Confirm Ceph fsid
sudo ceph fsid

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

### Step 10: Deploy the Ceph-CSI Driver
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

### Step 11: Create a StorageClass
Create a StorageClass to use with Ceph-CSI for dynamic provisioning.

```bash
# Confirm Ceph authentication details
sudo ceph auth list |grep client.admin -A5
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

### Step 12: Deploy Test Pod
```bash
# Apply
k apply -f test-pod.yaml

# Confirm
k get po,pv,pvc
NAME                     READY   STATUS    RESTARTS   AGE
pod/pod-using-ceph-rbd   1/1     Running   0          16s

NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/pvc-83fd673e-077c-4d24-b9c9-290118586bd3   1Gi        RWO            Delete           Bound    default/ceph-rbd-pvc   rbd            <unset>                          16s

NAME                                 STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/ceph-rbd-pvc   Bound    pvc-83fd673e-077c-4d24-b9c9-290118586bd3   1Gi        RWO            rbd            <unset>                 16s
```

<br/>

## Reference
- [Cephadm-Ansible GitHub](https://github.com/ceph/cephadm-ansible)
- [Ceph-CSI GitHub](https://github.com/ceph/ceph-csi)

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.