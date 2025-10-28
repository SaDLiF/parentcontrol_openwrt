#!/bin/sh

echo "=== Parental Control Installer ==="

# --- 0. Basic checks ---
echo "[1/12] Checking system..."

# opkg required
which opkg >/dev/null 2>&1 || { echo "ERROR: opkg not found"; exit 1; }

# prefer curl, else wget
USE_CURL=0
USE_WGET=0

if command -v curl >/dev/null 2>&1; then
    USE_CURL=1
elif command -v wget >/dev/null 2>&1; then
    USE_WGET=1
else
    echo "ERROR: Neither curl nor wget found. Install curl or wget via opkg."
    exit 1
fi

# helper fetch function: fetch_url <url>
fetch_url() {
    url="$1"
    if [ "$USE_CURL" -eq 1 ]; then
        # use provided GITHUB_TOKEN if set
        if [ -n "$GITHUB_TOKEN" ]; then
            curl -sSL -H "Accept: application/vnd.github.v3+json" -H "User-Agent: OpenWrt-installer" -H "Authorization: token $GITHUB_TOKEN" "$url"
        else
            curl -sSL -H "Accept: application/vnd.github.v3+json" -H "User-Agent: OpenWrt-installer" "$url"
        fi
        return
    fi

    # wget branch
    # BusyBox wget often does NOT support --header; try with --header and fall back to plain wget
    if wget --version >/dev/null 2>&1; then
        if wget --help 2>&1 | grep -q -- "--header"; then
            if [ -n "$GITHUB_TOKEN" ]; then
                wget -qO - --header="Accept: application/vnd.github.v3+json" --header="User-Agent: OpenWrt-installer" --header="Authorization: token $GITHUB_TOKEN" "$url"
            else
                wget -qO - --header="Accept: application/vnd.github.v3+json" --header="User-Agent: OpenWrt-installer" "$url"
            fi
            return
        else
            # fallback to simple wget (may be rate-limited / return HTML)
            wget -qO - "$url"
            return
        fi
    fi

    echo "ERROR: fetch tool failed"
    return 1
}

# --- 1. Get latest release assets from GitHub API ---
echo "[2/12] Finding latest IPK packages..."

API_URL="https://api.github.com/repos/SaDLiF/parentcontrol_openwrt/releases/latest"

API_RESPONSE=$(fetch_url "$API_URL") || API_RESPONSE=""

# Quick sanity check for HTML
if echo "$API_RESPONSE" | head -n1 | grep -qi "<!DOCTYPE\|<html"; then
    echo "ERROR: GitHub API returned HTML — probably rate-limited or blocked."
    echo "If you have a GitHub token, run: export GITHUB_TOKEN=ghp_xxx"
    echo "Response head:"
    echo "$API_RESPONSE" | sed -n '1,20p'
    exit 1
fi

if [ -z "$API_RESPONSE" ]; then
    echo "ERROR: Empty response from GitHub API."
    exit 1
fi

# Parse assets: name -> browser_download_url, using awk (works for compact JSON)
MAIN_PACKAGE_URL=""
TRANSLlation_PACKAGE_URL=""
TRANSLATION_PACKAGE_URL=""

echo "$API_RESPONSE" |
awk '
/"assets"[[:space:]]*:[[:space:]]*\[/ { in_assets=1; next }
/\]/ && in_assets { in_assets=0; next }
in_assets {
    gsub(/^[ \t,]+/, "")
    if (match($0, /"name"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)) { name = m[1] }
    if (match($0, /"browser_download_url"[[:space:]]*:[[:space:]]*"([^"]+)"/, m)) { url = m[1] }
    if (name != "" && url != "") {
        printf("%s\t%s\n", name, url)
        name=""; url=""
    }
}
' | while IFS=$'\t' read -r name url; do
    case "$name" in
        *luci-app-parentcontrol*.ipk)
            MAIN_PACKAGE_URL="$url"
            ;;
        *luci-i18n-parentcontrol-ru*.ipk)
            TRANSLATION_PACKAGE_URL="$url"
            ;;
        *luci-app-parentcontrol*)
            [ -z "$MAIN_PACKAGE_URL" ] && MAIN_PACKAGE_URL="$url"
            ;;
        *luci-i18n-parentcontrol-ru*|*parentcontrol-ru*)
            [ -z "$TRANSLATION_PACKAGE_URL" ] && TRANSLATION_PACKAGE_URL="$url"
            ;;
    esac
