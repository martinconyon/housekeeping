#!/bin/bash

#############################################################################
# macOS Security Hardening Script for Apple Silicon Macs
# Compatible with macOS Sequoia (15.0) and later
# Run with: bash m1_harden.sh
#############################################################################

set -euo pipefail
IFS=$'\n\t'

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Apple Silicon
check_apple_silicon() {
    if [[ $(uname -m) != "arm64" ]]; then
        log_error "This script is designed for Apple Silicon Macs only."
        exit 1
    fi
    log_success "Running on Apple Silicon Mac"
}

# Check macOS version (Sequoia is 15.0)
check_macos_version() {
    os_version=$(sw_vers -productVersion)
    major_version=$(echo "$os_version" | cut -d. -f1)
    
    if [[ $major_version -lt 15 ]]; then
        log_error "This script requires macOS Sequoia (15.0) or later. Current version: $os_version"
        exit 1
    fi
    log_success "macOS version $os_version is supported"
}

# Request sudo upfront
request_sudo() {
    log_info "Requesting administrator privileges..."
    if ! sudo -v; then
        log_error "Failed to obtain administrator privileges"
        exit 1
    fi
    
    # Keep sudo alive
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    
    log_success "Administrator privileges obtained"
}

# Enable FileVault
enable_filevault() {
    log_info "Checking FileVault status..."
    
    fv_status=$(fdesetup status 2>/dev/null || echo "error")
    
    if [[ "$fv_status" == *"FileVault is On"* ]]; then
        log_success "FileVault is already enabled"
    elif [[ "$fv_status" == *"FileVault is Off"* ]]; then
        log_info "Enabling FileVault with deferred recovery key..."
        
        # Check if current user has SecureToken
        current_user=$(whoami)
        if ! sysadminctl -secureTokenStatus "$current_user" 2>&1 | grep -q "ENABLED"; then
            log_warning "Current user does not have SecureToken. Attempting to enable..."
            # Note: This typically requires user interaction
            log_warning "SecureToken may need to be enabled manually"
        fi
        
        # Enable FileVault with deferred enablement
        if sudo fdesetup enable -defer /tmp/filevault_recovery.plist -forceatlogin 0 -dontaskatlogout 2>/dev/null; then
            log_success "FileVault enablement initiated (will complete at next login)"
            log_info "Recovery key will be escrowed per institutional recovery key"
        else
            log_warning "FileVault could not be enabled automatically. May require manual setup."
        fi
    else
        log_warning "Could not determine FileVault status"
    fi
}

# Enable and configure Firewall
enable_firewall() {
    log_info "Configuring Firewall..."
    
    # Enable firewall
    if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null; then
        log_success "Firewall enabled"
    else
        log_warning "Could not enable firewall"
    fi
    
    # Block all incoming connections
    if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on 2>/dev/null; then
        log_success "Firewall set to block all incoming connections"
    else
        log_warning "Could not set firewall to block all incoming"
    fi
    
    # Enable stealth mode
    if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null; then
        log_success "Stealth mode enabled"
    else
        log_warning "Could not enable stealth mode"
    fi
    
    # Enable logging
    if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on 2>/dev/null; then
        log_success "Firewall logging enabled"
    else
        log_warning "Could not enable firewall logging"
    fi
}

# Configure Gatekeeper
configure_gatekeeper() {
    log_info "Configuring Gatekeeper..."
    
    # Enable Gatekeeper
    if sudo spctl --master-enable 2>/dev/null; then
        log_success "Gatekeeper enabled"
    else
        log_warning "Could not enable Gatekeeper"
    fi
    
    # Set to App Store and identified developers
    if sudo spctl --enable --label "Developer ID" 2>/dev/null; then
        log_success "Gatekeeper set to allow signed apps only"
    else
        log_warning "Could not configure Gatekeeper settings"
    fi
}

# Enable automatic updates
enable_auto_updates() {
    log_info "Configuring automatic updates..."
    
    # Enable automatic check for updates
    if sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true 2>/dev/null; then
        log_success "Automatic update check enabled"
    else
        log_warning "Could not enable automatic update check"
    fi
    
    # Enable automatic download of updates
    if sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true 2>/dev/null; then
        log_success "Automatic update download enabled"
    else
        log_warning "Could not enable automatic update download"
    fi
    
    # Enable automatic install of macOS updates
    if sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool true 2>/dev/null; then
        log_success "Automatic macOS update installation enabled"
    else
        log_warning "Could not enable automatic macOS updates"
    fi
    
    # Enable automatic install of app updates
    if sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool true 2>/dev/null; then
        log_success "Automatic App Store update installation enabled"
    else
        log_warning "Could not enable automatic App Store updates"
    fi
    
    # Enable automatic install of critical updates
    if sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true 2>/dev/null; then
        log_success "Automatic critical update installation enabled"
    else
        log_warning "Could not enable automatic critical updates"
    fi
    
    # Enable automatic install of configuration data
    if sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool true 2>/dev/null; then
        log_success "Automatic configuration data installation enabled"
    else
        log_warning "Could not enable automatic configuration data updates"
    fi
}

