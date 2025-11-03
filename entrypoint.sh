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

# Determine storage mode: Docker volume or loopback file
USE_VOLUME=${USE_VOLUME:-false}
NFS_VOLUME_PATH=${NFS_VOLUME_PATH:-/nfs-volume}
NFS_SIZE_MB=${NFS_SIZE_MB:-100}

mkdir -p /mnt/nfs-share

if [ "$USE_VOLUME" = "true" ]; then
    # Docker Volume Mode
    log "📦 Using Docker volume mode"
    
    # Check if volume is mounted
    if mountpoint -q "$NFS_VOLUME_PATH"; then
        log "✅ Docker volume detected at $NFS_VOLUME_PATH"
        
        # Bind mount the volume to /mnt/nfs-share
        if [ "$NFS_VOLUME_PATH" != "/mnt/nfs-share" ]; then
            log "💾 Bind mounting $NFS_VOLUME_PATH to /mnt/nfs-share..."
            mount --bind "$NFS_VOLUME_PATH" /mnt/nfs-share || {
                log "❌ Failed to bind mount $NFS_VOLUME_PATH"
                exit 1
            }
        fi
        
        log "✅ Using Docker volume for NFS storage (persistent)"
    else
        log "⚠️  No volume mounted at $NFS_VOLUME_PATH, falling back to loopback mode"
        USE_VOLUME=false
    fi
fi

if [ "$USE_VOLUME" != "true" ]; then
    # Loopback File Mode (default)
    log "📦 Using loopback file mode with size: ${NFS_SIZE_MB}MB"
    
    # Create or resize the NFS disk image
    if [ ! -f /nfs-disk.img ]; then
        log "📝 Creating a new NFS disk image of size ${NFS_SIZE_MB}MB..."
        truncate -s "${NFS_SIZE_MB}M" /nfs-disk.img
        mkfs.ext4 -q /nfs-disk.img
    else
        log "📝 Existing NFS disk image found. Resizing to ${NFS_SIZE_MB}MB..."
        truncate -s "${NFS_SIZE_MB}M" /nfs-disk.img
        e2fsck -f -y /nfs-disk.img || true
        resize2fs /nfs-disk.img
    fi

    log "💾 Mounting ext4 filesystem for NFS..."
    mount -o loop /nfs-disk.img /mnt/nfs-share || {
        log "❌ Failed to mount /nfs-disk.img"
        exit 1
    }
fi

chmod 777 /mnt/nfs-share
log "✅ NFS share ready at /mnt/nfs-share"

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
    kill "$GANESHA_PID" 2>/dev/null || true
    kill "$DBUS_PID" 2>/dev/null || true
    kill "$RPCBIND_PID" 2>/dev/null || true
    
    # Only unmount if not using Docker volume mode
    if [ "$USE_VOLUME" != "true" ]; then
        umount /mnt/nfs-share 2>/dev/null || true
    else
        # Unmount bind mount if different path
        if [ "$NFS_VOLUME_PATH" != "/mnt/nfs-share" ]; then
            umount /mnt/nfs-share 2>/dev/null || true
        fi
    fi
    
    log "👋 Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start ganesha in foreground mode
exec ganesha.nfsd -F -L /dev/stderr -f /etc/ganesha/ganesha.conf -p /run/ganesha/ganesha.pid
