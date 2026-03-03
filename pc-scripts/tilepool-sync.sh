#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# Configuration
# ------------------------------
LOCAL="/tilepool"
PARTIAL_DIR=".rsync-partial"
MAX_RETRIES=5
RETRY_DELAY=15  # seconds

declare -A NODES
NODES["130.242.128.158"]="/mnt/tilepool-01"
NODES["130.242.128.116"]="/mnt/tilepool-02"
NODES["130.242.128.29"]="/mnt/tilepool-03"

# ------------------------------
# Detect local IP
# ------------------------------
MY_IP=$(ip -4 route get 1.1.1.1 | awk '{print $7; exit}')

# ------------------------------
# Lock to prevent multiple runs
# ------------------------------
LOCK="/tmp/tilepool-sync.lock"
exec 9>"$LOCK" || exit 1
flock -n 9 || { echo "Sync already running"; exit 0; }

# ------------------------------
# Ensure partial directory exists
# ------------------------------
mkdir -p "$LOCAL/$PARTIAL_DIR"

# ------------------------------
# Clean up old partial files
# ------------------------------
find "$LOCAL/$PARTIAL_DIR" -type f -mtime +7 -delete

# ------------------------------
# Rsync options (modular)
# ------------------------------
RSYNC_CMD=(rsync
    -a
    --ignore-existing
    --partial
    --partial-dir="$PARTIAL_DIR"
    --numeric-ids
    --info=progress2
    --human-readable
    --timeout=60
    --dry-run
)

# ------------------------------
# Sync loop
# ------------------------------
echo "Local IP: $MY_IP"
echo

for IP in "${!NODES[@]}"; do
    REMOTE="${NODES[$IP]}"

    # Skip local node
    [[ "$IP" == "$MY_IP" ]] && {
        echo "Skipping local node $IP ($REMOTE)"
        continue
    }

    # Check mountpoint
    if ! mountpoint -q "$REMOTE"; then
        echo "WARNING: $REMOTE not mounted — skipping"
        continue
    fi

    echo "Syncing from $IP ($REMOTE → $LOCAL)"

    ATTEMPT=1
    while (( ATTEMPT <= MAX_RETRIES )); do
        echo "Attempt $ATTEMPT / $MAX_RETRIES"

        # Run rsync
        "${RSYNC_CMD[@]}" "$REMOTE/" "$LOCAL/"
        STATUS=$?

        if [[ $STATUS -eq 0 ]]; then
            echo "Sync from $IP completed successfully"
            break
        else
            echo "⚠ rsync failed (status $STATUS) — retrying in $RETRY_DELAY seconds..."
            sleep "$RETRY_DELAY"
            ((ATTEMPT++))
        fi
    done

    if (( ATTEMPT > MAX_RETRIES )); then
        echo "❌ Failed syncing from $IP after $MAX_RETRIES attempts"
    fi

    echo
done

echo "Tilepool sync completed."
