#!/usr/bin/env bash
# Non-interactive install of Xcode Command Line Tools (CLT) + Homebrew on Apple Silicon.
# Usage:
#   bash ./install_xcodeclt_and_homebrew.sh
set -euo pipefail

log(){ printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"; }
die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Apple Silicon + self-elevate
[[ "$(uname -m)" == "arm64" ]] || die "Apple Silicon (arm64) required."
if [[ "${EUID}" -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi

# Resolve invoking user and HOME
INVOKER="${SUDO_USER:-$USER}"
INV_HOME="$(eval echo ~"${INVOKER}")"
[[ -d "${INV_HOME}" ]] || die "Cannot resolve HOME for ${INVOKER}"
log "Running as root; target user=${INVOKER} HOME=${INV_HOME}"

# ---- CLT ----
have_clt(){ /usr/bin/xcode-select -p >/dev/null 2>&1 && pkgutil --pkg-info=com.apple.pkg.CLTools_Executables >/dev/null 2>&1; }
install_clt(){
  if have_clt; then log "CLT already installed."; return; fi
  log "Installing Xcode Command Line Tools (non-interactive)…"
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  label=""
  for _ in 1 2 3 4 5 6; do
    label="$(softwareupdate -l 2>/dev/null \
      | sed -n 's/.*Label: \(Command Line Tools for Xcode-[^,]*\).*/\1/p' \
      | sort -V | tail -n1 || true)"
    [[ -n "${label}" ]] && break
    label="$(softwareupdate -l 2>/dev/null \
      | grep -Eo 'Command Line Tools for Xcode-[0-9][0-9\.]*' \
      | sort -V | tail -n1 || true)"
    [[ -n "${label}" ]] && break
    sleep 5
  done
  [[ -n "${label}" ]] || { rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress; die "Could not discover CLT label from softwareupdate."; }
  log "Selected label: ${label}"
  softwareupdate -i "${label}" --verbose
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  /usr/bin/xcode-select --switch /Library/Developer/CommandLineTools
  log "CLT installed."
}

# ---- Homebrew ----
have_brew(){ [[ -x /opt/homebrew/bin/brew ]]; }
install_brew(){
  if have_brew; then
    log "Homebrew already installed at /opt/homebrew."
  else
    log "Installing Homebrew (non-interactive)…"
    mkdir -p /opt/homebrew
    chown -R "${INVOKER}":staff /opt/homebrew
    sudo -u "${INVOKER}" NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    log "Homebrew installed."
  fi

  # Wire zsh + bash for invoking user; idempotent
  for f in "${INV_HOME}/.zprofile" "${INV_HOME}/.zshrc" "${INV_HOME}/.bash_profile"; do
    grep -q '/opt/homebrew/bin/brew shellenv' "$f" 2>/dev/null || \
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$f"
    chown "${INVOKER}":staff "$f" 2>/dev/null || true
  done

  # Apply for current process as invoking user
  sudo -u "${INVOKER}" bash -lc 'eval "$(/opt/homebrew/bin/brew shellenv)"; brew analytics off >/dev/null 2>&1 || true; brew update'
  log "Homebrew ready."
}

install_clt
install_brew
log "Done."
