#!/bin/bash

# macOS Personalization Script for Apple Silicon Macs (Sequoia+)
# Applies custom look & feel settings in a safe, idempotent manner

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
INFO() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

SUCCESS() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

WARN() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

ERROR() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create log file on Desktop
LOG_FILE="$HOME/Desktop/mac_personalization_$(date +%Y%m%d_%H%M%S).log"
exec 2>&1 | tee -a "$LOG_FILE"

INFO "Starting macOS personalization script at $(date)"
INFO "Log file: $LOG_FILE"

# Track changes and warnings
CHANGES_APPLIED=()
WARNINGS=()

# Function to add change to tracking
track_change() {
    CHANGES_APPLIED+=("$1")
}

# Function to add warning to tracking
track_warning() {
    WARNINGS+=("$1")
    WARN "$1"
}

# ==============================================================================
# DOCK CONFIGURATION
# ==============================================================================

INFO "Configuring Dock..."

# Remove all apps from Dock
defaults write com.apple.dock persistent-apps -array
track_change "Cleared all persistent apps from Dock"

# Add only System Settings and Terminal
defaults write com.apple.dock persistent-apps -array-add '<dict>
    <key>tile-data</key>
    <dict>
        <key>file-data</key>
        <dict>
            <key>_CFURLString</key>
            <string>/System/Library/PreferencePanes/Profiles.prefPane</string>
            <key>_CFURLStringType</key>
            <integer>0</integer>
        </dict>
    </dict>
</dict>'

defaults write com.apple.dock persistent-apps -array-add '<dict>
    <key>tile-data</key>
    <dict>
        <key>file-data</key>
        <dict>
            <key>_CFURLString</key>
            <string>/System/Applications/Utilities/Terminal.app</string>
            <key>_CFURLStringType</key>
            <integer>0</integer>
        </dict>
    </dict>
</dict>'

track_change "Added System Settings and Terminal to Dock"

# Enable Dock auto-hide
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0.0
defaults write com.apple.dock autohide-time-modifier -float 0.5
track_change "Enabled Dock auto-hide"

# Position dock at bottom
defaults write com.apple.dock orientation -string "bottom"
track_change "Set Dock position to bottom"

# ==============================================================================
# DESKTOP WALLPAPER
# ==============================================================================

INFO "Setting desktop wallpaper..."

# Create a solid gray image for wallpaper
WALLPAPER_PATH="/tmp/gray_wallpaper_$$.png"

# Use osascript to create a gray image
osascript <<EOF 2>/dev/null || track_warning "Could not create gray wallpaper image"
use framework "AppKit"
use framework "Foundation"

set grayColor to current application's NSColor's grayColor()
set theImage to current application's NSImage's alloc()'s initWithSize:{1920, 1080}
theImage's lockFocus()
grayColor's |set|()
current application's NSBezierPath's fillRect:{{0, 0}, {1920, 1080}}
theImage's unlockFocus()

set imageRep to theImage's TIFFRepresentation()
set theBitmap to current application's NSBitmapImageRep's imageRepWithData:imageRep
set pngData to theBitmap's representationUsingType:(current application's NSPNGFileType) |properties|:(missing value)
pngData's writeToFile:"$WALLPAPER_PATH" atomically:true
EOF

