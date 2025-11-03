# 📦 suse-nfs-server - Containerized NFSv4 Server with NFS-Ganesha

**suse-nfs-server** is a modern, containerized **NFSv4 server** built on **openSUSE Leap 15.5** using **NFS-Ganesha** (user-space NFS implementation). This project provides a **secure, lightweight, and flexible** NFS solution that runs **without privileged mode** and supports **dynamic storage configuration**.

---

## ✨ Features

✅ **NFSv4 Only** – Modern NFS protocol without legacy complexity  
✅ **NFS-Ganesha** – User-space NFS server for better security and isolation  
✅ **Non-Privileged Mode** – Runs with minimal Linux capabilities (no `--privileged`)  
✅ **Single Container** – All services (rpcbind, dbus, ganesha) in one container  
✅ **Dynamic Storage** – Configure storage size at runtime with environment variables  
✅ **No Docker Volume Required** – Uses loopback ext4 filesystem for persistence  
✅ **Container Best Practices** – Based on [contained-ganesha](https://github.com/NicolasT/contained-ganesha) approach

---

## 🚀 Quick Start

### Recommended: Non-Privileged Mode (Secure)

```bash
docker run -d --name nfs-server \
  --cap-drop ALL \
  --cap-add CHOWN \
  --cap-add DAC_OVERRIDE \
  --cap-add FOWNER \
  --cap-add FSETID \
  --cap-add NET_BIND_SERVICE \
  --cap-add SETGID \
  --cap-add SETUID \
  -p 2049:2049 -p 20048:20048 -p 111:111 \
  -e NFS_SIZE_MB=500 \
  ghcr.io/knightrider2070/suse-nfs-server
```

### Simple Mode (for Testing)

```bash
docker run -d --name nfs-server \
  -p 2049:2049 -p 20048:20048 -p 111:111 \
  -e NFS_SIZE_MB=1024 \
  ghcr.io/knightrider2070/suse-nfs-server
```

> **🔒 Security Note**: Unlike traditional kernel NFS servers, **NFS-Ganesha does NOT require `--privileged` mode**! This container runs securely with minimal Linux capabilities, making it suitable for production environments with strict security policies.

---

## 🛠 Configuration & Environment Variables

| Variable       | Default | Description                                          |
|----------------|---------|------------------------------------------------------|
| `NFS_SIZE_MB`  | `100`   | Set NFS storage size dynamically (in MB)             |
| `NFS_PORT`     | `2049`  | NFS service port                                     |
| `MOUNTD_PORT`  | `20048` | Mount daemon port                                    |

---

## 🔐 Security & Capabilities

This container follows security best practices from the [contained-ganesha](https://github.com/NicolasT/contained-ganesha) project:

### Required Linux Capabilities

Instead of running with `--privileged`, only the following capabilities are needed:

- `CHOWN` – Change file ownership
- `DAC_OVERRIDE` – Bypass file read, write, and execute permission checks
- `FOWNER` – Bypass permission checks on operations that normally require filesystem UID
- `FSETID` – Don't clear set-user-ID and set-group-ID mode bits
- `NET_BIND_SERVICE` – Bind to privileged ports (< 1024)
- `SETGID` – Make arbitrary manipulations of process GIDs
- `SETUID` – Make arbitrary manipulations of process UIDs

### How to Run Without Privileged Mode

**NFS-Ganesha was specifically designed to run as a user-space process**, eliminating the need for privileged containers that traditional kernel NFS servers require. Here's how to leverage this security benefit:

**❌ Old Way (Kernel NFS - Requires Privileged Mode):**
```bash
# Kernel NFS requires --privileged flag
docker run -d --privileged \
  -p 2049:2049 \
  old-kernel-nfs-image
```

**✅ New Way (NFS-Ganesha - No Privileged Mode Needed):**
```bash
# Option 1: Maximum Security - Drop all capabilities, add only what's needed
docker run -d --name nfs-server \
  --cap-drop ALL \
  --cap-add CHOWN \
  --cap-add DAC_OVERRIDE \
  --cap-add FOWNER \
  --cap-add FSETID \
  --cap-add NET_BIND_SERVICE \
  --cap-add SETGID \
  --cap-add SETUID \
  -p 2049:2049 -p 20048:20048 -p 111:111 \
  -e NFS_SIZE_MB=500 \
  ghcr.io/knightrider2070/suse-nfs-server

# Option 2: Simple Mode - Let Docker use default capabilities (still secure)
docker run -d --name nfs-server \
  -p 2049:2049 -p 20048:20048 -p 111:111 \
  -e NFS_SIZE_MB=1024 \
  ghcr.io/knightrider2070/suse-nfs-server
```

**Key Benefits:**
- 🔒 **Reduced Attack Surface** – Only 7 specific capabilities vs. full system access
- 🛡️ **Container Isolation** – No access to host kernel modules or `/proc/fs/nfsd`
- ☁️ **Cloud-Native** – Compatible with security-restricted environments (Kubernetes, cloud platforms)
- 🚀 **Production-Ready** – Meets enterprise security requirements without privileged mode

### Why NFS-Ganesha?

NFS-Ganesha is a **user-space NFS server** that offers several advantages:

- ✅ **No kernel NFS dependencies** – Doesn't require `/proc/fs/nfsd` mount
- ✅ **Better containerization** – All processes run in user space
- ✅ **NFSv4 native** – Modern protocol without legacy NFSv3 complexity
- ✅ **Flexible backends** – Supports VFS, CEPH, GLUSTER, and more (FSAL)
- ✅ **Simpler architecture** – Fewer daemons and dependencies

---

## 📡 Connecting to the NFS Server

### Prerequisites

Install NFS client tools on your client system:

```bash
# Ubuntu/Debian
sudo apt-get install nfs-common

# RHEL/CentOS/Fedora
sudo dnf install nfs-utils

# openSUSE
sudo zypper install nfs-client
```

### Mounting the NFSv4 Share

**Find the server IP:**

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nfs-server
```

**Mount the share (NFSv4):**

```bash
# Create mount point
sudo mkdir -p /mnt/nfs

# Mount the NFSv4 root export
sudo mount -t nfs4 -o vers=4.0 <server-ip>:/ /mnt/nfs

# Example:
sudo mount -t nfs4 -o vers=4.0 172.17.0.2:/ /mnt/nfs
```

**Verify the mount:**

```bash
df -h /mnt/nfs
ls -la /mnt/nfs
```

**Unmount when done:**

```bash
sudo umount /mnt/nfs
```

---

## 🐳 Advanced Usage

### Custom Storage Size

```bash
docker run -d --name nfs-server \
  --cap-drop ALL \
  --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER \
  --cap-add FSETID --cap-add NET_BIND_SERVICE --cap-add SETGID --cap-add SETUID \
  -p 2049:2049 -p 20048:20048 -p 111:111 \
  -e NFS_SIZE_MB=5120 \
  ghcr.io/knightrider2070/suse-nfs-server
```

### Custom Ganesha Configuration

You can provide your own `ganesha.conf` file:

```bash
docker run -d --name nfs-server \
  --cap-drop ALL \
  --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER \
  --cap-add FSETID --cap-add NET_BIND_SERVICE --cap-add SETGID --cap-add SETUID \
  -p 2049:2049 -p 20048:20048 -p 111:111 \
  -v ./my-ganesha.conf:/etc/ganesha/ganesha.conf:ro \
  -e NFS_SIZE_MB=1024 \
  ghcr.io/knightrider2070/suse-nfs-server
```

### Docker Compose Example

```yaml
version: '3.8'

services:
  nfs-server:
    image: ghcr.io/knightrider2070/suse-nfs-server
    container_name: nfs-ganesha-server
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - FOWNER
      - FSETID
      - NET_BIND_SERVICE
      - SETGID
      - SETUID
    ports:
      - "2049:2049"    # NFS
      - "20048:20048"  # MountD
      - "111:111"      # RPCBind
    environment:
      - NFS_SIZE_MB=2048
    restart: unless-stopped
```

---

## 🏗️ Architecture

This implementation runs all required services in a **single container**:

1. **rpcbind** – Port mapper service (RPC portmapper on port 111)
2. **dbus-daemon** – System message bus (required by NFS-Ganesha)
3. **ganesha.nfsd** – NFS-Ganesha server (NFSv4 on port 2049)

All services start automatically and are managed by the entrypoint script.

### Why All Services in One Container?

While the original [contained-ganesha](https://github.com/NicolasT/contained-ganesha) project uses separate containers for each service (following microservices principles), this implementation combines them for simplicity and ease of deployment in single-server scenarios. For production Kubernetes deployments, consider using the multi-container approach.

---

## 📝 Differences from Kernel NFS

| Feature                 | NFS-Ganesha (This Image)     | Kernel NFS            |
| ----------------------- | ---------------------------- | --------------------- |
| **Mode**                | User-space                   | Kernel-space          |
| **Privileged Mode**     | ❌ Not required               | ✅ Required            |
| **NFSv4 Support**       | ✅ Native                     | ✅ Supported           |
| **NFSv3 Support**       | ⚠️ Optional (disabled)        | ✅ Default             |
| **Dependencies**        | Minimal                      | Kernel modules        |
| **Portability**         | High (any container runtime) | Requires kernel NFS   |
| **Backend Flexibility** | Multiple FSALs               | Local filesystem only |

---

## 🔧 Troubleshooting

### Check Container Logs

```bash
docker logs nfs-server
```

### Verify Services are Running

```bash
# Check rpcbind
docker exec nfs-server rpcinfo -p

# Check Ganesha is listening
docker exec nfs-server ss -tlnp | grep 2049
```

### Test from Host

```bash
# Check if NFS port is accessible
nc -zv <server-ip> 2049

# Try to show mount info
showmount -e <server-ip>
```

### Common Issues

**1. "Connection refused" when mounting**
- Ensure all ports are exposed: 111, 2049, 20048
- Check firewall rules on host and client

**2. "Permission denied" when writing files**
- Check the `Squash` setting in `ganesha.conf`
- Verify file permissions in `/mnt/nfs-share` inside container

**3. Mount succeeds but no files visible**
- Verify the storage was created: `docker exec nfs-server df -h /mnt/nfs-share`
- Check logs for mount errors

---

## 🎯 Use Cases

- **Development/Testing** – Quick NFS server for testing applications
- **Container Storage** – Shared storage for containerized applications
- **Kubernetes** – NFS-based PersistentVolumes (consider multi-container approach)
- **Media Servers** – Share media libraries across devices
- **Backup Storage** – Central backup location for multiple machines

---

## 🌍 Contribute & Get Support

💡 **Contributions welcome!** If you have improvements or bug fixes, feel free to submit a PR or create an issue.

🔗 **GitHub Repository:**  
[![GitHub](https://img.shields.io/badge/GitHub-Repo-blue?logo=github&style=flat-square)](https://github.com/KnightRider2070/suse-nfs-server)

🐞 **Report Issues & Request Features:**  
[![GitHub Issues](https://img.shields.io/badge/GitHub-Issues-red?logo=github&style=flat-square)](https://github.com/KnightRider2070/suse-nfs-server/issues)

---

## 📚 References

- [NFS-Ganesha Project](https://nfs-ganesha.github.io/)
- [contained-ganesha](https://github.com/NicolasT/contained-ganesha) – Inspiration for this implementation
- [NFSv4 RFC 7530](https://tools.ietf.org/html/rfc7530)

---

## 📄 License

This project is licensed under the terms specified in the LICENSE file.

---

**Enjoy a modern, secure, and flexible NFSv4 server experience! 🚀**
