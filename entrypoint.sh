#!/bin/bash

LOG_FILE="/var/log/nfs-server.log"
touch $LOG_FILE

log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] 🔧 $1" | tee -a $LOG_FILE
}

log "Starting NFS Server..."
log "System Info: $(uname -a)"

# Get runtime-configurable NFS size from env variable (default: 100MB)
NFS_SIZE_MB=${NFS_SIZE_MB:-100}

log "Configuring NFS share with size: ${NFS_SIZE_MB}MB"

# Ensure the NFS disk image exists or resize it
if [ ! -f /nfs-disk.img ]; then
    log "Creating new NFS disk image of size ${NFS_SIZE_MB}MB..."
    truncate -s ${NFS_SIZE_MB}M /nfs-disk.img
    mkfs.ext4 /nfs-disk.img
else
    log "Existing NFS disk image found. Resizing to ${NFS_SIZE_MB}MB..."
    truncate -s ${NFS_SIZE_MB}M /nfs-disk.img
    e2fsck -f /nfs-disk.img
    resize2fs /nfs-disk.img
fi

# Mount the filesystem
log "Mounting ext4 filesystem for NFS..."
mount -o loop /nfs-disk.img /mnt/nfs-share || {
    log "❌ Failed to mount /nfs-disk.img"
    exit 1
}

# Start essential NFS services
log "Starting rpcbind..."
rpcbind -w -d &>>$LOG_FILE
sleep 2

log "Starting rpc.statd..."
rpc.statd --no-notify -F &>>$LOG_FILE &
sleep 2

log "Exporting NFS shares..."
exportfs -rv | tee -a $LOG_FILE

log "Starting rpc.nfsd (Disabling Client Recovery Tracking)..."
rpc.nfsd --no-nfs-version 2 --no-client-tracking -d &>>$LOG_FILE
sleep 2

log "Starting rpc.mountd..."
exec rpc.mountd -N 2 -V 4 -p 20048 -F &>>$LOG_FILE
