#!/usr/bin/env bash
# Minimal first-boot setup; run in a new user session after install.
set -euo pipefail

# Command Line Tools (idempotent; may show a dialog)
xcode-select --install 2>/dev/null || true

# Homebrew (Apple Silicon)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew update
echo "Minimal bootstrap done."
