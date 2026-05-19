#!/bin/bash

get_programmer_type() {

    case "$1" in
        0403:6014) echo "Digilent HS3" ;;
        0403:6010) echo "Digilent HS2" ;;
        1514:2008) echo "FlashPro5" ;;
        1514:2006) echo "FlashPro4" ;;
        1366:*) echo "Segger J-Link" ;;
        0483:3748) echo "ST-Link" ;;
        0d28:*) echo "CMSIS-DAP" ;;
        *) echo "Unknown Programmer" ;;
    esac

}

echo "=========================="
echo "Proxmox VM and USB Summary"
echo "=========================="
echo

echo ">>> USB Programmers connected to HOST:"
echo

for dev in /sys/bus/usb/devices/*; do

    [ -f "$dev/idVendor" ] || continue

    vendor=$(cat "$dev/idVendor")
    product=$(cat "$dev/idProduct")
    vidpid="$vendor:$product"

    serial=$(cat "$dev/serial" 2>/dev/null)
    usb_path=$(basename "$dev")

    case "$vendor" in
        0403|1366|0483|0d28|1514|03eb)

            type=$(get_programmer_type "$vidpid")

            if [ -n "$serial" ]; then
                json_serial="$serial"
                json_path="*"
            else
                json_serial="*"
                json_path="$usb_path"
            fi

            echo "Programmer detected:"
            echo "   Type     : $type"
            echo "   VID:PID  : $vidpid"
            echo "   Serial   : $json_serial"
            echo "   USB Path : $json_path"
            echo
        ;;

    esac

done

echo "--------------------------------------"
echo

echo ">>> List of VMs:"
qm list
echo

echo ">>> USB devices attached to VMs:"
for vmid in $(qm list | awk 'NR>1 {print $1}'); do

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

            vidpid="$vendor:$product"
            type=$(get_programmer_type "$vidpid")

            name=$(lsusb | grep -i "$vidpid" | cut -d' ' -f7-)
            [ -z "$name" ] && name="Unknown USB"

            if [ -n "$serial" ]; then
                json_serial="$serial"
                json_path="*"
            else
                json_serial="*"
                json_path="$host_path"
            fi

            echo "  $usb_line"
            echo "     → Type     : $type"
            echo "     → Name     : $name"
            echo "     → VID:PID  : $vidpid"
            echo "     → Serial   : $json_serial"
            echo "     → USB Path : $json_path"

            if [[ "$type" != "Unknown Programmer" ]]; then
                echo "     >>> PROGRAMMER DEVICE DETECTED <<<"
            fi
        else
            echo "  $usb_line → Unknown USB"
        fi

        echo
    done

    echo
done