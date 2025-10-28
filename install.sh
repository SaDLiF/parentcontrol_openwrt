#!/bin/sh

set -e

echo "=== Parental Control Installer ==="

# Check required commands
echo "[1/6] Checking system..."
which opkg >/dev/null || { echo "ERROR: opkg not found"; exit 1; }
which wget >/dev/null || { echo "ERROR: wget not found"; exit 1; }

# Get architecture
echo "[2/6] Detecting architecture..."
ARCH=$(opkg print-architecture | awk '{print $2}' | head -1)
echo "Architecture: $ARCH"

# Hardcoded download URL for testing (замените на актуальную ссылку с вашего релиза)
echo "[3/6] Getting download URL..."
DOWNLOAD_URL="https://github.com/SaDLiF/parentcontrol_openwrt/releases/download/v1.0.0/parentcontrol_1.0.0-1_aarch64_cortex-a53.ipk"

# If no specific URL, try to find latest
if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "none" ]; then
    echo "Trying to find latest release..."
    # Простая попытка получить последний релиз
    LATEST_URL=$(wget -qO - https://api.github.com/repos/SaDLiF/parentcontrol_openwrt/releases/latest | grep "browser_download_url.*ipk" | head -1 | cut -d'"' -f4)
    if [ -n "$LATEST_URL" ]; then
        DOWNLOAD_URL="$LATEST_URL"
    else
        echo "ERROR: Could not find download URL"
        echo "Please download IPK manually from:"
        echo "https://github.com/SaDLiF/parentcontrol_openwrt/releases"
        exit 1
    fi
fi

echo "Download URL: $DOWNLOAD_URL"

# Download
echo "[4/6] Downloading IPK..."
cd /tmp
wget -O parentcontrol.ipk "$DOWNLOAD_URL" || {
    echo "ERROR: Download failed"
    exit 1
}

# Install
echo "[5/6] Installing..."
opkg install parentcontrol.ipk || {
    echo "ERROR: Installation failed"
    rm -f parentcontrol.ipk
    exit 1
}

# Cleanup
rm -f parentcontrol.ipk

# Start service
echo "[6/6] Starting service..."
if [ -f "/etc/init.d/parentalcontrol-watch" ]; then
    /etc/init.d/parentalcontrol-watch enable
    /etc/init.d/parentalcontrol-watch start
    echo "Service started successfully!"
else
    echo "WARNING: Service file not found"
fi

echo "=== Installation completed! ==="
echo "Parental Control is now installed and running."
echo "Access via LuCI web interface."