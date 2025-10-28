#!/bin/bash

LOG_FILE="/var/log/nfs-server.log"
touch "$LOG_FILE"

# Logging function with timestamps
log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] 🔧 $1" | tee -a "$LOG_FILE"
}

log "Starting NFS Server..."
log "System Info: $(uname -a)"

# Determine whether to use Ganesha (user-space NFS) or kernel NFS server
USE_GANESHA=${USE_GANESHA:-0}
if [[ "$USE_GANESHA" =~ ^(1|yes|true|on)$ ]]; then
    log "USE_GANESHA is enabled — starting NFS Ganesha instead of kernel NFSd"
else
    log "Using kernel NFS server (default behavior)"
fi

# Get the runtime-configurable NFS storage size (default: 100MB)
NFS_SIZE_MB=${NFS_SIZE_MB:-100}
log "Configuring NFS share with size: ${NFS_SIZE_MB}MB"

# Create or resize the NFS disk image
if [ ! -f /nfs-disk.img ]; then
    log "Creating a new NFS disk image of size ${NFS_SIZE_MB}MB..."
    truncate -s ${NFS_SIZE_MB}M /nfs-disk.img
    mkfs.ext4 /nfs-disk.img
else
    log "Existing NFS disk image found. Resizing to ${NFS_SIZE_MB}MB..."
    truncate -s ${NFS_SIZE_MB}M /nfs-disk.img
    e2fsck -f /nfs-disk.img
    resize2fs /nfs-disk.img
fi

log "Mounting ext4 filesystem for NFS..."
mkdir -p /mnt/nfs-share
mount -o loop /nfs-disk.img /mnt/nfs-share || {
    log "❌ Failed to mount /nfs-disk.img"
    exit 1
}

if [[ "$USE_GANESHA" =~ ^(1|yes|true|on)$ ]]; then
    # NFS Ganesha (user-space) is typically NFSv4-only and does not interact with
    # kernel-space nfsd, rpc.mountd or rpcbind the same way kernel NFS does. Skip
    # starting kernel NFS subsystems and start ganesha directly.
    log "USE_GANESHA enabled — starting NFS Ganesha (NFSv4). Skipping kernel nfsd/rpc.mountd/rpcbind."

    # Ensure Ganesh config exists at expected location; if not, warn
    if [ ! -f /etc/ganesha/ganesha.conf ]; then
        log "⚠️  Ganesha config not found at /etc/ganesha/ganesha.conf — using embedded defaults may fail"
    else
        log "Using Ganesha config: /etc/ganesha/ganesha.conf"
    fi

    log "Starting NFS Ganesha (ganesha.nfsd) in background..."
    if command -v ganesha.nfsd >/dev/null 2>&1; then
        # Start ganesha in foreground-style background so container stays alive
        ganesha.nfsd -L /var/log/ganesha.log &>>"$LOG_FILE" &
        sleep 2
        log "Ganesha started (pid: $!)"
    else
        log "❌ ganesha.nfsd binary not found. Is nfs-ganesha installed?"
    fi
else
    # Ensure the NFS kernel module is available
    mkdir -p /proc/fs/nfsd
    mount -t nfsd nfsd /proc/fs/nfsd

    log "Starting rpcbind..."
    rpcbind -w -d &>>"$LOG_FILE"
    sleep 2

    log "Starting rpc.statd..."
    rpc.statd --no-notify -F &>>"$LOG_FILE" &
    sleep 2

    log "Exporting NFS shares..."
    exportfs -rv | tee -a "$LOG_FILE"

    log "Starting rpc.nfsd ..."
    rpc.nfsd -N 2 &>>"$LOG_FILE"
    sleep 2

    log "Starting rpc.mountd..."
    rpc.mountd -N 2 -V 4 -p 20048 &>>"$LOG_FILE" &
fi

MONITOR_INTERVAL=${MONITOR_INTERVAL:-1}
log "Monitoring NFS client connections every ${MONITOR_INTERVAL} seconds..."

declare -A PREV_CONNECTIONS

while true; do

    # Grab active connections (peer/client side is column $5)
    mapfile -t CURRENT_CONNECTIONS < <(
        ss -tn state established '( sport = :2049 )' |
            awk 'NR>1 {print $4}' |
            sed 's/\r$//' |
            grep -v '^[[:space:]]*$' ||
            true
    )

    # Build CURRENT_CONNECTIONS_MAP from CURRENT_CONNECTIONS
    unset CURRENT_CONNECTIONS_MAP
    declare -A CURRENT_CONNECTIONS_MAP
    for conn in "${CURRENT_CONNECTIONS[@]}"; do
        [[ -n "$conn" ]] && CURRENT_CONNECTIONS_MAP["$conn"]=1
    done

    # Detect new connections
    new_count=0
    for conn in "${CURRENT_CONNECTIONS[@]}"; do
        if [[ -z "${PREV_CONNECTIONS[$conn]}" ]]; then
            log "➕ New NFS connection: $conn"
            ((new_count++))
        fi
    done

    # Detect disconnections
    disc_count=0
    for conn in "${!PREV_CONNECTIONS[@]}"; do
        if [[ -z "${CURRENT_CONNECTIONS_MAP[$conn]}" ]]; then
            log "➖ NFS client disconnected: $conn"
            unset "PREV_CONNECTIONS[$conn]"
            ((disc_count++))
        fi
    done

    # Update PREV_CONNECTIONS
    for conn in "${CURRENT_CONNECTIONS[@]}"; do
        PREV_CONNECTIONS["$conn"]=1
    done

    sleep "$MONITOR_INTERVAL"
done
