#!/bin/bash

CONFIG_FILE="vm_usb_config.json"
VERIFY_ONLY=false

if [ "$1" == "-v" ]; then
    VERIFY_ONLY=true
fi

echo "==============================="
echo " Proxmox USB Assignment"
echo " Mode: $([ "$VERIFY_ONLY" = true ] && echo "Selective (-v)" || echo "Full Reset")"
echo "==============================="

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found."
    exit 1
fi

# 1. Parse JSON into a format that handles spaces: VM|VIDPID|SERIAL|PATH
# We use a newline-separated list of pipe-delimited values
RAW_DATA=$(python3 - <<EOF
import json
with open("$CONFIG_FILE") as f:
    data = json.load(f)
for vm in data.get("vms", []):
    name = vm.get("name")
    for usb in vm.get("usbs", []):
        print(f"{name}|{usb.get('vidpid')}|{usb.get('serial')}|{usb.get('usb_path')}")
EOF
)

# 2. Get list of unique VM names from the JSON
VM_NAMES=$(echo "$RAW_DATA" | cut -d'|' -f1 | sort -u)

declare -A ASSIGNED_PATHS

for vm_name in $VM_NAMES; do
    vmid=$(qm list | awk -v name="$vm_name" '$2 == name {print $1}')

    if [ -z "$vmid" ]; then
        echo -e "\nVM '$vm_name' not found — skipping"
        continue
    fi

    echo -e "\nVM: $vm_name (VMID $vmid)"

    # Phase 1: Cleanup slots not in the config (or all slots if not Verify Mode)
    for usbslot in $(qm config "$vmid" | grep '^usb[0-9]\+:' | cut -d':' -f1); do
        host_conf=$(qm config "$vmid" | grep "^$usbslot:" | awk -F'host=' '{print $2}' | cut -d',' -f1)
        
        keep_device=false
        # Check if this currently attached host_path is in our desired list for THIS VM
        while IFS='|' read -r d_vm d_vidpid d_serial d_path; do
            [[ "$d_vm" != "$vm_name" ]] && continue
            
            # Match Logic
            if [[ "$d_path" != "*" && "$host_conf" == "$d_path" ]]; then
                keep_device=true
            elif [[ "$d_path" == "*" ]]; then
                # If path is *, we must check the actual hardware at host_conf
                sys_val="/sys/bus/usb/devices/$host_conf"
                if [ -d "$sys_val" ]; then
                    cur_vp="$(cat "$sys_val/idVendor"):$(cat "$sys_val/idProduct")"
                    cur_ser="$(cat "$sys_val/serial" 2>/dev/null || echo "*")"
                    [[ "$cur_vp" == "$d_vidpid" && "$cur_ser" == "$d_serial" ]] && keep_device=true
                fi
            fi
        done <<< "$RAW_DATA"

        if [ "$VERIFY_ONLY" = false ] || [ "$keep_device" = false ]; then
            qm set "$vmid" -delete "$usbslot" >/dev/null
            echo "  Removed $usbslot ($host_conf)"
        else
            echo "  Keeping $usbslot ($host_conf)"
            ASSIGNED_PATHS["$host_conf"]=1
        fi
    done

    # Phase 2: Attachment
    usb_index=0
    echo "$RAW_DATA" | grep "^$vm_name|" | while IFS='|' read -r d_vm vidpid serial target_path; do
        found_path=""

        if [[ "$target_path" != "*" ]]; then
            dev_dir="/sys/bus/usb/devices/$target_path"

            if [ -d "$dev_dir" ] &&
            [ -f "$dev_dir/idVendor" ] &&
            [ -f "$dev_dir/idProduct" ]; then

                vp="$(cat "$dev_dir/idVendor"):$(cat "$dev_dir/idProduct")"

                if [[ "$vp" == "$vidpid" ]]; then
                    found_path="$target_path"
                fi
            fi
        else
            # Search by VIDPID and Serial
            for dev_dir in /sys/bus/usb/devices/[0-9]*; do
                [ -f "$dev_dir/idVendor" ] || continue
                vp="$(cat "$dev_dir/idVendor"):$(cat "$dev_dir/idProduct")"
                ser="$(cat "$dev_dir/serial" 2>/dev/null || echo "*")"
                
                if [[ "$vp" == "$vidpid" && "$ser" == "$serial" ]]; then
                    found_path=$(basename "$dev_dir")
                    # Ensure this specific physical device isn't already used
                    [[ "${ASSIGNED_PATHS[$found_path]}" == "1" ]] && continue
                    break
                fi
            done
        fi

        if [ -n "$found_path" ]; then
            # Check if this VM already has this path attached
            if qm config "$vmid" | grep -q "host=$found_path"; then
                ASSIGNED_PATHS["$found_path"]=1
                continue
            fi

            # Find next free usbX slot
            while qm config "$vmid" | grep -q "^usb${usb_index}:"; do
                ((usb_index++))
            done

            qm set "$vmid" "-usb${usb_index}" "host=${found_path}" >/dev/null
            echo "  Attached $vidpid ($found_path) to usb${usb_index}"
            ASSIGNED_PATHS["$found_path"]=1
            ((usb_index++))
        else
            echo "  ❌ NOT FOUND: $vidpid (Serial: $serial / Path: $target_path)"
        fi
    done
done

echo -e "\nDone."
