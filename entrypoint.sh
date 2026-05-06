#!/bin/bash
# =============================================================================
# ganesha-entrypoint.sh
# Entrypoint for a containerised NFS-Ganesha NFSv4 server.
#
# Storage modes:
#   USE_VOLUME=true   -> bind-mounts a Docker volume at NFS_VOLUME_PATH
#   USE_VOLUME=false  -> creates a loopback ext4 image (default, ephemeral)
#
# Seed (first-run only):
#   On the very first start, if SEED_DIR exists and has files, its contents
#   are copied into the NFS share. A hidden marker file tracks initialisation
#   so this never runs again — even across container recreations (the marker
#   lives on the NFS volume itself).
#
# Environment variables:
#   USE_VOLUME       true | false                     (default: false)
#   NFS_VOLUME_PATH  path to the Docker volume        (default: /nfs-volume)
#   NFS_SIZE_MB      loopback image size in MB         (default: 100)
#   NFS_PORT         NFS listening port                (default: 2049)
#   MOUNTD_PORT      MountD port                       (default: 20048)
#   SEED_DIR         container path with seed files    (default: /opt/nfs-seed)
#   SEED_OWNER       uid:gid to chown seeded files to  (default: 1000:1000)
# =============================================================================
set -euo pipefail

LOG_FILE="/dev/stdout"

### ───────────────────────────── Logging ──────────────────────────────────────

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

### ──────────────────────── Service wait helper ──────────────────────────────

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

SEED_DIR="${SEED_DIR:-/opt/nfs-seed}"
SEED_OWNER="${SEED_OWNER:-1000:1000}"

# Hidden marker file — lives ON the NFS volume so it survives container
# recreations but is invisible to normal ls
SEED_MARKER=".nfs-initialized"

RPCBIND_PID=""
DBUS_PID=""
GANESHA_PID=""

### ────────────────────────── Cleanup / trap ──────────────────────────────────

cleanup() {
  log "Shutting down NFS-Ganesha server..."

  [[ -n "$GANESHA_PID" ]] && { kill "$GANESHA_PID" 2>/dev/null; wait "$GANESHA_PID" 2>/dev/null || true; }
  [[ -n "$DBUS_PID" ]]    && { kill "$DBUS_PID"    2>/dev/null; wait "$DBUS_PID"    2>/dev/null || true; }
  [[ -n "$RPCBIND_PID" ]] && { kill "$RPCBIND_PID" 2>/dev/null; wait "$RPCBIND_PID" 2>/dev/null || true; }

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

### ──────────────────── First-run seed (one-time only) ───────────────────────
#
# Copies template files from SEED_DIR (inside the Docker image) into the NFS
# share on the very first start. The hidden marker file tracks whether this
# has already happened. Because the marker lives on the NFS volume itself,
# it survives container recreations — seed only ever runs once per volume.

seed_nfs_share() {
  local marker_path="${SHARE_PATH}/${SEED_MARKER}"

  # ── Already initialised? Skip entirely. ──
  if [[ -f "$marker_path" ]]; then
    local init_date; init_date=$(cat "$marker_path" 2>/dev/null || echo "unknown")
    log "NFS share already initialised (seeded on: ${init_date}). Skipping seed."
    return 0
  fi

  # ── No seed directory or empty? Nothing to copy. ──
  if [[ ! -d "$SEED_DIR" ]]; then
    log "No seed directory at $SEED_DIR. Skipping seed."
    return 0
  fi

  # Check if seed dir has any files (including hidden, excluding . and ..)
  local file_count
  file_count=$(find "$SEED_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
  if (( file_count == 0 )); then
    log "Seed directory $SEED_DIR is empty. Skipping seed."
    return 0
  fi

  # ── First run: copy seed files ──
  log "First-time start detected. Seeding NFS share from $SEED_DIR ($file_count items)..."

  # Copy everything preserving structure, permissions, and timestamps
  # Using cp -a (archive): recursive, preserve all attributes, follow nothing
  if cp -a "${SEED_DIR}/." "${SHARE_PATH}/" 2>&1; then
    log "Seed files copied successfully"
  else
    log "ERROR: Failed to copy seed files from $SEED_DIR to $SHARE_PATH"
    log "ERROR: NFS share may be in an incomplete state"
    return 1
  fi

  # Set ownership if specified (Kasm user is typically 1000:1000)
  if [[ -n "$SEED_OWNER" ]]; then
    log "Setting ownership to $SEED_OWNER on seeded files..."
    chown -R "$SEED_OWNER" "$SHARE_PATH"/ 2>/dev/null || {
      log "WARN: Could not set ownership to $SEED_OWNER (continuing anyway)"
    }
  fi

  # Log what was seeded for the record
  log "Seeded contents:"
  find "$SHARE_PATH" -mindepth 1 -maxdepth 2 -not -name "$SEED_MARKER" | sort | while IFS= read -r entry; do
    local rel="${entry#${SHARE_PATH}/}"
    if [[ -d "$entry" ]]; then
      log "  [dir]  $rel/"
    else
      local size; size=$(stat -c%s "$entry" 2>/dev/null || echo "?")
      log "  [file] $rel (${size} bytes)"
    fi
  done

  # ── Write the marker file ──
  # Hidden (dot-prefixed) so it doesn't show up in normal ls
  # Contains the timestamp so you can see when initialisation happened
  echo "$(date -Iseconds)" > "$marker_path"
  chmod 444 "$marker_path"    # read-only to prevent accidental deletion
  chattr +i "$marker_path" 2>/dev/null || true   # immutable if filesystem supports it

  local total_size; total_size=$(du -sh "$SHARE_PATH" 2>/dev/null | awk '{print $1}')
  log "Seed complete. NFS share size: ${total_size:-unknown}"
  log "Marker written: $marker_path"
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

  ganesha.nfsd -F -L /dev/stderr -f "$conf" -p /run/ganesha/ganesha.pid &
  GANESHA_PID=$!

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
  seed_nfs_share
  start_rpcbind
  start_dbus
  start_ganesha

  log "================================================"
  log "NFS-Ganesha is running and serving $SHARE_PATH"
  log "Clients mount via:  mount -t nfs -o vers=4.1 <this-host>:/share /mnt/nfs"
  log "================================================"

  wait "$GANESHA_PID"
}

main "$@"
