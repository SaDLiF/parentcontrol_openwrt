#!/bin/sh

echo "=== Parental Control Installer ==="

# Check required commands
echo "[1/8] Checking system..."
which opkg >/dev/null || { echo "ERROR: opkg not found"; exit 1; }
which wget >/dev/null || { echo "ERROR: wget not found"; exit 1; }

# Get latest release info
echo "[2/8] Finding latest IPK packages..."
API_RESPONSE=$(wget -qO - https://api.github.com/repos/SaDLiF/parentcontrol_openwrt/releases/latest)

# Simple but reliable JSON parsing for OpenWrt
MAIN_PACKAGE_URL=$(echo "$API_RESPONSE" | sed -e 's/"/ /g' | tr ' ' '\n' | grep "https.*luci-app-parentcontrol.*\.ipk" | head -1)
TRANSLATION_PACKAGE_URL=$(echo "$API_RESPONSE" | sed -e 's/"/ /g' | tr ' ' '\n' | grep "https.*luci-i18n-parentcontrol-ru.*\.ipk" | head -1)

if [ -z "$MAIN_PACKAGE_URL" ]; then
    echo "ERROR: Could not find main package URL"
    echo "API Response sample:"
    echo "$API_RESPONSE" | head -5
    echo "Please check: https://github.com/SaDLiF/parentcontrol_openwrt/releases"
    exit 1
fi

echo "Main package: $MAIN_PACKAGE_URL"
[ -n "$TRANSLATION_PACKAGE_URL" ] && echo "Translation package: $TRANSLATION_PACKAGE_URL"

# Download packages
echo "[3/8] Downloading IPK packages..."
cd /tmp

echo "Downloading main package..."
wget -O luci-app-parentcontrol.ipk "$MAIN_PACKAGE_URL" || {
    echo "ERROR: Main package download failed"
    exit 1
}

# Check if file is HTML (simple check)
if head -1 luci-app-parentcontrol.ipk | grep -q "<!DOCTYPE HTML\|<html"; then
    echo "ERROR: Downloaded HTML instead of IPK file"
    rm -f luci-app-parentcontrol.ipk
    exit 1
fi

if [ -n "$TRANSLATION_PACKAGE_URL" ]; then
    echo "Downloading translation package..."
    wget -O luci-i18n-parentcontrol-ru.ipk "$TRANSLATION_PACKAGE_URL" || {
        echo "WARNING: Translation package download failed, continuing with main package only"
        rm -f luci-i18n-parentcontrol-ru.ipk 2>/dev/null
    }

    # Check translation package if it exists
    if [ -f "luci-i18n-parentcontrol-ru.ipk" ]; then
        if head -1 luci-i18n-parentcontrol-ru.ipk | grep -q "<!DOCTYPE HTML\|<html"; then
            echo "WARNING: Translation package is HTML, skipping"
            rm -f luci-i18n-parentcontrol-ru.ipk
        fi
    fi
fi

# Install packages
echo "[4/8] Installing packages..."
opkg install luci-app-parentcontrol.ipk || {
    echo "ERROR: Main package installation failed"
    rm -f *.ipk
    exit 1
}

if [ -f "luci-i18n-parentcontrol-ru.ipk" ]; then
    opkg install luci-i18n-parentcontrol-ru.ipk || {
        echo "WARNING: Translation package installation failed, continuing..."
    }
fi

# Cleanup downloaded packages
rm -f *.ipk

# Set file permissions
echo "[5/8] Setting file permissions..."
[ -f "/usr/sbin/parentalcontrol" ] && chmod 755 /usr/sbin/parentalcontrol && echo "✓ /usr/sbin/parentalcontrol"
[ -f "/usr/bin/parentalcontrol-apply" ] && chmod 755 /usr/bin/parentalcontrol-apply && echo "✓ /usr/bin/parentalcontrol-apply"
[ -f "/etc/init.d/parentalcontrol-watch" ] && chmod 755 /etc/init.d/parentalcontrol-watch && echo "✓ /etc/init.d/parentalcontrol-watch"
[ -f "/etc/config/parentalcontrol" ] && chmod 644 /etc/config/parentalcontrol && echo "✓ /etc/config/parentalcontrol"

# Add cron job
echo "[6/8] Setting up cron job..."
if [ -f "/usr/bin/parentalcontrol-apply" ]; then
    (crontab -l 2>/dev/null | grep -v "/usr/bin/parentalcontrol-apply"; echo "* * * * * /usr/bin/parentalcontrol-apply") | crontab -
    echo "✓ Cron job added: * * * * * /usr/bin/parentalcontrol-apply"
else
    echo "⚠ WARNING: /usr/bin/parentalcontrol-apply not found, skipping cron job"
fi

# Start service
echo "[7/8] Starting service..."
if [ -f "/etc/init.d/parentalcontrol-watch" ]; then
    /etc/init.d/parentalcontrol-watch enable
    /etc/init.d/parentalcontrol-watch start
    echo "✓ Service started successfully!"
else
    echo "⚠ WARNING: Service file not found"
fi

# Restart LuCI
echo "[8/8] Restarting LuCI..."
/etc/init.d/uhttpd restart 2>/dev/null && echo "✓ uhttpd restarted" || echo "⚠ uhttpd restart failed"
/etc/init.d/rpcd restart 2>/dev/null && echo "✓ rpcd restarted" || echo "⚠ rpcd restart failed"

echo ""
echo "🎉 Installation completed!"
echo "Parental Control is now installed and running."
echo "Cron job will apply rules every minute."
echo "Access via LuCI: Network → Parental Control"
echo ""
echo "To uninstall, use: opkg remove luci-app-parentcontrol luci-i18n-parentcontrol-ru"