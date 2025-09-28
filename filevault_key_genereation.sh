#!/bin/bash
set -euo pipefail

# ===== Logging =====
info(){ echo "[INFO]  $*"; }
ok(){ echo "[OK]    $*"; }
warn(){ echo "[WARN]  $*"; }
die(){ echo "[ERR]   $*"; exit 1; }

# ===== Preconditions =====
# Must be run on macOS with sudo (you will be prompted for your password)
[[ "$(uname -s)" == "Darwin" ]] || die "This script is for macOS."
if [[ $EUID -ne 0 ]]; then
  echo "[INFO]  Re-running with sudo..."
  exec sudo /bin/bash "$0" "$@"
fi

CONSOLE_USER="$(stat -f%Su /dev/console)"
DESKTOP="/Users/$CONSOLE_USER/Desktop"
REC="$DESKTOP/FileVault_Recovery_Key.txt"

info "Console user: $CONSOLE_USER"
mkdir -p "$DESKTOP" || true
chown "$CONSOLE_USER:staff" "$DESKTOP" || true

# ===== Check FileVault state =====
FV_STATUS="$(fdesetup status 2>/dev/null || true)"
echo "$FV_STATUS" | grep -q "FileVault is On" || {
  warn "FileVault is not ON yet."
  warn "If you just ran a deferred enable, log out and log back in once, then run this script again."
  exit 1
}

# ===== Generate / rotate PERSONAL recovery key =====
info "Generating a personal recovery key (Apple will prompt for your account password)..."
# This always requires the SecureToken user's password by design.
if fdesetup changerecovery -personal | tee "$REC" >/dev/null; then
  chown "$CONSOLE_USER:staff" "$REC" 2>/dev/null || true
  chmod 600 "$REC" 2>/dev/null || true
  ok "Recovery key saved to: $REC"
  info "Store this securely (password manager / print & safe)."
else
  die "Failed to generate recovery key."
fi
