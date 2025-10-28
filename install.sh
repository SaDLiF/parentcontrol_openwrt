#!/bin/sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base URL for GitHub repository
REPO_URL="https://github.com/SaDLiF/parentcontrol_openwrt"
API_URL="https://api.github.com/repos/SaDLiF/parentcontrol_openwrt/releases/latest"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect architecture
detect_arch() {
    local arch
    arch=$(opkg print-architecture | awk '{print $2}' | head -1)
    
    if [ -z "$arch" ]; then
        arch=$(uname -m)
        case "$arch" in
            x86_64)
                arch="x86_64"
                ;;
            aarch64)
                arch="aarch64_cortex-a53"
                ;;
            armv7l)
                arch="arm_cortex-a7_neon-vfpv4"
                ;;
            mips)
                arch="mipsel_24kc"
                ;;
            *)
                print_error "Unsupported architecture: $arch"
                exit 1
                ;;
        esac
    fi
    
    echo "$arch"
}

# Get latest release info
get_latest_release() {
    print_info "Fetching latest release information..."
    
    # Try to get release info from GitHub API
    response=$(curl -s "$API_URL")
    
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        print_error "Failed to fetch release information"
        exit 1
    fi
    
    # Extract download URL for IPK file
    download_url=$(echo "$response" | grep -o "browser_download_url.*\.ipk" | cut -d'"' -f4 | head -1)
    
    if [ -z "$download_url" ]; then
        print_error "No IPK file found in latest release"
        exit 1
    fi
    
    echo "$download_url"
}

# Download and install IPK
download_and_install() {
    local download_url="$1"
    local ipk_name="parentcontrol_latest.ipk"
    
    print_info "Downloading latest IPK package..."
    wget -O "/tmp/$ipk_name" "$download_url"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to download IPK package"
        exit 1
    fi
    
    print_info "Installing package..."
    opkg install "/tmp/$ipk_name"
    
    if [ $? -eq 0 ]; then
        print_info "Installation completed successfully!"
        
        # Cleanup
        rm -f "/tmp/$ipk_name"
        
        # Start service
        if [ -f "/etc/init.d/parentalcontrol-watch" ]; then
            print_info "Starting parentalcontrol service..."
            /etc/init.d/parentalcontrol-watch enable
            /etc/init.d/parentalcontrol-watch start
        fi
        
        print_info "Parental Control has been installed and started!"
        print_info "You can access it via LuCI web interface"
        
    else
        print_error "Installation failed"
        rm -f "/tmp/$ipk_name"
        exit 1
    fi
}

# Main installation function
main() {
    print_info "Starting Parental Control installation..."
    
    # Check if we're on OpenWRT
    if [ ! -f "/etc/openwrt_release" ]; then
        print_error "This script must be run on an OpenWRT system"
        exit 1
    fi
    
    # Check for required commands
    for cmd in opkg wget curl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_error "Required command '$cmd' not found"
            exit 1
        fi
    done
    
    # Get download URL
    download_url=$(get_latest_release)
    
    if [ -n "$download_url" ]; then
        print_info "Found IPK: $download_url"
        download_and_install "$download_url"
    else
        print_error "Could not find suitable IPK package"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    -h|--help)
        echo "Parental Control Installer"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  -h, --help    Show this help message"
        echo "  -v, --version Show version information"
        echo ""
        echo "This script will automatically:"
        echo "1. Detect your device architecture"
        echo "2. Download the latest IPK from GitHub releases"
        echo "3. Install and configure Parental Control"
        exit 0
        ;;
    -v|--version)
        echo "Parental Control Installer v1.0"
        exit 0
        ;;
    *)
        main
        ;;
esac