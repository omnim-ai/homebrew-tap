#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <cask-file>" >&2
  exit 2
}

cask="${1:-}"
[[ -n "$cask" && -f "$cask" ]] || usage

app="ArtifactBridge.app"
canonical_cli='#{appdir}/ArtifactBridge.app/Contents/MacOS/artifactbridge'

fail() {
  echo "Cask contract violation in $cask: $1" >&2
  exit 1
}

require() {
  if ! grep -Fq "$1" "$cask"; then
    fail "missing required content: $1"
  fi
}

forbid() {
  if grep -Fq "$1" "$cask"; then
    fail "forbidden content: $1"
  fi
}

# canonical bundle in the app stanza
require "app \"$app\""

# Homebrew owns updates after installation; livecheck stays for discovery
forbid 'auto_updates'
require 'livecheck do'

# canonical staged CLI in the binary link, register, and unregister paths
require "binary \"$canonical_cli\","
require "system_command \"$canonical_cli\","
if grep 'Contents/MacOS/' "$cask" | grep -Fv "$canonical_cli" | grep -q .; then
  fail "non-canonical Contents/MacOS path present"
fi

# CLI link target
require 'target: "artifactbridge"'

# ownership registration and uninstall coherence
require '"installation"'
require '"register-homebrew-cask"'
require '"unregister-homebrew-cask"'
require '"--brew-prefix"'
require 'HOMEBREW_PREFIX'
require 'must_succeed: true'
require 'uninstall quit: "com.artifactbridge.tray"'

# platform scope
require 'depends_on :macos'

# no zap stanza
if grep -Eq '^[[:space:]]*zap([[:space:]]|$)' "$cask"; then
  fail "the ArtifactBridge Cask must not contain a zap stanza"
fi
