#!/bin/sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

print_debug() {
    echo -e "${YELLOW}[DEBUG]${NC} $1"
}

# Detect architecture
detect_arch() {
    print_debug "Starting architecture detection..."
    
    local arch
    
    # First try opkg
    print_debug "Checking if opkg command exists..."
    if command -v opkg >/dev/null 2>&1; then
        print_debug "opkg found, getting architecture..."
        arch=$(opkg print-architecture | awk '{print $2}' | head -1)
        print_debug "opkg architecture: $arch"
    else
        print_debug "opkg not found"
    fi

    # If not found, use uname
    if [ -z "$arch" ]; then
        print_debug "Using uname to detect architecture..."
        arch=$(uname -m)
        print_debug "uname architecture: $arch"
        
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
            mips|mipsel)
                arch="mipsel_24kc"
                ;;
            *)
                print_warn "Unknown architecture: $arch, using generic"
                arch="unknown"
                ;;
        esac
    fi 

    print_debug "Final architecture: $arch"
    echo "$arch"   
}

# Get latest release info
get_latest_release() {
    print_debug "Starting get_latest_release function..."
    print_info "Fetching latest release information..."
    
    print_debug "Trying to fetch from GitHub API..."
    # Try to get release info from GitHub API
    response=$(curl -s "https://api.github.com/repos/SaDLiF/parentcontrol_openwrt/releases/latest" || wget -qO - "https://api.github.com/repos/SaDLiF/parentcontrol_openwrt/releases/latest")
    
    print_debug "Curl/wget exit code: $?"
    print_debug "Response length: ${#response}"
    
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        print_error "Failed to fetch release information"
        return 1
    fi
    
    print_debug "Extracting download URL from response..."
    # Extract download URL for IPK file
    download_url=$(echo "$response" | grep -o "browser_download_url.*\.ipk" | cut -d'"' -f4 | head -1)
    
    print_debug "Download URL found: $download_url"
    
    if [ -z "$download_url" ]; then
        print_error "No IPK file found in latest release"
        return 1
    fi
    
    echo "$download_url"
}

# Download and install IPK
download_and_install() {
    print_debug "Starting download_and_install function..."
    local download_url="$1"
    local ipk_name="parentcontrol_latest.ipk"
    
    print_info "Downloading latest IPK package..."
    print_debug "Download URL: $download_url"
    print_debug "Target file: /tmp/$ipk_name"
    
    if ! wget -O "/tmp/$ipk_name" "$download_url"; then
        print_error "Failed to download IPK package"
        return 1
    fi
    
    print_debug "Download completed, checking file..."
    if [ -f "/tmp/$ipk_name" ]; then
        print_debug "File size: $(ls -la /tmp/$ipk_name | awk '{print $5}') bytes"
    else
        print_error "Downloaded file not found"
        return 1
    fi
    
    print_info "Installing package..."
    print_debug "Running: opkg install /tmp/$ipk_name"
    
    if opkg install "/tmp/$ipk_name"; then
        print_info "Installation completed successfully!"
        
        # Cleanup
        print_debug "Cleaning up temporary file..."
        rm -f "/tmp/$ipk_name"
        
        # Start service
        print_debug "Checking for service file..."
        if [ -f "/etc/init.d/parentalcontrol-watch" ]; then
            print_info "Starting parentalcontrol service..."
            print_debug "Enabling service..."
            /etc/init.d/parentalcontrol-watch enable
            print_debug "Starting service..."
            /etc/init.d/parentalcontrol-watch start
            print_info "Service started successfully!"
        else
            print_warn "Service file not found, manual start may be required"
            print_debug "Service file path: /etc/init.d/parentalcontrol-watch"
        fi
        
        print_info "Parental Control has been installed and started!"
        print_info "You can access it via LuCI web interface"
        
    else
        print_error "Installation failed"
        print_debug "Removing temporary file after failed installation..."
        rm -f "/tmp/$ipk_name"
        return 1
    fi
}

# Main installation function
main() {
    print_debug "=== STARTING PARENTAL CONTROL INSTALLER ==="
    print_info "Starting Parental Control installation..."
    
    print_debug "Checking current directory: $(pwd)"
    print_debug "Checking user: $(whoami)"
    
    # Check for required commands
    print_debug "Checking required commands..."
    for cmd in opkg wget; do
        print_debug "Checking command: $cmd"
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_error "Required command '$cmd' not found"
            print_debug "Command $cmd not found in PATH: $PATH"
            exit 1
        else
            print_debug "Command $cmd found: $(which $cmd)"
        fi
    done
    
    print_debug "All required commands found, proceeding..."
    
    # Detect architecture (for debugging)
    print_debug "Detecting architecture..."
    arch=$(detect_arch)
    print_info "Detected architecture: $arch"
    
    # Get download URL
    print_debug "Getting latest release info..."
    download_url=$(get_latest_release)
    
    print_debug "Download URL result: $download_url"
    
    if [ -n "$download_url" ] && [ "$download_url" != "1" ]; then
        print_info "Found IPK: $download_url"
        download_and_install "$download_url"
    else
        print_error "Could not find suitable IPK package"
        print_debug "Download URL was empty or error"
        exit 1
    fi
    
    print_debug "=== INSTALLATION COMPLETED ==="
}

# Run main function
print_debug "Script started, calling main function..."
main "$@"
print_debug "Script finished with exit code: $?"