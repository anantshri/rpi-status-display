#!/bin/bash
# Install rpi-status on a Raspberry Pi
set -euo pipefail

INSTALL_DIR="/opt/rpi-status"
WEBROOT="/var/www/local"

echo "Installing rpi-status..."

sudo mkdir -p "$INSTALL_DIR" "$WEBROOT/data"
sudo cp collect.sh rotate.sh "$INSTALL_DIR/"
sudo cp -r webroot/* "$WEBROOT/"
sudo chmod +x "$INSTALL_DIR/collect.sh" "$INSTALL_DIR/rotate.sh"

# Set up cron
CRON_COLLECT="*/5 * * * * RPI_STATUS_DATA_DIR=$WEBROOT/data $INSTALL_DIR/collect.sh # rpi-status-collect"
CRON_ROTATE="0 0 * * * RPI_STATUS_DATA_DIR=$WEBROOT/data $INSTALL_DIR/rotate.sh # rpi-status-rotate"

{ crontab -l 2>/dev/null | grep -v '# rpi-status-' || true; echo "$CRON_COLLECT"; echo "$CRON_ROTATE"; } | crontab -

# Nginx config
if [ -d /etc/nginx/sites-enabled ]; then
    sudo cp nginx.conf /etc/nginx/sites-available/rpi-status
    sudo ln -sf /etc/nginx/sites-available/rpi-status /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
    echo "Nginx configured."
fi

echo "Done. Dashboard at http://$(hostname -I | awk '{print $1}')"
