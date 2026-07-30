#!/bin/bash

# Check for root privileges without exiting
if [[ $EUID -ne 0 ]]; then
   echo "❌ Error: This script must be run as root (sudo)."
   echo "Please re-run using: sudo $0"
else
    # Parse command-line arguments
    UNMOUNT=false
    REMOUNT=false
    INVALID_ARG=false

    while getopts "ur" opt; do
        case "$opt" in
            u) UNMOUNT=true ;;
            r) REMOUNT=true ;;
            *) INVALID_ARG=true ;;
        esac
    done

    # Handle invalid arguments by showing usage instead of exiting
    if [ "$INVALID_ARG" = true ]; then
        echo "Usage: $0 [-u] [-r]"
        echo "  -u  Automatically force-unmount any hanging mounts found"
        echo "  -r  Remount all filesystems listed in /etc/fstab after unmounting"
    else
        echo "🔍 Scanning system for hanging mount points (2-second timeout per mount)..."
        echo "----------------------------------------------------------------------"

        # Get a unique list of all currently mounted paths
        mounts=$(mount | awk '{print $3}' | sort -u)
        hanging_mounts=()

        # Iterate and test each mount point
        for m in $mounts; do
            # Skip virtual kernel filesystems to save time
            [[ "$m" =~ ^/(sys|proc|dev|run) ]] && continue

            # Test if the directory responds within 2 seconds
            if ! timeout 2 ls -d "$m" &>/dev/null; then
                echo "⚠️  Hanging mount detected: $m"
                hanging_mounts+=("$m")
            fi
        done

        echo "----------------------------------------------------------------------"

        # Act based on whether hanging mounts were discovered
        if [ ${#hanging_mounts[@]} -eq 0 ]; then
            echo "✅ No hanging mount points detected. System is healthy."
        else
            # Handle the unmount (-u) flag
            if [ "$UNMOUNT" = true ]; then
                for m in "${hanging_mounts[@]}"; do
                    echo "🔄 Attempting to lazy/force unmount: $m"
                    
                    # Try standard force unmount, fallback to lazy unmount, then FUSE unmount
                    if umount -f "$m" 2>/dev/null || umount -l "$m" 2>/dev/null || fusermount -uz "$m" 2>/dev/null; then
                        echo "✅ Successfully unmounted: $m"
                    else
                        echo "❌ Failed to unmount: $m (Device might be deeply locked)"
                    fi
                done
            else
                echo "💡 Info: Hanging mounts were found but not unmounted. Run with '-u' to unmount them."
            fi
        fi

        # Handle the remount (-r) flag (placed outside the block so it runs if requested)
        if [ "$REMOUNT" = true ]; then
            if [ "$UNMOUNT" = false ] && [ ${#hanging_mounts[@]} -gt 0 ]; then
                echo "⚠️  Warning: Remount (-r) was requested without unmounting (-u) first."
            fi
            echo "🔄 Attempting to remount all filesystems from /etc/fstab..."
            mount -a
            echo "✅ Remount command issued."
        fi
    fi
fi

# The script naturally ends here and hands control back to your terminal prompt
echo "🏁 Script execution finished."
