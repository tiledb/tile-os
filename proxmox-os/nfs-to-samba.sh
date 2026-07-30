#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
#  exit 1
fi

EXPORTS_FILE="/etc/exports"
SAMBA_CONFIG="/etc/samba/smb.conf"
BACKUP_CONFIG="/etc/samba/smb.conf.bak.$(date +%F_%H%M%S)"

# Check if NFS exports file exists and has content
if [ ! -f "$EXPORTS_FILE" ] || [ ! -s "$EXPORTS_FILE" ]; then
    echo "Error: $EXPORTS_FILE is empty or does not exist."
#    exit 1
fi

# Ensure Samba is installed
if ! command -v smbd &> /dev/null; then
    echo "Samba is not installed. Installing it now..."
    apt update && apt install samba -y
fi

# Back up the current Samba configuration
echo "Backing up current Samba configuration to $BACKUP_CONFIG"
cp "$SAMBA_CONFIG" "$BACKUP_CONFIG"

echo "Parsing NFS exports and generating Samba shares..."

# Read /etc/exports line by line
while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments (#) and completely empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[:space:]/}" ]] && continue

    # Extract the local folder path (the first item on the line)
    share_path=$(echo "$line" | awk '{print $1}')

    # Validate that it is a real directory
    if [ -d "$share_path" ]; then
        # Create a clean share name from the last directory folder
        share_name=$(basename "$share_path")
        
        # Check if this share name or path already exists in smb.conf to avoid duplicates
        if grep -q "path = $share_path" "$SAMBA_CONFIG" || grep -q "\[$share_name\]" "$SAMBA_CONFIG"; then
            echo "Skipping '$share_path' - Already exists in $SAMBA_CONFIG"
            continue
        fi

        echo "Adding Samba share: [$share_name] for path: $share_path"

        # Append Samba block to smb.conf
        cat <<EOF >> "$SAMBA_CONFIG"

[$share_name]
   comment = Auto-generated from NFS Export
   path = $share_path
   browseable = yes
   read only = no
   guest ok = no
   create mask = 0775
   directory mask = 0775
   force user = root
   vfs objects = crossrename

EOF
    fi
done < "$EXPORTS_FILE"

# Restart Samba to apply changes
echo "Restarting Samba service..."
systemctl restart smbd

echo "Done! Your NFS shares have been synchronized to Samba."
