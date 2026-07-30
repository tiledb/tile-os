#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
#  exit 1
fi

FSTAB_FILE="/etc/fstab"
SAMBA_CONFIG="/etc/samba/smb.conf"
BACKUP_CONFIG="/etc/samba/smb.conf.bak.$(date +%F_%H%M%S)"

# Ensure Samba is installed
if ! command -v smbd &> /dev/null; then
    echo "Samba is not installed. Installing it now..."
    apt update && apt install samba -y
fi

# Back up the current Samba configuration
echo "Backing up current Samba configuration to $BACKUP_CONFIG"
cp "$SAMBA_CONFIG" "$BACKUP_CONFIG"

# ----------------------------------------------------
# Step 1: Inject the IP Restrictive Firewall into [global]
# ----------------------------------------------------
echo "Injecting network restrictions into Samba configuration..."

# Clean out any previous hosts allow/deny rules to prevent duplicates
sed -i '/hosts allow =/d' "$SAMBA_CONFIG"
sed -i '/hosts deny =/d' "$SAMBA_CONFIG"

# Insert the IP rules right under the [global] section identifier
sed -i '/\[global\]/a \   hosts allow = 192.168.1. 127.\n   hosts deny = ALL' "$SAMBA_CONFIG"


# ----------------------------------------------------
# Step 2: Parse /etc/fstab and Generate Individual Shares
# ----------------------------------------------------
echo "Parsing fstab mounts and generating individual Samba shares..."

# Read /etc/fstab line by line
while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments (#), empty lines, and system-critical virtual file systems
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[:space:]/}" ]] && continue
    
    # Extract the device/source (1st item) and the mount point path (2nd item)
    dev_source=$(echo "$line" | awk '{print $1}')
    mount_path=$(echo "$line" | awk '{print $2}')
    fs_type=$(echo "$line" | awk '{print $3}')

    # Skip root, boot, swap, proc, and other non-storage system paths
    if [[ "$mount_path" == "/" ]] || [[ "$mount_path" == "/boot"* ]] || [[ "$mount_path" == "none" ]] || [[ "$fs_type" == "swap" ]] || [[ "$fs_type" == "proc" ]] || [[ "$fs_type" == "sysfs" ]] || [[ "$fs_type" == "devpts" ]]; then
        continue
    fi

    # Validate that the path is an existing local directory
    if [ -d "$mount_path" ]; then
        # Create a clean, friendly share name from the folder basename
        share_name=$(basename "$mount_path")
        
        # If the mount path is something generic like /mnt/data, use 'data'
        if [ "$share_name" == "" ] || [ "$share_name" == "/" ]; then
            continue
        fi

        # Check if this exact path or share name is already defined to avoid duplicates
        if grep -q "path = $mount_path" "$SAMBA_CONFIG" || grep -q "\[$share_name\]" "$SAMBA_CONFIG"; then
            echo "Skipping '$mount_path' - Already exists in $SAMBA_CONFIG"
            continue
        fi

        echo "Adding dedicated Samba share: [$share_name] for mount: $mount_path"

        # Append the explicit Samba block for this specific mount boundary
        cat <<EOF >> "$SAMBA_CONFIG"

[$share_name]
   comment = Auto-generated from fstab Mount ($fs_type)
   path = $mount_path
   browseable = yes
   read only = no
   guest ok = no
   create mask = 0775
   directory mask = 0775
   force user = root
EOF
    fi
done < "$FSTAB_FILE"

# Restart Samba to apply network security and mount points
echo "Restarting Samba service..."
systemctl restart smbd

echo "Done! Your fstab mounts are mapped and locked down to 192.168.1.0/24."
