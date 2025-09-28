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
# FIX: ensure user LaunchAgents dir exists; then create+load the agent ---
# ==============================================================================


INFO "Setting up persistence..."

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PATH="$LAUNCH_AGENTS_DIR/com.user.mute-volume.plist"
LAUNCH_LABEL="com.user.mute-volume"

# 1) Create directory if missing
/bin/mkdir -p "$LAUNCH_AGENTS_DIR"

# 2) Write the plist
/bin/cat > "$LAUNCH_AGENT_PATH" <<'EOF'
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

# 3) Load/refresh the agent for the logged-in (console) user
CONSOLE_UID="$(id -u "$(stat -f %Su /dev/console)")"
/bin/launchctl bootout "gui/$CONSOLE_UID" "$LAUNCH_AGENT_PATH" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "gui/$CONSOLE_UID" "$LAUNCH_AGENT_PATH"
/bin/launchctl enable "gui/$CONSOLE_UID/$LAUNCH_LABEL"
/bin/launchctl kickstart -k "gui/$CONSOLE_UID/$LAUNCH_LABEL"

SUCCESS "Installed and loaded $LAUNCH_LABEL"



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


set_wallpaper_gray() {
  # 1) Create (or reuse) a solid mid-gray image the system can use as wallpaper.
  #    Stored in the user's Pictures; avoids permission issues under /Library.
  GRAY_WALL="$HOME/Pictures/wallpaper_gray_50.png"
  if [ ! -f "$GRAY_WALL" ]; then
    /usr/bin/sips -s format png --resampleWidth 1920 /System/Library/CoreServices/DefaultBackgroundHD.jpg --out "$GRAY_WALL" >/dev/null 2>&1
    # Overpaint to mid-gray; Preview can't be scripted, so use sips trick: desaturate + gamma to flatten.
    /usr/bin/sips -s saturation 0 -s brightness 0.5 "$GRAY_WALL" >/dev/null 2>&1
  fi

  # 2) Apply to every desktop/Space in the **user context** via AppleScript.
  /usr/bin/osascript <<'APPLESCRIPT' "$GRAY_WALL"
on run argv
  set p to POSIX file (item 1 of argv) as alias
  tell application "System Events"
    repeat with d in desktops
      try
        set picture of d to p
      end try
    end repeat
  end tell
end run
APPLESCRIPT

  # 3) Restart Dock so the change is immediate on all Spaces.
  /usr/bin/killall Dock >/dev/null 2>&1 || true
}


# ==============================================================================
# ENABLE TAP TO CLICK
# ==============================================================================


enable_tap_to_click() {
  # Enable tap-to-click for the current (console) user and at the login window.
  # Works on Apple Silicon, macOS Sequoia 15.x. Safe to run repeatedly.

  set -euo pipefail

  # Resolve the console (logged-in) username and uid even if running with sudo/root.
  CONSOLE_USER="$(stat -f %Su /dev/console)"
  CONSOLE_UID="$(id -u "$CONSOLE_USER")"

  write_user_defaults() {
    /usr/bin/sudo -u "$CONSOLE_USER" /usr/bin/defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
    /usr/bin/sudo -u "$CONSOLE_USER" /usr/bin/defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    # Some components read this key; set both in user and currentHost domains.
    /usr/bin/sudo -u "$CONSOLE_USER" /usr/bin/defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    /usr/bin/sudo -u "$CONSOLE_USER" /usr/bin/defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  }

  write_system_defaults_for_loginwindow() {
    # Apply at the login screen (system domain). Does not override per-user settings.
    /usr/bin/defaults write /Library/Preferences/com.apple.AppleMultitouchTrackpad Clicking -bool true
    /usr/bin/defaults write /Library/Preferences/com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    /usr/bin/defaults write /Library/Preferences/.GlobalPreferences com.apple.mouse.tapBehavior -int 1
    /usr/bin/defaults -currentHost write /Library/Preferences/.GlobalPreferences com.apple.mouse.tapBehavior -int 1
  }

  apply_now() {
    # Flush caches and refresh UI so the change is immediate in the user session.
    /bin/launchctl asuser "$CONSOLE_UID" /usr/bin/killall cfprefsd >/dev/null 2>&1 || true
    /bin/launchctl asuser "$CONSOLE_UID" /usr/bin/killall SystemUIServer >/dev/null 2>&1 || true
  }

  write_user_defaults
  write_system_defaults_for_loginwindow
  apply_now
}



