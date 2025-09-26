#!/usr/bin/env bash
# Usage: scripts/make_bootable_usb.sh <diskId> [VolumeName]
# Example: scripts/make_bootable_usb.sh disk4 InstallUSB
set -euo pipefail
DISK_ID="${1:?Missing disk id (e.g., disk4)}"
VOL_NAME="${2:-InstallUSB}"

diskutil eraseDisk HFS+ "${VOL_NAME}" GPT "${DISK_ID}"
sudo "/Applications/Install macOS Sequoia.app/Contents/Resources/createinstallmedia" \
  --volume "/Volumes/${VOL_NAME}" --nointeraction
diskutil eject "/Volumes/Install macOS Sequoia" || true
echo "Bootable USB created."
