# ![Ceph](https://img.shields.io/badge/-Ceph-E24C27?style=flat-square&logo=ceph&logoColor=white) Ceph and Ceph-CSI Installation Guide
This guide provides a comprehensive walkthrough for installing Ceph with the Ceph-CSI plugin, enabling dynamic volume provisioning in Kubernetes environments.

<br/>

## 📋 Prerequisites
A running Kubernetes cluster.
Helm 3 installed.
Access to a terminal with SSH capabilities.
Generate SSH Keys (if needed).
  ```bash
  ssh-keygen 
  ```
Copy SSH Public Key to Your Server.
  ```bash
  ssh-copy-id your_user@server_ip
  ```
Update `/etc/hosts` for Easy Access
  ```bash
  vi /etc/hosts
  server_ip your_hostname
  ```

<br/>

## 🛠️ Installation Steps

<br/>

## Reference
- [Cephadm-Ansible GitHub](https://github.com/ceph/cephadm-ansible)
- [Ceph-CSI GitHub](https://github.com/ceph/ceph-csi)

<br/>

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
