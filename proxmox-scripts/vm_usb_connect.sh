#!/bin/bash

CONFIG_FILE="vm_usb_config.json"
VERIFY_ONLY=false

# Parse argument
if [ "$1" == "-v" ]; then
    VERIFY_ONLY=true
fi

echo "==============================="
echo " Proxmox USB Assignment"
echo " Mode: $([ "$VERIFY_ONLY" = true ] && echo "Selective (-v)" || echo "Full Reset")"
echo "==============================="
echo

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file $CONFIG_FILE not found."
    return 0 2>/dev/null || true
fi

# Parse JSON once into temp structure
mapfile -t JSON_LINES < <(python3 - <<EOF
import json

with open("$CONFIG_FILE") as f:
    data = json.load(f)

for vm in data.get("vms", []):
    name = vm.get("name")
    for usb in vm.get("usbs", []):
        print(name, usb.get("vidpid"), usb.get("serial"))
EOF
)

# Process per VM
declare -A VM_USB_LIST

for line in "${JSON_LINES[@]}"; do
    vm_name=$(echo "$line" | awk '{print $1}')
    vidpid=$(echo "$line" | awk '{print $2}')
    serial=$(echo "$line" | awk '{print $3}')
    VM_USB_LIST["$vm_name"]+="$vidpid|$serial "
done

for vm_name in "${!VM_USB_LIST[@]}"; do

    vmid=$(qm list | awk -v name="$vm_name" '$2 == name {print $1}')

    if [ -z "$vmid" ]; then
        echo "VM '$vm_name' not found — skipping"
        echo
        continue
    fi

    echo "VM: $vm_name (VMID $vmid)"

    # Build list of desired devices
    desired_list="${VM_USB_LIST[$vm_name]}"

    # Remove USB devices
    for usbslot in $(qm config "$vmid" | grep '^usb' | cut -d':' -f1); do

        host_path=$(qm config "$vmid" | grep "^$usbslot:" | awk -F'host=' '{print $2}')
        sys_path="/sys/bus/usb/devices/$host_path"

        keep_device=false

        if [ -d "$sys_path" ]; then
            vendor=$(cat "$sys_path/idVendor" 2>/dev/null)
            product=$(cat "$sys_path/idProduct" 2>/dev/null)
            serial=$(cat "$sys_path/serial" 2>/dev/null)

            for entry in $desired_list; do
                desired_vidpid="${entry%%|*}"
                desired_serial="${entry##*|}"

                if [[ "$vendor:$product" == "$desired_vidpid" ]] && \
                   [[ "$serial" == "$desired_serial" ]]; then
                    keep_device=true
                fi
            done
        fi

        if [ "$VERIFY_ONLY" = false ]; then
            qm set "$vmid" -delete "$usbslot"
            echo "  Removed $usbslot"
        else
            if [ "$keep_device" = false ]; then
                qm set "$vmid" -delete "$usbslot"
                echo "  Removed non-listed $usbslot"
            else
                echo "  Keeping $usbslot (listed in JSON)"
            fi
        fi
    done

    # Attach missing devices
    usb_index=0

    for entry in $desired_list; do
        vidpid="${entry%%|*}"
        serial="${entry##*|}"

        vendor="${vidpid%%:*}"
        product="${vidpid##*:}"

        already_attached=false

        for usbslot in $(qm config "$vmid" | grep '^usb' | cut -d':' -f1); do
            host_path=$(qm config "$vmid" | grep "^$usbslot:" | awk -F'host=' '{print $2}')
            sys_path="/sys/bus/usb/devices/$host_path"

            if [ -d "$sys_path" ]; then
                dev_vendor=$(cat "$sys_path/idVendor" 2>/dev/null)
                dev_product=$(cat "$sys_path/idProduct" 2>/dev/null)
                dev_serial=$(cat "$sys_path/serial" 2>/dev/null)

                if [[ "$dev_vendor:$dev_product" == "$vendor:$product" ]] && \
                   [[ "$dev_serial" == "$serial" ]]; then
                    already_attached=true
                fi
            fi
        done

        if [ "$already_attached" = true ]; then
            continue
        fi

        # Find device on host
        found_path=""
        for dev in /sys/bus/usb/devices/*; do
            if [ -f "$dev/idVendor" ]; then
                dev_vendor=$(cat "$dev/idVendor")
                dev_product=$(cat "$dev/idProduct")
                dev_serial=$(cat "$dev/serial" 2>/dev/null)

                if [[ "$dev_vendor:$dev_product" == "$vendor:$product" ]] && \
                   [[ "$dev_serial" == "$serial" ]]; then
                    found_path=$(basename "$dev")
                    break
                fi
            fi
        done

        if [ -z "$found_path" ]; then
            echo "  ❌ $vidpid ($serial) not found on host"
            continue
        fi

        while qm config "$vmid" | grep -q "^usb${usb_index}:"; do
            ((usb_index++))
        done

        qm set "$vmid" -usb${usb_index} host=${found_path}
        echo "  Attached $vidpid ($serial) as usb${usb_index}"
        ((usb_index++))

    done

    echo
done

echo "Done."
