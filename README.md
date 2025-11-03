# **📦 suse-nfs-server - Containerized NFSv4 Server with NFS-Ganesha**# **📦 suse-nfs-server - Lightweight, Containerized NFS Server**



**suse-nfs-server** is a modern, containerized **NFSv4 server** built on **openSUSE Leap 15.5** using **NFS-Ganesha** (user-space NFS implementation). This project provides a **secure, lightweight, and flexible** NFS solution that runs **without privileged mode** and supports **dynamic storage configuration**.**suse-nfs-server** is a highly flexible, containerized **NFS server** built on **openSUSE Leap 15.5**, designed for **easy deployment**, and **dynamic storage configuration** without the need for Docker volumes.



------



## **✨ Features**## **✨ Features**



✅ **NFSv4 Only** – Modern NFS protocol without legacy complexity  **Supports NFSv3 & NFSv4** – Compatible with modern clients  

✅ **NFS-Ganesha** – User-space NFS server for better security and isolation  **Containerized for Flexibility** – Runs seamlessly in **Docker & Kubernetes**  

✅ **Non-Privileged Mode** – Runs with minimal Linux capabilities (no `--privileged`)  **No Docker Volume Required** – Uses a **loopback ext4 filesystem** for persistence  

✅ **Single Container** – All services (rpcbind, dbus, ganesha) in one container  

✅ **Dynamic Storage** – Configure storage size at runtime with environment variables  ---

✅ **No Docker Volume Required** – Uses loopback ext4 filesystem for persistence  

