#!/bin/bash
# =============================================================================
# ganesha-entrypoint.sh
# Entrypoint for a containerised NFS-Ganesha NFSv4 server.
#
# Storage modes:
#   USE_VOLUME=true   -> bind-mounts a Docker volume at NFS_VOLUME_PATH
#   USE_VOLUME=false  -> creates a loopback ext4 image (default, ephemeral)
#
# Environment variables:
#   USE_VOLUME       true | false  (default: false)
#   NFS_VOLUME_PATH  path to the Docker volume  (default: /nfs-volume)
#   NFS_SIZE_MB      loopback image size in MB   (default: 100)
#   NFS_PORT         NFS listening port           (default: 2049)
#   MOUNTD_PORT      MountD port                  (default: 20048)
# =============================================================================
set -euo pipefail

LOG_FILE="/dev/stdout"

### ───────────────────────────── Logging ──────────────────────────────────────

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

### ──────────────────────── Service wait helper ──────────────────────────────

# Usage: wait_for <label> <check_command> [timeout_seconds]
wait_for() {
  local label="$1" timeout="${3:-10}"
  shift
  local check_cmd="$1"

  local i
  for (( i=1; i<=timeout; i++ )); do
    log "Waiting for ${label} ($i/${timeout})..."
    if eval "$check_cmd" >/dev/null 2>&1; then
      log "${label} is ready"
      return 0
    fi
    sleep 1
  done

  log "ERROR: Timeout waiting for ${label} after ${timeout}s"
  return 1
}

### ──────────────────────────── Variables ─────────────────────────────────────

USE_VOLUME="${USE_VOLUME:-false}"
NFS_VOLUME_PATH="${NFS_VOLUME_PATH:-/nfs-volume}"
NFS_SIZE_MB="${NFS_SIZE_MB:-100}"
NFS_PORT="${NFS_PORT:-2049}"
MOUNTD_PORT="${MOUNTD_PORT:-20048}"
SHARE_PATH="/mnt/nfs-share"

RPCBIND_PID=""
DBUS_PID=""
GANESHA_PID=""

### ────────────────────────── Cleanup / trap ──────────────────────────────────

cleanup() {
  log "Shutting down NFS-Ganesha server..."

  # Stop services in reverse order
  [[ -n "$GANESHA_PID" ]] && { kill "$GANESHA_PID" 2>/dev/null; wait "$GANESHA_PID" 2>/dev/null || true; }
  [[ -n "$DBUS_PID" ]]    && { kill "$DBUS_PID"    2>/dev/null; wait "$DBUS_PID"    2>/dev/null || true; }
  [[ -n "$RPCBIND_PID" ]] && { kill "$RPCBIND_PID" 2>/dev/null; wait "$RPCBIND_PID" 2>/dev/null || true; }

  # Unmount
  if [[ "$USE_VOLUME" == "true" ]]; then
    [[ "$NFS_VOLUME_PATH" != "$SHARE_PATH" ]] && umount "$SHARE_PATH" 2>/dev/null || true
  else
    umount "$SHARE_PATH" 2>/dev/null || true
  fi

  log "Shutdown complete"
  exit 0
}

trap cleanup SIGTERM SIGINT EXIT

### ──────────────────────────── Storage ───────────────────────────────────────

