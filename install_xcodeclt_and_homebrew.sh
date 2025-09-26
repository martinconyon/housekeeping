#!/usr/bin/env bash
# Installs Xcode Command Line Tools (CLT) and Homebrew non-interactively.
# Apple Silicon only. Run once, with sudo, on a fresh macOS.
# Usage:
#   sudo bash install_xcodeclt_and_homebrew.sh

set -euo pipefail

log() { printf '%s\n' "[$(date +'%H:%M:%S')] $*"; }

require_arm64() {
  [[ "$(uname -m)" == "arm64" ]] || { echo "ERROR: Apple Silicon (arm64) required."; exit 1; }
}

have_clt() {
  # Returns 0 if CLT present
  /usr/bin/xcode-select -p >/dev/null 2>&1 && pkgutil --pkg-info=com.apple.pkg.CLTools_Executables >/dev/null 2>&1
}

install_clt() {
  if have_clt; then
    log "Xcode Command Line Tools already installed."
    return
  fi
  log "Installing Xcode Command Line Tools (non-interactive)…"
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  # Find the latest "Command Line Tools for Xcode-*" label
  CLT_LABEL="$(softwareupdate -l 2>/dev/null | awk -F"[*] " '/\* Command Line Tools for Xcode-/{print $2}' | sort -V | tail -n1 || true)"
  if [[ -z "${CLT_LABEL}" ]]; then
    rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    echo "ERROR: Could not find a Command Line Tools label via softwareupdate."
    exit 2
  fi

  log "Selected CLT label: ${CLT_LABEL}"
  softwareupdate -i "${CLT_LABEL}" --verbose
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  # Point xcode-select at CLT
  /usr/bin/xcode-select --switch /Library/Developer/CommandLineTools
  log "CLT installed."
}

have_brew() {
  [[ -x /opt/homebrew/bin/brew ]]
}

install_brew() {
  if have_brew; then
    log "Homebrew already installed at /opt/homebrew."
  else
    log "Installing Homebrew (non-interactive)…"
    # Pre-create directories so the installer won't prompt for sudo
    mkdir -p /opt/homebrew
    chown -R "$(id -u)":"$(id -g)" /opt/homebrew

    # Run official installer without prompts
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    log "Homebrew installed."
  fi

  # Set up shell environment for current user
  if ! grep -q '/opt/homebrew/bin/brew shellenv' "${HOME}/.zprofile" 2>/dev/null; then
    log "Adding brew shellenv to ~/.zprofile"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "${HOME}/.zprofile"
  fi
  # Also apply to current shell (helpful if the script continues)
  eval "$(/opt/homebrew/bin/brew shellenv)"

  # Basic hygiene
  brew analytics off >/dev/null 2>&1 || true
  brew update
}

main() {
  require_arm64

  # Must run with sudo so softwareupdate and chown/mkdir are non-interactive
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: Run with sudo: sudo bash $(basename "$0")"
    exit 1
  fi

  # Work as the invoking user for files in $HOME
  export SUDO_USER="${SUDO_USER:-$USER}"
  export HOME="$(eval echo ~${SUDO_USER})"
  export USER="${SUDO_USER}"

  log "Starting install as user: ${USER} (HOME=${HOME})"

  install_clt
  install_brew

  log "Done. Open a new terminal, or run: eval \"\$($(command -v brew) shellenv)\""
}

main "$@"
