#!/bin/bash

echo "=========================="
echo "Proxmox VM and USB Summary"
echo "=========================="
echo

# List all VMs
echo ">>> List of VMs:"
qm list
echo

# Show USB devices attached to each VM with names
echo ">>> USB devices attached to VMs:"
for vmid in $(qm list | awk 'NR>1 {print $1}'); do
    echo "VMID $vmid:"
    qm config $vmid | grep usb | while read -r usb_line; do
        # extract host path like 1-1.3.1.2
        host_path=$(echo "$usb_line" | awk -F'host=' '{print $2}')
        
        # convert topology path to sysfs path
        sys_path="/sys/bus/usb/devices/$host_path"

        if [ -d "$sys_path" ]; then
            vendor=$(cat $sys_path/idVendor 2>/dev/null)
            product=$(cat $sys_path/idProduct 2>/dev/null)
            name=$(lsusb | grep -i "$vendor:$product" | cut -d' ' -f7-)
            [ -z "$name" ] && name="Unknown USB"
        else
            name="Unknown USB"
        fi

        echo "  $usb_line → $name"
    done || echo "  No USB devices attached"
    echo
done

# List all USB devices on host
echo ">>> USB devices on host:"
lsusb
