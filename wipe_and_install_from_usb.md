# Wipe & Install (Apple Silicon, CLI in Recovery)

# 1) Identify internal disk (usually disk0)
diskutil list

# 2) Full erase (replace disk0 if different)
diskutil eraseDisk APFS "Macintosh HD" GPT disk0

# 3) Start installer from the USB (adjust names only if you changed them)
"/Volumes/Install macOS Sequoia/Install macOS Sequoia.app/Contents/Resources/startosinstall" \
  --volume "/Volumes/Macintosh HD" --agreetolicense --nointeraction
