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
"$root/scripts/assert-cask-contract.sh" "$sample"

for workflow in "$root"/.github/workflows/*.yml; do
  ruby -e 'require "yaml"; YAML.parse_file(ARGV.fetch(0)) or abort "invalid YAML"' "$workflow"
done

if [[ -f "$root/Casks/artifactbridge.rb" ]]; then
  ruby -c "$root/Casks/artifactbridge.rb" >/dev/null
  "$root/scripts/assert-cask-contract.sh" "$root/Casks/artifactbridge.rb"

  # the checked-in Cask must be exactly what the generator emits for its own
  # version and digest, so a repository dispatch can never regenerate a
  # broken contract
  version="$(sed -n 's/^  version "\([0-9.]*\)"$/\1/p' "$root/Casks/artifactbridge.rb")"
  sha256="$(sed -n 's/^  sha256 "\([0-9a-f]\{64\}\)"$/\1/p' "$root/Casks/artifactbridge.rb")"
  if [[ -z "$version" || -z "$sha256" ]]; then
    echo "Casks/artifactbridge.rb does not expose a version and sha256" >&2
    exit 1
  fi
  regenerated="$temporary/regenerated.rb"
  "$root/scripts/render-artifactbridge-cask.sh" "$version" "$sha256" "$regenerated"
  if ! cmp -s "$regenerated" "$root/Casks/artifactbridge.rb"; then
    echo "Casks/artifactbridge.rb does not match the generator output" >&2
    exit 1
  fi
fi

echo "tap repository contract: PASS"
