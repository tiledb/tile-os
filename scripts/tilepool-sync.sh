#!/usr/bin/env bash
set -euo pipefail

LOCAL="/tilepool"

declare -A NODES
NODES["130.242.128.158"]="/mnt/tilepool-01"
NODES["130.242.128.116"]="/mnt/tilepool-02"
NODES["130.242.128.29"]="/mnt/tilepool-03"

MY_IP=$(ip -4 route get 1.1.1.1 | awk '{print $7; exit}')

echo "Local IP: $MY_IP"
echo

LOCK="/tmp/tilepool-sync.lock"
exec 9>"$LOCK" || exit 1
flock -n 9 || { echo "Sync already running"; exit 0; }

for IP in "${!NODES[@]}"; do
    REMOTE="${NODES[$IP]}"

    if [[ "$IP" == "$MY_IP" ]]; then
        echo "Skipping local node $IP ($REMOTE)"
        continue
    fi

    if mountpoint -q "$REMOTE"; then
        echo "Syncing from $IP ($REMOTE → $LOCAL)"
        rsync -av --ignore-existing "$REMOTE/" "$LOCAL/"
    else
        echo "WARNING: $REMOTE not mounted"
    fi
done

echo
echo "Tilepool sync completed."