# ==============================================================================
# ENABLE SECONDARY CLICK (BOTTOM RIGHT CORNER)
# ==============================================================================

enable_secondary_click_bottom_right() {
  # Force secondary (right) click to the bottom-right corner (not two-finger).
  # Apple Silicon; macOS Sequoia 15.x. Idempotent.

  set -euo pipefail

  CONSOLE_USER="$(stat -f %Su /dev/console)"
  CONSOLE_UID="$(id -u "$CONSOLE_USER")"
  U="/usr/bin/sudo -u $CONSOLE_USER"
  PB="/usr/libexec/PlistBuddy"

  # 0) Ensure the Trackpad pane is not open (it can immediately overwrite changes)
  /bin/launchctl asuser "$CONSOLE_UID" /usr/bin/osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1 || true

  # 1) Per-device domains (built-in + Bluetooth trackpad)
  $U /usr/bin/defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -int 0
  $U /usr/bin/defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
  $U /usr/bin/defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -int 0
  $U /usr/bin/defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2

  # 2) ByHost globals that System Settings consults
  $U /usr/bin/defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true
  $U /usr/bin/defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1  # 1=bottom-right

  # 2b) Defensive: ensure the keys exist on disk via PlistBuddy as well
  HOST_UUID="$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F\" '/IOPlatformUUID/{print $4}')"
  BYHOST_PLIST="$HOME/Library/Preferences/ByHost/.GlobalPreferences.$HOST_UUID.plist"
  USER_PLIST="$HOME/Library/Preferences/com.apple.AppleMultitouchTrackpad.plist"

  $U $PB -c "Set :TrackpadRightClick 0" "$USER_PLIST" 2>/dev/null || $U $PB -c "Add :TrackpadRightClick integer 0" "$USER_PLIST" || true
  $U $PB -c "Set :TrackpadCornerSecondaryClick 2" "$USER_PLIST" 2>/dev/null || $U $PB -c "Add :TrackpadCornerSecondaryClick integer 2" "$USER_PLIST" || true
  $U $PB -c "Set :com.apple.trackpad.enableSecondaryClick true" "$BYHOST_PLIST" 2>/dev/null || $U $PB -c "Add :com.apple.trackpad.enableSecondaryClick bool true" "$BYHOST_PLIST" || true
  $U $PB -c "Set :com.apple.trackpad.trackpadCornerClickBehavior 1" "$BYHOST_PLIST" 2>/dev/null || $U $PB -c "Add :com.apple.trackpad.trackpadCornerClickBehavior integer 1" "$BYHOST_PLIST" || true

  # 3) Flush caches in the user’s GUI session so the change applies now
  /bin/launchctl asuser "$CONSOLE_UID" /usr/bin/killall cfprefsd  >/dev/null 2>&1 || true
  /bin/launchctl asuser "$CONSOLE_UID" /usr/bin/killall SystemUIServer >/dev/null 2>&1 || true

  # 4) Verification (expected: 0 / 2 / 1 / 1)
  echo "VERIFY:"
  $U /usr/bin/defaults read com.apple.AppleMultitouchTrackpad TrackpadRightClick || true
  $U /usr/bin/defaults read com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick || true
  $U /usr/bin/defaults -currentHost read NSGlobalDomain com.apple.trackpad.enableSecondaryClick || true
  $U /usr/bin/defaults -currentHost read NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior || true
}



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

INFO "Configuring trackpad (tap + secondary corner)..."
enable_tap_to_click
enable_secondary_click_bottom_right
track_change "Enabled tap-to-click"
track_change "Set secondary click to bottom-right corner"


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