✅ **Container Best Practices** – Based on [contained-ganesha](https://github.com/NicolasT/contained-ganesha) approach## **🚀 Quick Start**



---Run the **NFS server container** with default settings (100MB storage):



## **🚀 Quick Start**```sh

docker run -d --name nfs-server --privileged \

### **Run with Recommended Security (Non-Privileged Mode)**  -p 2049:2049 -p 20048:20048 \

  ghcr.io/knightrider2070/suse-nfs-server

```bash```

docker run -d --name nfs-server \

  --cap-drop ALL \### **📌 Customizing NFS Storage Size (Example: 2GB)**

  --cap-add CHOWN \

  --cap-add DAC_OVERRIDE \```sh

  --cap-add FOWNER \docker run -d --name nfs-server --privileged \

  --cap-add FSETID \  -e NFS_SIZE_MB=2048 \  # Set storage to 2GB

  --cap-add NET_BIND_SERVICE \  -p 2049:2049 -p 20048:20048 \

  --cap-add SETGID \  ghcr.io/knightrider2070/suse-nfs-server

  --cap-add SETUID \```

  -p 2049:2049 -p 20048:20048 -p 111:111 \

  -e NFS_SIZE_MB=500 \### **📌 Customizing log interval (Example: 5 seconds)**

  ghcr.io/knightrider2070/suse-nfs-server

``````sh

docker run -d --name nfs-server --privileged \

### **Simple Start (for testing)**  -e MONITOR_INTERVAL=5 \

  -p 2049:2049 -p 20048:20048 \

```bash  ghcr.io/knightrider2070/suse-nfs-server

docker run -d --name nfs-server \```

  -p 2049:2049 -p 20048:20048 -p 111:111 \

  -e NFS_SIZE_MB=1024 \> **Note**: `--privileged` is required to allow the container to mount special pseudo-filesystems like `nfsd`.

  ghcr.io/knightrider2070/suse-nfs-server

```---



> **Note**: The `--privileged` flag is **NOT required** when using NFS-Ganesha! The container runs with minimal capabilities for enhanced security.## **🛠 Configuration & Environment Variables**



---| Variable      | Default | Description                                   |

|---------------|---------|-----------------------------------------------|

## **🛠 Configuration & Environment Variables**| `NFS_SIZE_MB` | `100`   | Set NFS storage size dynamically (in MB)      |

| `MONITOR_INTERVAL` | `1` | Frequency (in seconds) to check connections  |

| Variable       | Default | Description                                          || `USE_GANESHA` | `0` | If set to `1` (or `true`), run NFS Ganesha (user-space NFS) instead of kernel nfsd |

|----------------|---------|------------------------------------------------------|

| `NFS_SIZE_MB`  | `100`   | Set NFS storage size dynamically (in MB)             |If you want to customize further (e.g., the exports file or mount options), simply build your own image with additional configuration.

| `NFS_PORT`     | `2049`  | NFS service port                                     |

| `MOUNTD_PORT`  | `20048` | Mount daemon port                                    |---



---## **Why Mount `/proc/fs/nfsd`?**



## **🔐 Security & Capabilities**Inside the container, the script runs:



This container follows security best practices from the [contained-ganesha](https://github.com/NicolasT/contained-ganesha) project:```bash

mkdir -p /proc/fs/nfsd

### **Required Linux Capabilities**mount -t nfsd nfsd /proc/fs/nfsd

```

Instead of running with `--privileged`, only the following capabilities are needed:

This **binds the kernel’s NFS filesystem** into the container so that `rpc.nfsd` can communicate with the host kernel’s NFS subsystem. Without it, **NFS exports** wouldn’t function correctly in a containerized environment.

- `CHOWN` – Change file ownership

- `DAC_OVERRIDE` – Bypass file read, write, and execute permission checks---

- `FOWNER` – Bypass permission checks on operations that normally require filesystem UID

- `FSETID` – Don't clear set-user-ID and set-group-ID mode bits## **Connecting to the NFS Server**

- `NET_BIND_SERVICE` – Bind to privileged ports (< 1024)

- `SETGID` – Make arbitrary manipulations of process GIDs**Requires** `nfs-client` (or equivalent) on your client system to mount NFS shares.

- `SETUID` – Make arbitrary manipulations of process UIDs

> **Note**: If your NFS client **itself** runs in a Docker container, you must add the `--privileged` flag to let it mount remote NFS shares.

### **Why NFS-Ganesha?**

### **🔹 Linux Clients (Tested)**

NFS-Ganesha is a **user-space NFS server** that offers several advantages:

Mount the NFS share from another Linux container or system.

- ✅ **No kernel NFS dependencies** – Doesn't require `/proc/fs/nfsd` mount**NFSv4** (root export is `/`):

- ✅ **Better containerization** – All processes run in user space

- ✅ **NFSv4 native** – Modern protocol without legacy NFSv3 complexity```sh

- ✅ **Flexible backends** – Supports VFS, CEPH, GLUSTER, and more (FSAL)mount.nfs4 172.17.0.2:/ /mnt/nfs

- ✅ **Simpler architecture** – Fewer daemons and dependencies```



---If you’d prefer to explicitly mount `/mnt/nfs-share` under NFSv4:



## **📡 Connecting to the NFS Server**```sh

mount -t nfs4 172.17.0.2:/mnt/nfs-share /mnt/nfs

### **Prerequisites**```



Install NFS client tools on your client system:For **NFSv3**:



```bash```sh

# Ubuntu/Debianmount -t nfs -o vers=3 172.17.0.2:/mnt/nfs-share /mnt/nfs

sudo apt-get install nfs-common```



# RHEL/CentOS/Fedora---

sudo dnf install nfs-utils

## **🌍 Contribute & Get Support**

# openSUSE

sudo zypper install nfs-client💡 **Contributions welcome!** If you have improvements or bug fixes, feel free to submit a PR or create an issue.

```

🔗 **GitHub Repository:**  

### **Mounting the NFSv4 Share**[![GitHub](https://img.shields.io/badge/GitHub-Repo-blue?logo=github&style=flat-square)](https://github.com/KnightRider2070/suse-nfs-server)  

Browse the source code, fork the project, and submit pull requests.

**Find the server IP:**

🐞 **Report Issues & Request Features:**  

```bash[![GitHub Issues](https://img.shields.io/badge/GitHub-Issues-red?logo=github&style=flat-square)](https://github.com/KnightRider2070/suse-nfs-server/issues)  

docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nfs-serverIf you encounter problems, report them on GitHub Issues.

```

---

**Mount the share (NFSv4):**

Enjoy a **lightweight**, **flexible** NFS server experience on openSUSE Leap!

```bash

# Create mount point---

sudo mkdir -p /mnt/nfs

## Using NFS Ganesha (optional)

# Mount the NFSv4 root export

sudo mount -t nfs4 -o vers=4.0 <server-ip>:/ /mnt/nfsThis image can run either the kernel NFS server (default) or NFS Ganesha (user-space NFS server).



# Example:To use Ganesha set the environment variable `USE_GANESHA=1` when running the container. Example:

sudo mount -t nfs4 -o vers=4.0 172.17.0.2:/ /mnt/nfs

``````sh

docker run -d --name nfs-ganesha --privileged \

**Verify the mount:**  -e NFS_SIZE_MB=1024 \

  -e USE_GANESHA=1 \

```bash  -p 2049:2049 \

df -h /mnt/nfs  ghcr.io/knightrider2070/suse-nfs-server

ls -la /mnt/nfs```

```

Notes:

**Unmount when done:**- The image will attempt to install `nfs-ganesha` at build time; if the package is not

  available on the chosen base repository, the build will continue but Ganesha won't be present in the image.

```bash- A default config is provided at `/etc/ganesha/ganesha.conf` that exports `/mnt/nfs-share` using the VFS FSAL.

sudo umount /mnt/nfs- Ganesha logs will be written to `/var/log/ganesha.log` and general runtime logs to `/var/log/nfs-server.log`.

```

Important notes about NFS Ganesha and NFSv4

---

- NFS Ganesha is typically used as an NFSv4 server only. The default `config/ganesha.conf`

## **🐳 Advanced Usage**  included with this project configures Ganesha for NFSv4 (see `Protocols = 4;`).

- NFSv4 (as served by Ganesha) does not use kernel `rpc.mountd` or interact with `rpcbind`

### **Custom Storage Size**  in the same way as kernel-space NFS. As a result, client tools that rely on the RPC

  portmapper protocol (for example `showmount`) will not list exports served by Ganesha.

```bash  This is expected behaviour — Ganesha advertises NFSv4 exports differently.

docker run -d --name nfs-server \- If you need to verify Ganesha exports, check `/var/log/ganesha.log` or use NFSv4-aware

  --cap-drop ALL \  client commands to mount and test the export directly (e.g., `mount -t nfs4`).

  --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER \

  --cap-add FSETID --cap-add NET_BIND_SERVICE --cap-add SETGID --cap-add SETUID \If you prefer to run a custom Ganesha configuration, mount your config file into the container at `/etc/ganesha/ganesha.conf`.

  -p 2049:2049 -p 20048:20048 -p 111:111 \
  -e NFS_SIZE_MB=5120 \
  ghcr.io/knightrider2070/suse-nfs-server
```

### **Custom Ganesha Configuration**

You can provide your own `ganesha.conf` file:

```bash
docker run -d --name nfs-server \
  --cap-drop ALL \
  --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER \
  --cap-add FSETID --cap-add NET_BIND_SERVICE --cap-add SETGID --cap-add SETUID \
  -p 2049:2049 -p 20048:20048 -p 111:111 \
  -v ./my-ganesha.conf:/etc/ganesha/ganesha.conf:ro \
  -e NFS_SIZE_MB=1024 \
  ghcr.io/knightrider2070/suse-nf-server
```

### **Docker Compose Example**

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

## **🏗️ Architecture**

This implementation runs all required services in a **single container**:

1. **rpcbind** – Port mapper service (RPC portmapper on port 111)
2. **dbus-daemon** – System message bus (required by NFS-Ganesha)
3. **ganesha.nfsd** – NFS-Ganesha server (NFSv4 on port 2049)

All services start automatically and are managed by the entrypoint script.

### **Why All Services in One Container?**

While the original [contained-ganesha](https://github.com/NicolasT/contained-ganesha) project uses separate containers for each service (following microservices principles), this implementation combines them for simplicity and ease of deployment in single-server scenarios. For production Kubernetes deployments, consider using the multi-container approach.

---

## **📝 Differences from Kernel NFS**

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

## **🔧 Troubleshooting**

### **Check Container Logs**

```bash
docker logs nfs-server
```

### **Verify Services are Running**

```bash
# Check rpcbind
docker exec nfs-server rpcinfo -p

# Check Ganesha is listening
docker exec nfs-server ss -tlnp | grep 2049
```

### **Test from Host**

```bash
# Check if NFS port is accessible
nc -zv <server-ip> 2049

# Try to show mount info
showmount -e <server-ip>
```

### **Common Issues**

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

## **🎯 Use Cases**

- **Development/Testing** – Quick NFS server for testing applications
- **Container Storage** – Shared storage for containerized applications
- **Kubernetes** – NFS-based PersistentVolumes (consider multi-container approach)
- **Media Servers** – Share media libraries across devices
- **Backup Storage** – Central backup location for multiple machines

---

## **🌍 Contribute & Get Support**

💡 **Contributions welcome!** If you have improvements or bug fixes, feel free to submit a PR or create an issue.

🔗 **GitHub Repository:**  
[![GitHub](https://img.shields.io/badge/GitHub-Repo-blue?logo=github&style=flat-square)](https://github.com/KnightRider2070/suse-nfs-server)

🐞 **Report Issues & Request Features:**  
[![GitHub Issues](https://img.shields.io/badge/GitHub-Issues-red?logo=github&style=flat-square)](https://github.com/KnightRider2070/suse-nfs-server/issues)

---

## **📚 References**

- [NFS-Ganesha Project](https://nfs-ganesha.github.io/)
- [contained-ganesha](https://github.com/NicolasT/contained-ganesha) – Inspiration for this implementation
- [NFSv4 RFC 7530](https://tools.ietf.org/html/rfc7530)

---

## **📄 License**

This project is licensed under the terms specified in the LICENSE file.

---

**Enjoy a modern, secure, and flexible NFSv4 server experience! 🚀**
