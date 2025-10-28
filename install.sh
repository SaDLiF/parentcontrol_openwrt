#!/bin/sh

echo "=== Parental Control Installer ==="

# Check required commands
echo "[1/6] Checking system..."
which opkg >/dev/null || { echo "ERROR: opkg not found"; exit 1; }
which wget >/dev/null || { echo "ERROR: wget not found"; exit 1; }

# Get actual IPK filename from GitHub
echo "[2/6] Finding latest IPK..."
API_RESPONSE=$(wget -qO - https://api.github.com/repos/SaDLiF/parentcontrol_openwrt/releases/latest)
DOWNLOAD_URL=$(echo "$API_RESPONSE" | grep "browser_download_url.*ipk" | head -1 | cut -d'"' -f4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: No IPK found in latest release"
    echo "Available releases: https://github.com/SaDLiF/parentcontrol_openwrt/releases"
    exit 1
fi

echo "Download URL: $DOWNLOAD_URL"

# Download
echo "[3/6] Downloading IPK..."
cd /tmp
wget -O parentcontrol.ipk "$DOWNLOAD_URL" || {
    echo "ERROR: Download failed"
    exit 1
}

# Install
echo "[4/6] Installing..."
opkg install parentcontrol.ipk || {
    echo "ERROR: Installation failed"
    rm -f parentcontrol.ipk
    exit 1
}

# Cleanup
rm -f parentcontrol.ipk

# Start service
echo "[5/6] Starting service..."
if [ -f "/etc/init.d/parentalcontrol-watch" ]; then
    /etc/init.d/parentalcontrol-watch enable
    /etc/init.d/parentalcontrol-watch start
    echo "Service started successfully!"
else
    echo "WARNING: Service file not found"
fi

echo "[6/6] Installation completed!"
echo "Parental Control is now installed and running."
echo "Access via LuCI web interface."