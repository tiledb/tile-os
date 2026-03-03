#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 -v <VMID>"
#    exit 1
}

# Parse arguments
while getopts ":v:" opt; do
  case $opt in
    v) VMID="$OPTARG";;
    *) usage;;
  esac
done

# Check if VMID is provided
if [ -z "$VMID" ]; then
    usage
fi

# Check if VM exists
qm list | awk 'NR>1 {print $1}' | grep -q "^$VMID$"
if [ $? -ne 0 ]; then
    echo "Error: VMID $VMID not found"
#    exit 1
fi

echo "Disconnecting and reconnecting USB devices for VMID $VMID..."

# Get list of USB devices attached to VM
USB_LINES=$(qm config $VMID | grep usb)
if [ -z "$USB_LINES" ]; then
    echo "No USB devices attached to VMID $VMID"
#    exit 0
fi

# Loop through each USB device
while read -r usb_line; do
    USB_SLOT=$(echo "$usb_line" | awk -F: '{print $1}')  # usb0, usb1, etc.
    HOST_PATH=$(echo "$usb_line" | awk -F'host=' '{print $2}')

    echo "Processing $USB_SLOT ($HOST_PATH)..."

    # Disconnect USB
    qm set $VMID -delete $USB_SLOT
    if [ $? -eq 0 ]; then
        echo "  Disconnected $USB_SLOT"
    else
        echo "  Failed to disconnect $USB_SLOT"
    fi

    # Reconnect USB (hotplug)
    qm set $VMID -$USB_SLOT host=$HOST_PATH
    if [ $? -eq 0 ]; then
        echo "  Reconnected $USB_SLOT → $HOST_PATH"
    else
        echo "  Failed to reconnect $USB_SLOT"
    fi

done <<< "$USB_LINES"

echo "Done."
