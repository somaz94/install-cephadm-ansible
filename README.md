# Install Ceph and Ceph-csi

### Clone cephadm-ansible

```bash
git clone https://github.com/ceph/cephadm-ansible

VENVDIR=cephadm-venv
CEPAHADMDIR=cephadm-ansible
python3.10 -m venv $VENVDIR
source $VENVDIR/bin/activate
cd $CEPAHADMDIR

pip install -U -r requirements.txt
```

### Copy files
```bash
cp * cephadm-ansible
cd cephadm-ansbile
```

### Modify Inventory.ini
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

### Install Ceph
```bash
chmod +x *.sh
./setup_ceph_cluster.sh
```

### Check Ceph
```bash
ceph orch host ls
ceph -s
ceph osd tree
ceph orch ls --service-type mon
ceph orch ls --service-type mgr
ceph orch ls --service-type osd
ceph df
```

### Create Pool(Select)
```bash
# Create pool
ex. ceph osd pool create {pool-name} {pg-num} [{pgp-num}] [replicated] [crush-rule-name] [expected-num-objects]
ceph osd pool create kube 128

# Confirm pool replica
ex. ceph osd pool get kube size
size: 1

# Change pool replica
ex. ceph osd pool set kube size 3

# Delete pool 
ex. ceph osd pool delete {pool-name} {pool-name} --yes-i-really-really-mean-it

# Change pg
ex. ceph osd pool set {pool-name} pg_num {new-pg-num}

ceph osd pool set kube pg_num 256

# Confirm
ceph df
--- RAW STORAGE ---
CLASS     SIZE    AVAIL     USED  RAW USED  %RAW USED
ssd    150 GiB  149 GiB  872 MiB   872 MiB       0.57
TOTAL  150 GiB  149 GiB  872 MiB   872 MiB       0.57

--- POOLS ---
POOL  ID  PGS   STORED  OBJECTS     USED  %USED  MAX AVAIL
.mgr   1    1  1.1 MiB        2  1.1 MiB      0    142 GiB
kube   2  128      0 B        0      0 B      0    142 GiB
```

### Install Ceph-csi

```bash
helm repo add ceph-csi https://ceph.github.io/csi-charts
helm repo update

helm search repo ceph-csi

# Use rbd
helm install ceph-csi-rbd ceph-csi/ceph-csi-rbd --namespace ceph-csi --create-namespace --version <chart_version>

# Use Cephfs
helm install ceph-csi-cephfs ceph-csi/ceph-csi-cephfs --namespace ceph-csi --create-namespace --version <chart_version>
```

### Write `ceph-csi-values.yaml`

```bash
# Confirm Ceph fsid
sudo ceph fsid

# Check 6789 Port
ss -nlpt | grep 6789

# Example: ceph-csi-values.yaml
csiConfig:
- clusterID: "afdfd487-cef1-11ee-8e5d-831aa89df15f" # ceph id
  monitors:
  - "10.77.101.47:6789"
provisioner:
  replicaCount: 1
```

### Install Ceph-csi Driver
```bash
# Create Namespace 
kubectl create namespace ceph-csi

# Install Ceph-csi Driver
helm install -n ceph-csi ceph-csi ceph-csi/ceph-csi-rbd -f ceph-csi-values.yaml

# Confirm
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

### Create StorageClass
```bash
# Confirm Ceph Auth
sudo ceph auth list |grep client.admin -A5
client.admin
        key: AQAYINNlW7qOEhAAO++/Hvc6HBO+whoSJRT6eg==
        caps: [mds] allow *
        caps: [mgr] allow *
        caps: [mon] allow *
        caps: [osd] allow *

# Apply
k apply -f ceph-csi-storageclass.yaml 

# Confirm
k get sc
NAME            PROVISIONER        RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rbd (default)   rbd.csi.ceph.com   Delete          Immediate           true      
```

### Deploy Test Pod
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

### Reference
- https://github.com/ceph/cephadm-ansible
- https://github.com/ceph/ceph-csi

