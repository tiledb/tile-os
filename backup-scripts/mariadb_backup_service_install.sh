#!/bin/bash

set -e

SERVICE_NAME="mariadb_backup"
SYSTEMD_DIR="/etc/systemd/system"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="${SCRIPT_DIR}/mariadb_backup.sh"

usage() {
    cat <<EOF
Usage:
    $0 install
    $0 uninstall
    $0 reinstall
    $0 status

Commands:
    install     Install and enable the systemd service and timer.
    uninstall   Stop, disable and remove the service and timer.
    reinstall   Uninstall then install again.
    status      Show timer and service status.
EOF
}

install_service() {

    echo "Installing service..."

    cat > "${SYSTEMD_DIR}/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Daily MariaDB Backup and Nextcloud Upload
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
WorkingDirectory=${SCRIPT_DIR}
ExecStart=/bin/bash ${BACKUP_SCRIPT}
EOF

    cat > "${SYSTEMD_DIR}/${SERVICE_NAME}.timer" <<EOF
[Unit]
Description=Run MariaDB backup every day at 04:00

[Timer]
OnCalendar=*-*-* 04:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now "${SERVICE_NAME}.timer"
    echo "Running first backup..."
    systemctl start mariadb_backup.service

    echo
    echo "Installation complete."
    systemctl list-timers "${SERVICE_NAME}.timer"
}

uninstall_service() {

    echo "Removing service..."

    systemctl stop "${SERVICE_NAME}.timer" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}.timer" 2>/dev/null || true

    rm -f "${SYSTEMD_DIR}/${SERVICE_NAME}.service"
    rm -f "${SYSTEMD_DIR}/${SERVICE_NAME}.timer"

    systemctl daemon-reload
    systemctl reset-failed

    echo "Service removed."
}

status_service() {

    echo
    systemctl status "${SERVICE_NAME}.service" --no-pager || true

    echo
    systemctl status "${SERVICE_NAME}.timer" --no-pager || true

    echo
    systemctl list-timers "${SERVICE_NAME}.timer"
}

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root."
    #exit 1
fi


case "$1" in
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    reinstall)
        uninstall_service
        install_service
        ;;
    status)
        status_service
        ;;
    *)
        usage
        #exit 1
        ;;
esac
