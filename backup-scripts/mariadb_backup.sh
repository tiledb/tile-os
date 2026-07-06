#!/bin/bash

HOST="192.168.0.200"
PORT="3306"
USER="tiledb"
PASSWORD="T1le-db-word!"

BACKUP_DIR="../resources/mariadb_backups"
SYNC_BACKUP_DIR="/var/www/html/drive/mariadb_backup"

DATE=$(date +"%Y-%m-%d_%H-%M-%S")

mkdir -p "$BACKUP_DIR"

echo "Starting backups..."

# =========================
# 1. MariaDB dump ONLY
# =========================
MARIADB_SQL="$BACKUP_DIR/mariadb_${DATE}.sql"

mysqldump \
  --host="$HOST" \
  --port="$PORT" \
  --user="$USER" \
  --password="$PASSWORD" \
  --single-transaction \
  --routines \
  --events \
  --triggers \
  --all-databases \
> "$MARIADB_SQL"

if [ $? -ne 0 ]; then
  echo "MariaDB dump FAILED"
  exit 1
fi

# =========================
# 2. Activate pyenv + run SQLite generator (ONLY STEP 2)
# =========================
echo "Creating SQLite database via Python..."

source ../resources/.pyenv/bin/activate

python3 mariadb_backup.py \
  --output-dir "$BACKUP_DIR" \
  --timestamp "$DATE"

deactivate


# =========================
# Sync backup directory
# =========================
echo "Synchronizing backups to secondary location..."

mkdir -p "$SYNC_BACKUP_DIR"

rsync -av --delete "$BACKUP_DIR"/ "$SYNC_BACKUP_DIR"/

if [ $? -eq 0 ]; then
    echo "Backup synchronization completed."
else
    echo "WARNING: Backup synchronization failed!"
fi


# =========================
# Done
# =========================
echo "Done!"
echo "MariaDB: $MARIADB_SQL"
echo "SQLite generated in: $BACKUP_DIR"


echo "Starting upload step..."
source ./mariadb_nextcloud_upload.sh
echo "Finished..."