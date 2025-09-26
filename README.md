# Housekeeping (Apple Silicon)

## Create Sequoia bootable USB
1) Find disk id: `diskutil list` (e.g., disk4)
2) Run: `bash scripts/make_bootable_usb.sh disk4`

## Wipe & install (from USB, Recovery CLI)
See `scripts/wipe_and_install_from_usb.md`.

## First boot (minimal)
Run: `bash scripts/bootstrap_minimal.sh`
