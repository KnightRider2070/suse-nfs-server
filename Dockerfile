# openSUSE NFS-Ganesha Server Dockerfile
# Maintainer: KnightRider2070
# Description: Lightweight containerized NFSv4 server using NFS-Ganesha (user-space NFS)
# Based on contained-ganesha approach: https://github.com/NicolasT/contained-ganesha

FROM opensuse/leap:15.5

# Set non-interactive mode for package management
ENV ZYPP_NO_TTY=1 \
    NFS_SIZE_MB=100 \
    NFS_PORT=2049 \
    MOUNTD_PORT=20048 \
    USE_VOLUME=false \
    NFS_VOLUME_PATH=/nfs-volume

# Install required packages for NFS-Ganesha
RUN zypper --non-interactive ref && \
    # Install NFS-Ganesha and supporting services
    zypper --non-interactive install -y \
        nfs-ganesha \
        nfs-ganesha-vfs \
        rpcbind \
        dbus-1 \
        e2fsprogs \
        iproute2 \
        util-linux \
        systemd \
        && \
    zypper clean --all && \
    # Create necessary directories
    mkdir -p /mnt/nfs-share /run/ganesha /run/dbus /var/lib/nfs/ganesha && \
    chmod 755 /mnt/nfs-share /run/ganesha && \
    # Remove default ganesha config (we'll provide our own)
    rm -f /etc/ganesha/ganesha.conf

# Set up required NFS service ports
EXPOSE ${NFS_PORT}/tcp ${NFS_PORT}/udp ${MOUNTD_PORT}/tcp ${MOUNTD_PORT}/udp 111/tcp 111/udp

# Copy configuration and scripts
COPY ./config/ganesha.conf /etc/ganesha/ganesha.conf
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Define volumes for runtime data and optional persistent NFS storage
VOLUME ["/run", "/var/lib/nfs/ganesha", "/nfs-volume"]

# Use entrypoint script for service management
ENTRYPOINT ["/entrypoint.sh"]

# Usage examples:
# Run with loopback file (default):
#   docker run -d --name nfs-server \
#     --cap-drop ALL \
#     --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER --cap-add FSETID \
#     --cap-add NET_BIND_SERVICE --cap-add SETGID --cap-add SETUID \
#     -p 2049:2049 -p 20048:20048 -p 111:111 \
#     -e NFS_SIZE_MB=500 \
#     nfs-ganesha-server
#
# Run with Docker volume (persistent storage):
#   docker volume create nfs-data
#   docker run -d --name nfs-server \
#     --cap-drop ALL \
#     --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER --cap-add FSETID \
#     --cap-add NET_BIND_SERVICE --cap-add SETGID --cap-add SETUID \
#     -p 2049:2049 -p 20048:20048 -p 111:111 \
#     -v nfs-data:/nfs-volume \
#     -e USE_VOLUME=true \
#     nfs-ganesha-server
#
# Mount from client (NFSv4):
#   mount -t nfs4 -o vers=4.0 <server-ip>:/ /mnt/nfs