# Disable diagnostics and analytics
disable_diagnostics() {
    log_info "Disabling diagnostics and analytics submission..."
    
    # Disable diagnostic data submission
    if sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist AutoSubmit -bool false 2>/dev/null; then
        log_success "Diagnostic data submission disabled"
    else
        log_warning "Could not disable diagnostic data submission"
    fi
    
    # Disable analytics sharing
    if defaults write com.apple.assistant.support "Siri Data Sharing Opt-In Status" -int 2 2>/dev/null; then
        log_success "Siri analytics sharing disabled"
    else
        log_warning "Could not disable Siri analytics"
    fi
    
    # Disable crash reporter
    if defaults write com.apple.CrashReporter DialogType -string "none" 2>/dev/null; then
        log_success "Crash reporter dialog disabled"
    else
        log_warning "Could not disable crash reporter dialog"
    fi
    
    # Disable ad tracking
    if defaults write com.apple.AdLib forceLimitAdTracking -bool true 2>/dev/null; then
        log_success "Ad tracking limited"
    else
        log_warning "Could not limit ad tracking"
    fi
}

# Additional security hardening
additional_hardening() {
    log_info "Applying additional security hardening..."
    
    # Disable AirDrop
    if defaults write com.apple.NetworkBrowser DisableAirDrop -bool true 2>/dev/null; then
        log_success "AirDrop disabled"
    else
        log_warning "Could not disable AirDrop"
    fi
    
    # Require password immediately after sleep
    if defaults write com.apple.screensaver askForPassword -int 1 2>/dev/null; then
        log_success "Password required after sleep"
    else
        log_warning "Could not set password requirement after sleep"
    fi
    
    if defaults write com.apple.screensaver askForPasswordDelay -int 0 2>/dev/null; then
        log_success "Password required immediately"
    else
        log_warning "Could not set immediate password requirement"
    fi
    
    # Disable guest account
    if sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false 2>/dev/null; then
        log_success "Guest account disabled"
    else
        log_warning "Could not disable guest account"
    fi
    
    # Enable secure keyboard entry in Terminal
    if defaults write com.apple.terminal SecureKeyboardEntry -bool true 2>/dev/null; then
        log_success "Secure keyboard entry enabled in Terminal"
    else
        log_warning "Could not enable secure keyboard entry"
    fi
}

# Verification and logging
verify_settings() {
    log_info "Verifying security settings..."
    echo ""
    echo "========================================="
    echo "SECURITY CONFIGURATION VERIFICATION"
    echo "========================================="
    echo ""
    
    # FileVault status
    echo "FileVault Status:"
    fdesetup status 2>/dev/null || echo "  Could not determine FileVault status"
    echo ""
    
    # Firewall status
    echo "Firewall Configuration:"
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "  Could not determine firewall status"
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getblockall 2>/dev/null || echo "  Could not determine block all status"
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null || echo "  Could not determine stealth mode status"
    echo ""
    
    # Gatekeeper status
    echo "Gatekeeper Status:"
    spctl --status 2>/dev/null || echo "  Could not determine Gatekeeper status"
    echo ""
    
    # Software Update settings
    echo "Automatic Update Settings:"
    echo "  AutomaticCheckEnabled: $(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo 'unknown')"
    echo "  AutomaticDownload: $(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload 2>/dev/null || echo 'unknown')"
    echo "  AutomaticallyInstallMacOSUpdates: $(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates 2>/dev/null || echo 'unknown')"
    echo "  CriticalUpdateInstall: $(defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall 2>/dev/null || echo 'unknown')"
    echo ""
    
    # System information
    echo "System Information:"
    echo "  Architecture: $(uname -m)"
    echo "  macOS Version: $(sw_vers -productVersion)"
    echo "  Build: $(sw_vers -buildVersion)"
    echo ""
    
    # Log file creation
    log_file="$HOME/Desktop/mac_hardening_$(date +%Y%m%d_%H%M%S).log"
    echo "Creating detailed log file: $log_file"
    
    {
        echo "macOS Hardening Script Log"
        echo "=========================="
        echo "Date: $(date)"
        echo "User: $(whoami)"
        echo "System: $(system_profiler SPHardwareDataType | grep "Model Name" | sed 's/.*: //')"
        echo ""
        echo "Security Settings Applied:"
        echo "--------------------------"
        fdesetup status
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getblockall
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
        spctl --status
        echo ""
        echo "All defaults written during hardening process"
    } > "$log_file" 2>&1
    
    log_success "Verification complete. Log saved to: $log_file"
}

# Main execution
main() {
    echo ""
    echo "================================================"
    echo "macOS Security Hardening Script"
    echo "For Apple Silicon Macs (M1/M2/M3)"
    echo "================================================"
    echo ""
    
    # Run checks
    check_apple_silicon
    check_macos_version
    request_sudo
    
    echo ""
    log_info "Starting security hardening process..."
    echo ""
    
    # Apply hardening
    enable_filevault
    enable_firewall
    configure_gatekeeper
    enable_auto_updates
    disable_diagnostics
    additional_hardening
    
    echo ""
    # Verify settings
    verify_settings
    
    echo ""
    echo "================================================"
    log_success "Security hardening process complete!"
    echo "================================================"
    echo ""
    echo "IMPORTANT NOTES:"
    echo "1. Some settings may require a restart to take full effect"
    echo "2. FileVault encryption (if newly enabled) will complete in the background"
    echo "3. Review the log file on your Desktop for detailed results"
    echo ""
}

# Run main function
main "$@"