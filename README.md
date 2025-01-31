# **📦 suse-nfs-server - Lightweight, Containerized NFS Server**

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
  ghcr.io/knightrider2070/suse-nfs-server
```

### **📌 Customizing NFS Storage Size (Example: 2GB)**

```sh
docker run -d --name nfs-server --privileged \
  -e NFS_SIZE_MB=2048 \  # Set storage to 2GB
  -p 2049:2049 -p 20048:20048 \
  ghcr.io/knightrider2070/suse-nfs-server
```

### **📌 Customizing log interval (Example: 5 seconds)**

```sh
docker run -d --name nfs-server --privileged \
  -e MONITOR_INTERVAL=5 \
  -p 2049:2049 -p 20048:20048 \
  ghcr.io/knightrider2070/suse-nfs-server
```

> **Note**: `--privileged` is required to allow the container to mount special pseudo-filesystems like `nfsd`.

---

## **🛠 Configuration & Environment Variables**

| Variable      | Default | Description                                   |
|---------------|---------|-----------------------------------------------|
| `NFS_SIZE_MB` | `100`   | Set NFS storage size dynamically (in MB)      |
| `MONITOR_INTERVAL` | `1` | Frequency (in seconds) to check connections  |

If you want to customize further (e.g., the exports file or mount options), simply build your own image with additional configuration.

---

## **Why Mount `/proc/fs/nfsd`?**

Inside the container, the script runs:

```bash
mkdir -p /proc/fs/nfsd
mount -t nfsd nfsd /proc/fs/nfsd
```

This **binds the kernel’s NFS filesystem** into the container so that `rpc.nfsd` can communicate with the host kernel’s NFS subsystem. Without it, **NFS exports** wouldn’t function correctly in a containerized environment.

---

## **Connecting to the NFS Server**

**Requires** `nfs-client` (or equivalent) on your client system to mount NFS shares.

> **Note**: If your NFS client **itself** runs in a Docker container, you must add the `--privileged` flag to let it mount remote NFS shares.

### **🔹 Linux Clients (Tested)**

Mount the NFS share from another Linux container or system.
**NFSv4** (root export is `/`):

```sh
mount.nfs4 172.17.0.2:/ /mnt/nfs
```

If you’d prefer to explicitly mount `/mnt/nfs-share` under NFSv4:

```sh
mount -t nfs4 172.17.0.2:/mnt/nfs-share /mnt/nfs
```

For **NFSv3**:

```sh
mount -t nfs -o vers=3 172.17.0.2:/mnt/nfs-share /mnt/nfs
```

### **🔹 macOS (Untested)**

Install NFS client tools (already included on most macOS systems). Then:

```sh
sudo mount -t nfs -o vers=4,hard,nolock 172.17.0.2:/mnt/nfs-share /mnt/nfs
```

> Some macOS versions might require additional flags (e.g., `resvport`).

### **🔹 Windows (WSL2) (Untested)**

WSL2 supports NFS mounting in newer builds. For example:

```powershell
mount -t nfs -o vers=4 172.17.0.2:/mnt/nfs-share /mnt/nfs
```

> If you encounter permissions issues, confirm WSL’s NFS client settings or use Samba as an alternative.

---

## **🌍 Contribute & Get Support**

💡 **Contributions welcome!** If you have improvements or bug fixes, feel free to submit a PR or create an issue.

🔗 **GitHub:** [https://github.com/KnightRider2070/suse-nfs-server]
🐞 **Issues:** [https://github.com/KnightRider2070/suse-nfs-server/issues]

---

Enjoy a **lightweight**, **flexible** NFS server experience on openSUSE Leap!
