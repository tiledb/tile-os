#!/bin/bash

# =========================
# CONFIG
# =========================
BACKUP_DIR="../resources/mariadb_backups"
NEXTCLOUD_URL="https://nextcloud.fysik.su.se"
USERNAME="edval@su.se"
APP_PASSWORD="4PNiS-S3w2o-ntDdx-P6gZb-E342c"
REMOTE_DIR="ATLAS-Lab/TileDB-Backup"
# =========================


echo "========================================"
echo "Nextcloud upload started: $(date)"
echo "Backup directory : $BACKUP_DIR"
echo "Remote directory : $REMOTE_DIR"
echo "========================================"

# =========================
# Check files exist
# =========================
shopt -s nullglob
FILES=("$BACKUP_DIR"/*.sql "$BACKUP_DIR"/*.sqlite "$BACKUP_DIR"/*.xlsx)

if [ ${#FILES[@]} -eq 0 ]; then
    echo "No backup files found. Exiting."
    # exit 0
fi

# =========================
# Upload loop
# =========================
for FILE in "${FILES[@]}"; do

    echo "----------------------------------------"

    echo "Found: $FILE"

    BASENAME=$(basename "$FILE")
    REMOTE_NAME="$BASENAME"

    # Clean filename (safety)
    REMOTE_NAME="$(echo "$REMOTE_NAME" | tr -d '\r\n')"

    URL="${NEXTCLOUD_URL}/remote.php/dav/files/${USERNAME}/${REMOTE_DIR}/${REMOTE_NAME}"

    echo "Uploading as: $REMOTE_NAME"
    echo "Destination URL: $URL"

    HTTP_CODE=$(
        curl \
            --silent \
            --show-error \
            --output /dev/null \
            --write-out "%{http_code}" \
            --user "$USERNAME:$APP_PASSWORD" \
            --header "If-None-Match: *" \
            --upload-file "$FILE" \
            "$URL"
    )

    echo "HTTP response: $HTTP_CODE"

    case "$HTTP_CODE" in
        201|204)
            echo "SUCCESS: Uploaded $REMOTE_NAME"
            ;;
        412)
            echo "SKIPPED: Already exists"
            ;;
        401|403)
            echo "AUTH ERROR"
            ;;
        404)
            echo "ERROR: Wrong remote path"
            ;;
        *)
            echo "ERROR: Unexpected response ($HTTP_CODE)"
            ;;
    esac

done

echo "========================================"
echo "Upload finished: $(date)"
echo "========================================"