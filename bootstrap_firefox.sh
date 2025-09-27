#!/usr/bin/env bash
# Apple Silicon macOS; Homebrew already installed.
# Installs Firefox to ~/Applications, creates a deterministic profile
# (~/"Library/Application Support/Firefox/Profiles/bootstrap.default"),
# force-installs uBlock Origin + Privacy Badger + Multi-Account Containers,
# sets homepage=about:blank, sets DuckDuckGo as default search (system policy),
# and launches Firefox on THAT profile so add-ons appear on first run.

set -euo pipefail
log(){ printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"; }
die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Preconditions
[[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon required."
if ! command -v brew >/dev/null 2>&1; then
  [[ -x /opt/homebrew/bin/brew ]] || die "Homebrew not found."
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 0) Ensure Firefox not running
pkill -x "Firefox" >/dev/null 2>&1 || true

# 1) Install Firefox to ~/Applications (avoid TCC prompts)
export HOMEBREW_CASK_OPTS="--appdir=${HOME}/Applications"
mkdir -p "${HOME}/Applications"
log "Installing Firefox…"
brew install --cask firefox >/dev/null || brew upgrade --cask firefox >/dev/null

# Paths
FF_APP="${HOME}/Applications/Firefox.app"
[[ -d "$FF_APP" ]] || FF_APP="/Applications/Firefox.app"
[[ -d "$FF_APP" ]] || die "Firefox.app not found after install."
FF_BIN="${FF_APP}/Contents/MacOS/firefox"
[[ -x "$FF_BIN" ]] || die "Firefox binary not found."

FF_SUPPORT="${HOME}/Library/Application Support/Firefox"
PROFILES_DIR="${FF_SUPPORT}/Profiles"
PROFILE_DIR="${PROFILES_DIR}/bootstrap.default"
PROFILES_INI="${FF_SUPPORT}/profiles.ini"

# 2) Create deterministic profile and make it default (overwrite profiles.ini)
log "Creating deterministic Firefox profile…"
mkdir -p "${PROFILES_DIR}"
"$FF_BIN" --headless -CreateProfile "bootstrap ${PROFILE_DIR}" >/dev/null 2>&1 || true

cat > "${PROFILES_INI}" <<EOF
[General]
StartWithLastProfile=1

[Profile0]
Name=bootstrap
IsRelative=1
Path=Profiles/bootstrap.default
Default=1
EOF

[[ -d "${PROFILE_DIR}" ]] || die "Profile directory missing: ${PROFILE_DIR}"

# 3) Install signed XPIs into the profile (filename must equal add-on ID)
EXT_DIR="${PROFILE_DIR}/extensions"
mkdir -p "${EXT_DIR}"
log "Installing add-ons into: ${EXT_DIR}"
# uBlock Origin
curl -fsSL "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi" \
  -o "${EXT_DIR}/uBlock0@raymondhill.net.xpi"
# Privacy Badger
curl -fsSL "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi" \
  -o "${EXT_DIR}/jid1-MnnxcxisBPnSXQ@jetpack.xpi"
# Multi-Account Containers (ID: @testpilot-containers)
curl -fsSL "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi" \
  -o "${EXT_DIR}/@testpilot-containers.xpi"

# 4) Set homepage=about:blank and ensure extensions aren’t auto-disabled
USERJS="${PROFILE_DIR}/user.js"
tmp="$(mktemp)"; [[ -f "$USERJS" ]] && \
  grep -v -E '^(user_pref\("browser.startup.homepage"|user_pref\("browser.startup.page"|user_pref\("extensions.autoDisableScopes"|user_pref\("extensions.enabledScopes")' "$USERJS" > "$tmp" || :
mv -f "$tmp" "$USERJS" 2>/dev/null || true
{
  echo 'user_pref("browser.startup.homepage","about:blank");'
  echo 'user_pref("browser.startup.page",1);'
  echo 'user_pref("extensions.autoDisableScopes", 0);'
  echo 'user_pref("extensions.enabledScopes", 15);'
} >> "$USERJS"

# 5) System policy: set DuckDuckGo as default search (survives updates)
POL_DIR="/Library/Application Support/Mozilla/ManagedPolicies"
log "Setting DuckDuckGo as default search (system policy)…"
sudo mkdir -p "$POL_DIR"
sudo tee "${POL_DIR}/policies.json" >/dev/null <<'JSON'
{
  "policies": {
    "SearchEngines": { "Default": "DuckDuckGo" },
    "DontCheckDefaultBrowser": true
  }
}
JSON

# 6) First launch on THIS profile, then relaunch normally
log "Launching Firefox with target profile…"
"$FF_BIN" -profile "$PROFILE_DIR" -no-remote >/dev/null 2>&1 &

sleep 10
pkill -x "Firefox" >/dev/null 2>&1 || true

log "Relaunching Firefox normally…"
open -na "$FF_APP"

log "Done. Check about:addons (uBlock Origin, Privacy Badger, Multi-Account Containers) and about:policies (Active)."
