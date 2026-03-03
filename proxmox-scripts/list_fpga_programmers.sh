#!/bin/bash

echo "=========================="
echo "Proxmox VM and USB Summary"
echo "=========================="
echo

# List all VMs
echo ">>> List of VMs:"
qm list
echo

echo ">>> USB devices attached to VMs:"
for vmid in $(qm list | awk 'NR>1 {print $1}'); do

    # Extract VM name
    vmname=$(qm config $vmid | awk -F': ' '/^name:/ {print $2}')

    echo "VMID $vmid ($vmname):"

    if ! qm config $vmid | grep -q '^usb'; then
        echo "  No USB devices attached"
        echo
        continue
    fi

    qm config $vmid | grep '^usb' | while read -r usb_line; do

        host_path=$(echo "$usb_line" | awk -F'host=' '{print $2}')
        sys_path="/sys/bus/usb/devices/$host_path"

        if [ -d "$sys_path" ]; then
            vendor=$(cat $sys_path/idVendor 2>/dev/null)
            product=$(cat $sys_path/idProduct 2>/dev/null)
            serial=$(cat $sys_path/serial 2>/dev/null)

            name=$(lsusb | grep -i "$vendor:$product" | cut -d' ' -f7-)
            [ -z "$name" ] && name="Unknown USB"

            echo "  $usb_line"
            echo "     → $name"
            echo "     → VID:PID = $vendor:$product"
            echo "     → Serial  = ${serial:-"(none)"}"

            if [[ "$name" == *"Digilent"* ]] || [[ "$name" == *"FlashPro"* ]]; then
                echo "     >>> PROGRAMMER DEVICE DETECTED <<<"
            fi
        else
            echo "  $usb_line → Unknown USB"
        fi

        echo
    done

    echo
done