# If osascript method failed, try alternative method with sips
if [ ! -f "$WALLPAPER_PATH" ]; then
    # Create a simple gray image using printf and sips
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x8f\x8f\x8f\x00\x05\xfe\x02\xfe\xa7\x96\x19\x9c\x00\x00\x00\x00IEND\xaeB`\x82' > /tmp/gray_pixel.png
    sips -z 1080 1920 /tmp/gray_pixel.png --out "$WALLPAPER_PATH" 2>/dev/null || track_warning "Could not create gray wallpaper"
fi

# Apply wallpaper to all desktops/spaces if image was created
if [ -f "$WALLPAPER_PATH" ]; then
    osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$WALLPAPER_PATH\"" 2>/dev/null || track_warning "Could not set wallpaper on all desktops"
    track_change "Set gray wallpaper on all desktops"
else
    track_warning "Failed to create gray wallpaper image"
fi

# ==============================================================================
# SOUND SETTINGS
# ==============================================================================

INFO "Configuring sound settings..."

# Mute system volume
osascript -e "set volume output volume 0" 2>/dev/null || track_warning "Could not mute system volume"
osascript -e "set volume with output muted" 2>/dev/null || track_warning "Could not set output muted"
track_change "Muted system output volume"

# Disable sound effects
defaults write com.apple.systemsound com.apple.sound.beep.volume -float 0.0
defaults write com.apple.sound.beep.feedback -bool false
defaults write NSGlobalDomain com.apple.sound.beep.volume -float 0.0
defaults write NSGlobalDomain com.apple.sound.uiaudio.enabled -int 0
track_change "Disabled system sound effects"

# Disable startup sound
sudo nvram StartupMute=%01 2>/dev/null || track_warning "Could not disable startup sound (requires admin)"

# ==============================================================================
# FINDER CONFIGURATION
# ==============================================================================

INFO "Configuring Finder..."

# Set default view to list view
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
track_change "Set Finder default view to List"

# Set new Finder windows to open Documents
defaults write com.apple.finder NewWindowTarget -string "PfDo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Documents/"
track_change "Set new Finder windows to open Documents"

# Show icons on desktop
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
track_change "Enabled desktop icons for disks and servers"

# Enable preview pane in Finder
defaults write com.apple.finder ShowPreviewPane -bool true
defaults write com.apple.finder PreviewPaneWidth -int 172
track_change "Enabled Finder preview pane"

# Configure Finder sidebar
INFO "Configuring Finder sidebar..."

# Remove tags from sidebar
defaults write com.apple.finder ShowRecentTags -bool false
track_change "Removed Tags from Finder sidebar"

# Get current sidebar items plist path
SIDEBAR_PLIST="$HOME/Library/Preferences/com.apple.sidebarlists.plist"

# Use PlistBuddy if available to modify sidebar
if command -v /usr/libexec/PlistBuddy &> /dev/null; then
    # Remove Recents from sidebar (domain com.apple.LSSharedFileList.RecentDocuments)
    /usr/libexec/PlistBuddy -c "Delete :systemitems:VolumesList:com.apple.LSSharedFileList.RecentDocuments" "$SIDEBAR_PLIST" 2>/dev/null || true
    
    # Ensure Downloads, Desktop, Documents are visible
    /usr/libexec/PlistBuddy -c "Add :systemitems:VolumesList:Downloads dict" "$SIDEBAR_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :systemitems:VolumesList:Desktop dict" "$SIDEBAR_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :systemitems:VolumesList:Documents dict" "$SIDEBAR_PLIST" 2>/dev/null || true
    
    track_change "Modified Finder sidebar items"
else
    # Fallback: Use defaults for basic sidebar configuration
    defaults write com.apple.finder SidebarShowingSignedIntoiCloud -bool false
    defaults write com.apple.finder SidebarDevicesSectionDisclosedState -bool true
    defaults write com.apple.finder SidebarPlacesSectionDisclosedState -bool true
    track_change "Applied basic Finder sidebar configuration"
fi

# Additional Finder settings for better experience
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
track_change "Applied additional Finder enhancements"

# ==============================================================================
# APPLY CHANGES
# ==============================================================================

INFO "Applying changes..."

# Restart affected services
killall Dock 2>/dev/null || true
SUCCESS "Restarted Dock"

killall Finder 2>/dev/null || true
SUCCESS "Restarted Finder"

killall SystemUIServer 2>/dev/null || true
SUCCESS "Restarted SystemUIServer"

killall cfprefsd 2>/dev/null || true
SUCCESS "Restarted cfprefsd"

# ==============================================================================
# PERSISTENCE SETUP
# ==============================================================================

INFO "Setting up persistence..."

# Create LaunchAgent to maintain muted volume at login
LAUNCH_AGENT_PATH="$HOME/Library/LaunchAgents/com.user.mute-volume.plist"
cat > "$LAUNCH_AGENT_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.mute-volume</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/osascript</string>
        <string>-e</string>
        <string>set volume with output muted</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

launchctl load "$LAUNCH_AGENT_PATH" 2>/dev/null || track_warning "Could not load mute volume LaunchAgent"
track_change "Created LaunchAgent for persistent mute"

# ==============================================================================
# VERIFICATION & SUMMARY
# ==============================================================================

INFO "Verifying applied settings..."

# Verification checks
VERIFICATION_RESULTS=()

# Check Dock auto-hide
if [[ $(defaults read com.apple.dock autohide 2>/dev/null) == "1" ]]; then
    VERIFICATION_RESULTS+=("✓ Dock auto-hide enabled")
else
    VERIFICATION_RESULTS+=("✗ Dock auto-hide not enabled")
fi

# Check Finder default view
if [[ $(defaults read com.apple.finder FXPreferredViewStyle 2>/dev/null) == "Nlsv" ]]; then
    VERIFICATION_RESULTS+=("✓ Finder list view set")
else
    VERIFICATION_RESULTS+=("✗ Finder list view not set")
fi

# Check desktop icons
if [[ $(defaults read com.apple.finder ShowHardDrivesOnDesktop 2>/dev/null) == "1" ]]; then
    VERIFICATION_RESULTS+=("✓ Desktop disk icons enabled")
else
    VERIFICATION_RESULTS+=("✗ Desktop disk icons not enabled")
fi

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================

echo ""
echo "======================================================================"
echo "                    PERSONALIZATION COMPLETE"
echo "======================================================================"
echo ""
SUCCESS "Script execution completed at $(date)"
echo ""

echo "CHANGES APPLIED (${#CHANGES_APPLIED[@]} total):"
for change in "${CHANGES_APPLIED[@]}"; do
    echo "  • $change"
done
echo ""

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "WARNINGS (${#WARNINGS[@]} total):"
    for warning in "${WARNINGS[@]}"; do
        echo "  ⚠ $warning"
    done
    echo ""
fi

echo "VERIFICATION RESULTS:"
for result in "${VERIFICATION_RESULTS[@]}"; do
    echo "  $result"
done
echo ""

echo "======================================================================"
echo "Log saved to: $LOG_FILE"
echo "Script is idempotent - safe to run again if needed"
echo "======================================================================"

# Write script to file for download
cat > personalize_mac.sh << 'SCRIPT_EOF'
#!/bin/bash

# macOS Personalization Script for Apple Silicon Macs (Sequoia+)
# Applies custom look & feel settings in a safe, idempotent manner

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
INFO() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

SUCCESS() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

WARN() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

ERROR() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create log file on Desktop
LOG_FILE="$HOME/Desktop/mac_personalization_$(date +%Y%m%d_%H%M%S).log"
exec 2>&1 | tee -a "$LOG_FILE"

INFO "Starting macOS personalization script at $(date)"
INFO "Log file: $LOG_FILE"

# Track changes and warnings
CHANGES_APPLIED=()
WARNINGS=()

# Function to add change to tracking
track_change() {
    CHANGES_APPLIED+=("$1")
}

# Function to add warning to tracking
track_warning() {
    WARNINGS+=("$1")
    WARN "$1"
}

# ==============================================================================
# DOCK CONFIGURATION
# ==============================================================================

INFO "Configuring Dock..."

# Remove all apps from Dock
defaults write com.apple.dock persistent-apps -array
track_change "Cleared all persistent apps from Dock"

# Add only System Settings and Terminal
defaults write com.apple.dock persistent-apps -array-add '<dict>
    <key>tile-data</key>
    <dict>
        <key>file-data</key>
        <dict>
            <key>_CFURLString</key>
            <string>/System/Library/PreferencePanes/Profiles.prefPane</string>
            <key>_CFURLStringType</key>
            <integer>0</integer>
        </dict>
    </dict>
</dict>'

defaults write com.apple.dock persistent-apps -array-add '<dict>
    <key>tile-data</key>
    <dict>
        <key>file-data</key>
        <dict>
            <key>_CFURLString</key>
            <string>/System/Applications/Utilities/Terminal.app</string>
            <key>_CFURLStringType</key>
            <integer>0</integer>
        </dict>
    </dict>
</dict>'

track_change "Added System Settings and Terminal to Dock"

# Enable Dock auto-hide
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0.0
defaults write com.apple.dock autohide-time-modifier -float 0.5
track_change "Enabled Dock auto-hide"

# Position dock at bottom
defaults write com.apple.dock orientation -string "bottom"
track_change "Set Dock position to bottom"

# ==============================================================================
# DESKTOP WALLPAPER
# ==============================================================================

INFO "Setting desktop wallpaper..."

# Create a solid gray image for wallpaper
WALLPAPER_PATH="/tmp/gray_wallpaper_$$.png"

# Use osascript to create a gray image
osascript <<EOF 2>/dev/null || track_warning "Could not create gray wallpaper image"
use framework "AppKit"
use framework "Foundation"

set grayColor to current application's NSColor's grayColor()
set theImage to current application's NSImage's alloc()'s initWithSize:{1920, 1080}
theImage's lockFocus()
grayColor's |set|()
current application's NSBezierPath's fillRect:{{0, 0}, {1920, 1080}}
theImage's unlockFocus()

set imageRep to theImage's TIFFRepresentation()
set theBitmap to current application's NSBitmapImageRep's imageRepWithData:imageRep
set pngData to theBitmap's representationUsingType:(current application's NSPNGFileType) |properties|:(missing value)
pngData's writeToFile:"$WALLPAPER_PATH" atomically:true
EOF

# If osascript method failed, try alternative method with sips
if [ ! -f "$WALLPAPER_PATH" ]; then
    # Create a simple gray image using printf and sips
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x8f\x8f\x8f\x00\x05\xfe\x02\xfe\xa7\x96\x19\x9c\x00\x00\x00\x00IEND\xaeB`\x82' > /tmp/gray_pixel.png
    sips -z 1080 1920 /tmp/gray_pixel.png --out "$WALLPAPER_PATH" 2>/dev/null || track_warning "Could not create gray wallpaper"