done

# if awk/cmd substitution in while lost variables due to subshell, get them via temp file (robust fallback)
if [ -z "$MAIN_PACKAGE_URL" ]; then
    # fallback: try simple greps (less reliable)
    MAIN_PACKAGE_URL=$(echo "$API_RESPONSE" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*luci-app-parentcontrol[^"]*"' | head -n1 | cut -d'"' -f4)
    TRANSLATION_PACKAGE_URL=$(echo "$API_RESPONSE" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*parentcontrol-ru[^"]*"' | head -n1 | cut -d'"' -f4)
fi

if [ -z "$MAIN_PACKAGE_URL" ]; then
    echo "ERROR: Could not find main package URL in release assets."
    echo "Available releases: https://github.com/SaDLiF/parentcontrol_openwrt/releases"
    echo "Response snippet:"
    echo "$API_RESPONSE" | sed -n '1,160p'
    exit 1
fi

echo "Main package: $MAIN_PACKAGE_URL"
[ -n "$TRANSLATION_PACKAGE_URL" ] && echo "Translation package: $TRANSLATION_PACKAGE_URL"

# --- 2. Download packages ---
echo "[3/12] Downloading IPK packages..."
cd /tmp || { echo "ERROR: Cannot cd /tmp"; exit 1; }

download_file() {
    url="$1"
    out="$2"

    if [ "$USE_CURL" -eq 1 ]; then
        if [ -n "$GITHUB_TOKEN" ]; then
            curl -sSL -H "Accept: application/octet-stream" -H "User-Agent: OpenWrt-installer" -H "Authorization: token $GITHUB_TOKEN" -o "$out" "$url" || return 1
        else
            curl -sSL -H "Accept: application/octet-stream" -H "User-Agent: OpenWrt-installer" -o "$out" "$url" || return 1
        fi
        return 0
    fi

    # wget branch
    if wget --help 2>&1 | grep -q -- "--header"; then
        if [ -n "$GITHUB_TOKEN" ]; then
            wget -qO "$out" --header="Accept: application/octet-stream" --header="User-Agent: OpenWrt-installer" --header="Authorization: token $GITHUB_TOKEN" "$url" || return 1
        else
            wget -qO "$out" --header="Accept: application/octet-stream" --header="User-Agent: OpenWrt-installer" "$url" || return 1
        fi
    else
        # plain wget
        wget -qO "$out" "$url" || return 1
    fi
    return 0
}

echo "Downloading main package..."
download_file "$MAIN_PACKAGE_URL" "luci-app-parentcontrol.ipk" || {
    echo "ERROR: Main package download failed"
    exit 1
}

# Quick file-type check: avoid HTML pages saved as .ipk
if head -n1 luci-app-parentcontrol.ipk | grep -q "<!DOCTYPE\|<html"; then
    echo "ERROR: Downloaded HTML instead of IPK file (main package)"
    rm -f luci-app-parentcontrol.ipk
    exit 1
fi

if [ -n "$TRANSLATION_PACKAGE_URL" ]; then
    echo "Downloading translation package..."
    download_file "$TRANSLATION_PACKAGE_URL" "luci-i18n-parentcontrol-ru.ipk" || {
        echo "WARNING: Translation package download failed, continuing with main package only"
        rm -f luci-i18n-parentcontrol-ru.ipk 2>/dev/null
    }

    if [ -f "luci-i18n-parentcontrol-ru.ipk" ]; then
        if head -n1 luci-i18n-parentcontrol-ru.ipk | grep -q "<!DOCTYPE\|<html"; then
            echo "WARNING: Translation package is HTML, skipping"
            rm -f luci-i18n-parentcontrol-ru.ipk
        fi
    fi
fi

# --- 3. Install packages ---
echo "[4/12] Installing packages..."
opkg install /tmp/luci-app-parentcontrol.ipk || {
    echo "ERROR: Main package installation failed"
    rm -f /tmp/*.ipk
    exit 1
}

if [ -f "/tmp/luci-i18n-parentcontrol-ru.ipk" ]; then
    opkg install /tmp/luci-i18n-parentcontrol-ru.ipk || {
        echo "WARNING: Translation package installation failed, continuing..."
    }
fi

# Cleanup downloaded packages
rm -f /tmp/*.ipk 2>/dev/null

# --- 4. Set permissions ---
echo "[5/12] Setting file permissions..."
[ -f "/usr/sbin/parentalcontrol" ] && chmod 755 /usr/sbin/parentalcontrol && echo "✓ /usr/sbin/parentalcontrol"
[ -f "/usr/bin/parentalcontrol-apply" ] && chmod 755 /usr/bin/parentalcontrol-apply && echo "✓ /usr/bin/parentalcontrol-apply"
[ -f "/etc/init.d/parentalcontrol-watch" ] && chmod 755 /etc/init.d/parentalcontrol-watch && echo "✓ /etc/init.d/parentalcontrol-watch"
[ -f "/etc/config/parentalcontrol" ] && chmod 644 /etc/config/parentalcontrol && echo "✓ /etc/config/parentalcontrol"

# --- 5. Cron job ---
echo "[6/12] Setting up cron job..."
if [ -f "/usr/bin/parentalcontrol-apply" ]; then
    # ensure crontab exists and add unique entry
    (crontab -l 2>/dev/null | grep -v "/usr/bin/parentalcontrol-apply"; echo "* * * * * /usr/bin/parentalcontrol-apply") | crontab -
    echo "✓ Cron job added: * * * * * /usr/bin/parentalcontrol-apply"
else
    echo "⚠ WARNING: /usr/bin/parentalcontrol-apply not found, skipping cron job"
fi

# --- 6. Start service ---
echo "[7/12] Starting service..."
if [ -f "/etc/init.d/parentalcontrol-watch" ]; then
    /etc/init.d/parentalcontrol-watch enable 2>/dev/null
    /etc/init.d/parentalcontrol-watch start 2>/dev/null && echo "✓ Service started successfully!" || echo "⚠ Service start failed (see logs)"
else
    echo "⚠ WARNING: Service file not found"
fi

# --- 7. Restart LuCI / RPCD if available ---
echo "[8/12] Restarting LuCI..."
if [ -x "/etc/init.d/uhttpd" ]; then
    /etc/init.d/uhttpd restart 2>/dev/null && echo "✓ uhttpd restarted" || echo "⚠ uhttpd restart failed"
fi
if [ -x "/etc/init.d/rpcd" ]; then
    /etc/init.d/rpcd restart 2>/dev/null && echo "✓ rpcd restarted" || echo "⚠ rpcd restart failed"
fi

# --- 8. Optional: check installed package existence ---
echo "[9/12] Verifying installation..."
if [ -f "/usr/bin/parentalcontrol-apply" ] || [ -f "/usr/sbin/parentalcontrol" ]; then
    echo "✓ Files present"
else
    echo "⚠ Warning: expected binaries not found. The package might have installed to different paths."
fi

# --- 9. Show access hint ---
echo ""
echo "🎉 Installation completed (if no errors above)."
echo "Parental Control is now installed (or attempted)."
echo "Cron job will apply rules every minute (if cron added)."
echo "Access via LuCI: Network → Parental Control (if LuCI page exists)."
echo ""

# --- 10. Uninstall hint ---
echo "To uninstall, run: opkg remove luci-app-parentcontrol luci-i18n-parentcontrol-ru"
echo ""

# --- 11. Exit ---
exit 0