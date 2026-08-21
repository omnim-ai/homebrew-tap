#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT

for script in "$root"/scripts/*.sh; do
  bash -n "$script"
done

sample="$temporary/artifactbridge.rb"
"$root/scripts/render-artifactbridge-cask.sh" \
  1.2.3 \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  "$sample"
ruby -c "$sample" >/dev/null

grep -Fq 'auto_updates true' "$sample"
grep -Fq 'depends_on :macos' "$sample"
grep -Fq 'app "ArtifactBridge Tray.app"' "$sample"
grep -Fq 'binary "#{appdir}/ArtifactBridge Tray.app/Contents/MacOS/artifactbridge"' "$sample"
grep -Fq 'register-homebrew-cask' "$sample"
grep -Fq 'unregister-homebrew-cask' "$sample"
grep -Fq 'uninstall quit: "com.artifactbridge.tray"' "$sample"
if grep -Eq '^[[:space:]]*zap([[:space:]]|$)' "$sample"; then
  echo "the ArtifactBridge Cask must not contain a zap stanza" >&2
  exit 1
fi

for workflow in "$root"/.github/workflows/*.yml; do
  ruby -e 'require "yaml"; YAML.parse_file(ARGV.fetch(0)) or abort "invalid YAML"' "$workflow"
done

if [[ -f "$root/Casks/artifactbridge.rb" ]]; then
  ruby -c "$root/Casks/artifactbridge.rb" >/dev/null
  grep -Fq 'auto_updates true' "$root/Casks/artifactbridge.rb"
  ! grep -Eq '^[[:space:]]*zap([[:space:]]|$)' "$root/Casks/artifactbridge.rb"
fi

echo "tap repository contract: PASS"