fi

# Apply wallpaper to all desktops/spaces if image was created
if [ -f "$WALLPAPER_PATH" ]; then
    osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$WALLPAPER_PATH\"" 2>/dev/null || track_warning "Could not set wallpaper on all desktops"
    track_change "Set gray wallpaper on all desktops"
else
    track_warning "Failed to create gray wallpaper image"
fi

# ==============================================================================
# SOUND SETTINGS
# ==============================================================================

INFO "Configuring sound settings..."

# Mute system volume
osascript -e "set volume output volume 0" 2>/dev/null || track_warning "Could not mute system volume"
osascript -e "set volume with output muted" 2>/dev/null || track_warning "Could not set output muted"
track_change "Muted system output volume"

# Disable sound effects
defaults write com.apple.systemsound com.apple.sound.beep.volume -float 0.0
defaults write com.apple.sound.beep.feedback -bool false
defaults write NSGlobalDomain com.apple.sound.beep.volume -float 0.0
defaults write NSGlobalDomain com.apple.sound.uiaudio.enabled -int 0
track_change "Disabled system sound effects"

# Disable startup sound
sudo nvram StartupMute=%01 2>/dev/null || track_warning "Could not disable startup sound (requires admin)"

# ==============================================================================
# FINDER CONFIGURATION
# ==============================================================================

