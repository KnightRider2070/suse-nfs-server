# openSUSE NFS Server Dockerfile
# Maintainer: KnightRider2070
# Description: Lightweight and containerized NFS Server with runtime-configurable storage size.

FROM opensuse/leap:15.5

# Set non-interactive mode for package management
ENV ZYPP_NO_TTY=1 \
    NFS_SIZE_MB=100 \
    MONITOR_INTERVAL=1

# Install required packages
RUN zypper --non-interactive ref && \
    zypper --non-interactive install -y \
    nfs-kernel-server rpcbind nfs-client e2fsprogs iproute2 && \
    zypper clean --all

# Create necessary directories and NFS share
RUN mkdir -p /mnt/nfs-share /nfs-share && chmod 777 /nfs-share

# Define NFS export rules
RUN echo "/mnt/nfs-share *(rw,sync,no_root_squash,no_subtree_check,fsid=0)" > /etc/exports

# Set up required NFS service ports
EXPOSE 2049/tcp 2049/udp 20048/tcp 20048/udp

# Copy the entrypoint script and make it executable
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use entrypoint script for service management
CMD ["/entrypoint.sh"]

#docker run --privileged --name nfs-server -p 2049:2049 -p 20048:20048 nfs-server
#mount.nfs4 -v  172.17.0.2:/ /mnt/share