### **📦 suse-nfs-server - Lightweight, Containerized NFS Server**

**suse-nfs-server** is a highly flexible, containerized **NFS server** built on **openSUSE Leap 15.5**, designed for **easy deployment**, and **dynamic storage configuration** without the need for Docker volumes.

---

## **✨ Features**

**Supports NFSv3 & NFSv4** – Compatible with modern clients
**Containerized for Flexibility** – Runs seamlessly in **Docker & Kubernetes**
**No Docker Volume Required** – Uses a **loopback ext4 filesystem** for persistence
**Dynamic Storage Configuration** – **Adjust NFS size at runtime** using environment variables
**Pre-configured Exports** – Ready-to-use for **multi-container setups**
**Lightweight & Minimal Dependencies** – Uses `rpcbind`, `nfs-kernel-server`, `rpc.mountd`

---

## **🚀 Quick Start**

Run the **NFS server container** with default settings (100MB storage):

```sh
docker run -d --name nfs-server --privileged \
  -p 2049:2049 -p 20048:20048 \
  ghcr.io/my-username/suse-nfs-server
```

### **📌 Customizing NFS Storage Size (Example: 2GB)**

```sh
docker run -d --name nfs-server --privileged \
  -e NFS_SIZE_MB=2048 \  # Set storage to 2GB
  -p 2049:2049 -p 20048:20048 \
  ghcr.io/my-username/suse-nfs-server
```

---

## **🛠 Configuration & Environment Variables**

| Variable      | Default | Description                              |
| ------------- | ------- | ---------------------------------------- |
| `NFS_SIZE_MB` | `100`   | Set NFS storage size dynamically (in MB) |

If you want to customize the NFS server configuration—such as modifying the exports file, changing mount options, or tweaking NFS service settings—you can easily build your own image with custom configurations.

---

## **Connecting to the NFS Server**

### **🔹 Linux Clients (Tested)**

Mount the NFS share from another container or system:

```sh
mount -o vers=4 172.17.0.2:/mnt/nfs-share /mnt/nfs
```

For **NFSv3**:

```sh
mount -o vers=3 172.17.0.2:/mnt/nfs-share /mnt/nfs
```

### **🔹 macOS (Untested)**

```sh
sudo mount -o vers=4,hard,nolock 172.17.0.2:/mnt/nfs-share /mnt/nfs
```

### **🔹 Windows (WSL2) (Untested)**

```powershell
mount -o vers=4 172.17.0.2:/mnt/nfs-share /mnt/nfs
```

---

## **🌍 Contribute & Get Support**

💡 **Contributions welcome!** If you have improvements or bug fixes, feel free to submit a PR or create an issue.

🔗 **GitHub:** [https://github.com/KnightRider2070/suse-nfs-server]
🐞 **Issues:** [https://github.com/KnightRider2070/suse-nfs-server/issues]