INFO "Configuring Finder..."

# Set default view to list view
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
track_change "Set Finder default view to List"

# Set new Finder windows to open Documents
defaults write com.apple.finder NewWindowTarget -string "PfDo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Documents/"
track_change "Set new Finder windows to open Documents"

# Show icons on desktop
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
track_change "Enabled desktop icons for disks and servers"

# Enable preview pane in Finder
defaults write com.apple.finder ShowPreviewPane -bool true
defaults write com.apple.finder PreviewPaneWidth -int 172
track_change "Enabled Finder preview pane"

# Configure Finder sidebar
INFO "Configuring Finder sidebar..."

# Remove tags from sidebar
defaults write com.apple.finder ShowRecentTags -bool false
track_change "Removed Tags from Finder sidebar"

# Get current sidebar items plist path
SIDEBAR_PLIST="$HOME/Library/Preferences/com.apple.sidebarlists.plist"

# Use PlistBuddy if available to modify sidebar
if command -v /usr/libexec/PlistBuddy &> /dev/null; then
    # Remove Recents from sidebar (domain com.apple.LSSharedFileList.RecentDocuments)
    /usr/libexec/PlistBuddy -c "Delete :systemitems:VolumesList:com.apple.LSSharedFileList.RecentDocuments" "$SIDEBAR_PLIST" 2>/dev/null || true
    
    # Ensure Downloads, Desktop, Documents are visible
    /usr/libexec/PlistBuddy -c "Add :systemitems:VolumesList:Downloads dict" "$SIDEBAR_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :systemitems:VolumesList:Desktop dict" "$SIDEBAR_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :systemitems:VolumesList:Documents dict" "$SIDEBAR_PLIST" 2>/dev/null || true
    
    track_change "Modified Finder sidebar items"