setup_storage() {
  mkdir -p "$SHARE_PATH"

  if [[ "$USE_VOLUME" == "true" ]]; then
    log "Storage mode: Docker volume"

    if mountpoint -q "$NFS_VOLUME_PATH"; then
      log "Docker volume detected at $NFS_VOLUME_PATH"

      if [[ "$NFS_VOLUME_PATH" != "$SHARE_PATH" ]]; then
        log "Bind mounting $NFS_VOLUME_PATH -> $SHARE_PATH"
        mount --bind "$NFS_VOLUME_PATH" "$SHARE_PATH" || {
          log "ERROR: Failed to bind mount $NFS_VOLUME_PATH"
          exit 1
        }
      fi

      log "Using Docker volume for NFS storage (persistent)"
    else
      log "WARN: No volume mounted at $NFS_VOLUME_PATH, falling back to loopback mode"
      USE_VOLUME=false
    fi
  fi

  if [[ "$USE_VOLUME" != "true" ]]; then
    log "Storage mode: loopback file (${NFS_SIZE_MB} MB)"

    if [[ ! -f /nfs-disk.img ]]; then
      log "Creating new NFS disk image (${NFS_SIZE_MB} MB)..."
      truncate -s "${NFS_SIZE_MB}M" /nfs-disk.img
      mkfs.ext4 -q /nfs-disk.img
    else
      log "Existing disk image found, resizing to ${NFS_SIZE_MB} MB..."
      truncate -s "${NFS_SIZE_MB}M" /nfs-disk.img
      e2fsck -f -y /nfs-disk.img || true
      resize2fs /nfs-disk.img
    fi

    log "Mounting ext4 filesystem..."
    mount -o loop /nfs-disk.img "$SHARE_PATH" || {
      log "ERROR: Failed to mount /nfs-disk.img"
      exit 1
    }
  fi

  chmod 777 "$SHARE_PATH"
  log "NFS share ready at $SHARE_PATH"
}

### ─────────────────────────── rpcbind ───────────────────────────────────────

start_rpcbind() {
  log "Setting up rpcbind..."
  mkdir -p /run/rpcbind /var/lib/rpcbind
  chmod 755 /run/rpcbind

  log "Starting rpcbind..."
  rpcbind -w -f &
  RPCBIND_PID=$!

  wait_for "rpcbind" "rpcinfo -T tcp 127.0.0.1 100000 4" 10
}

### ──────────────────────────── dbus ─────────────────────────────────────────

start_dbus() {
  log "Setting up dbus-daemon..."
  mkdir -p /run/dbus /var/lib/dbus
  [[ ! -f /var/lib/dbus/machine-id ]] && dbus-uuidgen --ensure=/var/lib/dbus/machine-id

  log "Starting dbus-daemon..."
  dbus-daemon --system --nofork --nopidfile &
  DBUS_PID=$!

  wait_for "dbus-daemon" "[ -S /run/dbus/system_bus_socket ]" 10
}

### ─────────────────────────── Ganesha ───────────────────────────────────────

start_ganesha() {
  local conf="/etc/ganesha/ganesha.conf"

  if [[ ! -f "$conf" ]]; then
    log "ERROR: Ganesha config not found at $conf"
    exit 1
  fi
  log "Using Ganesha config: $conf"

  mkdir -p /run/ganesha /var/lib/nfs/ganesha
  chmod 755 /run/ganesha /var/lib/nfs/ganesha

  log "Starting NFS-Ganesha (NFSv4 user-space server)..."
  log "NFS port: ${NFS_PORT}, MountD port: ${MOUNTD_PORT}"

  # Run in foreground but NOT via exec — we need the shell alive for the trap.
  ganesha.nfsd -F -L /dev/stderr -f "$conf" -p /run/ganesha/ganesha.pid &
  GANESHA_PID=$!

  # Brief health check: make sure the process didn't die immediately
  sleep 2
  if ! kill -0 "$GANESHA_PID" 2>/dev/null; then
    log "ERROR: ganesha.nfsd exited immediately (check /dev/stderr for details)"
    exit 1
  fi

  log "NFS-Ganesha started (PID: $GANESHA_PID)"
}

### ──────────────────────────── Main ─────────────────────────────────────────

main() {
  log "================================================"
  log "Starting NFS-Ganesha Server"
  log "System: $(uname -r)"
  log "================================================"

  setup_storage
  start_rpcbind
  start_dbus
  start_ganesha

  log "================================================"
  log "NFS-Ganesha is running and serving $SHARE_PATH"
  log "Clients can mount via:  mount -t nfs -o vers=4.1 <this-host>:/ /mnt/nfs"
  log "================================================"

  # Wait for ganesha to exit. If it dies, the EXIT trap fires cleanup().
  wait "$GANESHA_PID"
}

main "$@"
