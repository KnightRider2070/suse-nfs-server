#!/bin/bash
# NFS-Ganesha Entrypoint Script
# Starts all required services for NFS-Ganesha in a single container

set -e

LOG_FILE="/dev/stdout"

# Logging function with timestamps
log() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

log "🚀 Starting NFS-Ganesha Server..."
log "System Info: $(uname -a)"

# Get the runtime-configurable NFS storage size (default: 100MB)
NFS_SIZE_MB=${NFS_SIZE_MB:-100}
log "📦 Configuring NFS share with size: ${NFS_SIZE_MB}MB"

# Create or resize the NFS disk image
if [ ! -f /nfs-disk.img ]; then
    log "📝 Creating a new NFS disk image of size ${NFS_SIZE_MB}MB..."
    truncate -s ${NFS_SIZE_MB}M /nfs-disk.img
    mkfs.ext4 -q /nfs-disk.img
else
    log "📝 Existing NFS disk image found. Resizing to ${NFS_SIZE_MB}MB..."
    truncate -s ${NFS_SIZE_MB}M /nfs-disk.img
    e2fsck -f -y /nfs-disk.img || true
    resize2fs /nfs-disk.img
fi

log "💾 Mounting ext4 filesystem for NFS..."
mkdir -p /mnt/nfs-share
mount -o loop /nfs-disk.img /mnt/nfs-share || {
    log "❌ Failed to mount /nfs-disk.img"
    exit 1
}
chmod 777 /mnt/nfs-share

# Setup tmpfiles for rpcbind
log "🔧 Setting up rpcbind runtime directories..."
mkdir -p /run/rpcbind /var/lib/rpcbind
chmod 755 /run/rpcbind

# Start rpcbind
log "🔌 Starting rpcbind..."
rpcbind -w -f &
RPCBIND_PID=$!
sleep 2

# Wait for rpcbind to be ready
TIMEOUT=10
RPCBIND_UP=0
for i in $(seq 1 $TIMEOUT); do
    log "⏳ Waiting for rpcbind to be up ($i/$TIMEOUT)..."
    if rpcinfo -T tcp 127.0.0.1 100000 4 >/dev/null 2>&1; then
        log "✅ rpcbind is ready"
        RPCBIND_UP=1
        break
    fi
    sleep 1
done

if [ $RPCBIND_UP -ne 1 ]; then
    log "❌ Timeout while waiting for rpcbind to be up"
    exit 1
fi

# Setup and start dbus-daemon
log "🔧 Setting up dbus-daemon..."
mkdir -p /run/dbus /var/lib/dbus
if [ ! -f /var/lib/dbus/machine-id ]; then
    dbus-uuidgen --ensure=/var/lib/dbus/machine-id
fi

log "🔌 Starting dbus-daemon..."
dbus-daemon --system --nofork --nopidfile &
DBUS_PID=$!
sleep 2

# Wait for dbus to be ready
DBUS_UP=0
for i in $(seq 1 $TIMEOUT); do
    log "⏳ Waiting for dbus-daemon to be up ($i/$TIMEOUT)..."
    if [ -S /run/dbus/system_bus_socket ]; then
        log "✅ dbus-daemon is ready"
        DBUS_UP=1
        break
    fi
    sleep 1
done

if [ $DBUS_UP -ne 1 ]; then
    log "❌ Timeout while waiting for dbus-daemon to be up"
    exit 1
fi

# Validate Ganesha configuration
if [ ! -f /etc/ganesha/ganesha.conf ]; then
    log "❌ Ganesha config not found at /etc/ganesha/ganesha.conf"
    exit 1
fi
log "✅ Using Ganesha config: /etc/ganesha/ganesha.conf"

# Setup Ganesha runtime directory
mkdir -p /run/ganesha /var/lib/nfs/ganesha
chmod 755 /run/ganesha /var/lib/nfs/ganesha

# Start NFS-Ganesha in foreground
log "🚀 Starting NFS-Ganesha (NFSv4 user-space server)..."
log "📡 NFS Port: ${NFS_PORT:-2049}, MountD Port: ${MOUNTD_PORT:-20048}"

# Function to cleanup on exit
cleanup() {
    log "🛑 Shutting down NFS-Ganesha server..."
    kill $GANESHA_PID 2>/dev/null || true
    kill $DBUS_PID 2>/dev/null || true
    kill $RPCBIND_PID 2>/dev/null || true
    umount /mnt/nfs-share 2>/dev/null || true
    log "👋 Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start ganesha in foreground mode
exec ganesha.nfsd -F -L /dev/stderr -f /etc/ganesha/ganesha.conf -p /run/ganesha/ganesha.pid
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