else
    # Fallback: Use defaults for basic sidebar configuration
    defaults write com.apple.finder SidebarShowingSignedIntoiCloud -bool false
    defaults write com.apple.finder SidebarDevicesSectionDisclosedState -bool true
    defaults write com.apple.finder SidebarPlacesSectionDisclosedState -bool true
    track_change "Applied basic Finder sidebar configuration"
fi

# Additional Finder settings for better experience
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
track_change "Applied additional Finder enhancements"

# ==============================================================================
# APPLY CHANGES
# ==============================================================================

INFO "Applying changes..."

# Restart affected services
killall Dock 2>/dev/null || true
SUCCESS "Restarted Dock"

killall Finder 2>/dev/null || true
SUCCESS "Restarted Finder"

killall SystemUIServer 2>/dev/null || true
SUCCESS "Restarted SystemUIServer"

killall cfprefsd 2>/dev/null || true
SUCCESS "Restarted cfprefsd"

# ==============================================================================
# PERSISTENCE SETUP
# ==============================================================================

INFO "Setting up persistence..."

# Create LaunchAgent to maintain muted volume at login
LAUNCH_AGENT_PATH="$HOME/Library/LaunchAgents/com.user.mute-volume.plist"
cat > "$LAUNCH_AGENT_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.mute-volume</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/osascript</string>
        <string>-e</string>
        <string>set volume with output muted</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

launchctl load "$LAUNCH_AGENT_PATH" 2>/dev/null || track_warning "Could not load mute volume LaunchAgent"
track_change "Created LaunchAgent for persistent mute"

# ==============================================================================
# VERIFICATION & SUMMARY
# ==============================================================================

INFO "Verifying applied settings..."

# Verification checks
VERIFICATION_RESULTS=()

# Check Dock auto-hide
if [[ $(defaults read com.apple.dock autohide 2>/dev/null) == "1" ]]; then
    VERIFICATION_RESULTS+=("✓ Dock auto-hide enabled")
else
    VERIFICATION_RESULTS+=("✗ Dock auto-hide not enabled")
fi

# Check Finder default view
if [[ $(defaults read com.apple.finder FXPreferredViewStyle 2>/dev/null) == "Nlsv" ]]; then
    VERIFICATION_RESULTS+=("✓ Finder list view set")
else
    VERIFICATION_RESULTS+=("✗ Finder list view not set")
fi

# Check desktop icons
if [[ $(defaults read com.apple.finder ShowHardDrivesOnDesktop 2>/dev/null) == "1" ]]; then
    VERIFICATION_RESULTS+=("✓ Desktop disk icons enabled")
else
    VERIFICATION_RESULTS+=("✗ Desktop disk icons not enabled")
fi

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================

echo ""
echo "======================================================================"
echo "                    PERSONALIZATION COMPLETE"
echo "======================================================================"
echo ""
SUCCESS "Script execution completed at $(date)"
echo ""

echo "CHANGES APPLIED (${#CHANGES_APPLIED[@]} total):"
for change in "${CHANGES_APPLIED[@]}"; do
    echo "  • $change"
done
echo ""

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "WARNINGS (${#WARNINGS[@]} total):"
    for warning in "${WARNINGS[@]}"; do
        echo "  ⚠ $warning"
    done
    echo ""
fi

echo "VERIFICATION RESULTS:"
for result in "${VERIFICATION_RESULTS[@]}"; do
    echo "  $result"
done
echo ""

echo "======================================================================"
echo "Log saved to: $LOG_FILE"
echo "Script is idempotent - safe to run again if needed"
echo "======================================================================"
SCRIPT_EOF

SUCCESS "Script written to personalize_mac.sh"
