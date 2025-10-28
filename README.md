# **📦 suse-nfs-server - Lightweight, Containerized NFS Server**

**suse-nfs-server** is a highly flexible, containerized **NFS server** built on **openSUSE Leap 15.5**, designed for **easy deployment**, and **dynamic storage configuration** without the need for Docker volumes.

---

## **✨ Features**

**Supports NFSv3 & NFSv4** – Compatible with modern clients  
**Containerized for Flexibility** – Runs seamlessly in **Docker & Kubernetes**  
**No Docker Volume Required** – Uses a **loopback ext4 filesystem** for persistence  

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
| `USE_GANESHA` | `0` | If set to `1` (or `true`), run NFS Ganesha (user-space NFS) instead of kernel nfsd |

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

---

## **🌍 Contribute & Get Support**

💡 **Contributions welcome!** If you have improvements or bug fixes, feel free to submit a PR or create an issue.

🔗 **GitHub Repository:**  
[![GitHub](https://img.shields.io/badge/GitHub-Repo-blue?logo=github&style=flat-square)](https://github.com/KnightRider2070/suse-nfs-server)  
Browse the source code, fork the project, and submit pull requests.

🐞 **Report Issues & Request Features:**  
[![GitHub Issues](https://img.shields.io/badge/GitHub-Issues-red?logo=github&style=flat-square)](https://github.com/KnightRider2070/suse-nfs-server/issues)  
If you encounter problems, report them on GitHub Issues.

---

Enjoy a **lightweight**, **flexible** NFS server experience on openSUSE Leap!

---

## Using NFS Ganesha (optional)

This image can run either the kernel NFS server (default) or NFS Ganesha (user-space NFS server).

To use Ganesha set the environment variable `USE_GANESHA=1` when running the container. Example:

```sh
docker run -d --name nfs-ganesha --privileged \
  -e NFS_SIZE_MB=1024 \
  -e USE_GANESHA=1 \
  -p 2049:2049 \
  ghcr.io/knightrider2070/suse-nfs-server
```

Notes:
- The image will attempt to install `nfs-ganesha` at build time; if the package is not
  available on the chosen base repository, the build will continue but Ganesha won't be present in the image.
- A default config is provided at `/etc/ganesha/ganesha.conf` that exports `/mnt/nfs-share` using the VFS FSAL.
- Ganesha logs will be written to `/var/log/ganesha.log` and general runtime logs to `/var/log/nfs-server.log`.

Important notes about NFS Ganesha and NFSv4

- NFS Ganesha is typically used as an NFSv4 server only. The default `config/ganesha.conf`
  included with this project configures Ganesha for NFSv4 (see `Protocols = 4;`).
- NFSv4 (as served by Ganesha) does not use kernel `rpc.mountd` or interact with `rpcbind`
  in the same way as kernel-space NFS. As a result, client tools that rely on the RPC
  portmapper protocol (for example `showmount`) will not list exports served by Ganesha.
  This is expected behaviour — Ganesha advertises NFSv4 exports differently.
- If you need to verify Ganesha exports, check `/var/log/ganesha.log` or use NFSv4-aware
  client commands to mount and test the export directly (e.g., `mount -t nfs4`).

If you prefer to run a custom Ganesha configuration, mount your config file into the container at `/etc/ganesha/ganesha.conf`.
