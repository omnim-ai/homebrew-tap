#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT

placeholder=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

for script in "$root"/scripts/*.sh; do
  bash -n "$script"
done

render() {
  "$root/scripts/render-artifactbridge-cask.sh" "$1" "$2" "$3"
}

contract() {
  "$root/scripts/assert-cask-contract.sh" "$2" "$1"
}

sample="$temporary/artifactbridge.rb"
render 1.2.3 "$placeholder" "$sample"
contract 1.2.3 "$sample"

# release-layout boundary, from the immutable published DMGs:
# tray-v0.5.25 is the last release shipping "ArtifactBridge Tray.app",
# tray-v0.5.26 is the first shipping "ArtifactBridge.app"
render 0.5.25 "$placeholder" "$temporary/boundary-1.rb"
contract 0.5.25 "$temporary/boundary-1.rb"
render 0.5.26 "$placeholder" "$temporary/boundary.rb"
contract 0.5.26 "$temporary/boundary.rb"
render 0.5.27 "$placeholder" "$temporary/boundary-plus-1.rb"
contract 0.5.27 "$temporary/boundary-plus-1.rb"

# commented/missing/duplicated/misplaced structure must fail the contract
"$root/scripts/test-cask-contract-fixtures.sh"

if [[ -f "$root/Casks/artifactbridge.rb" ]]; then
  version="$(sed -n 's/^  version "\([0-9.]*\)"$/\1/p' "$root/Casks/artifactbridge.rb")"
  sha256="$(sed -n 's/^  sha256 "\([0-9a-f]\{64\}\)"$/\1/p' "$root/Casks/artifactbridge.rb")"
  if [[ -z "$version" || -z "$sha256" ]]; then
    echo "Casks/artifactbridge.rb does not expose a version and sha256" >&2
    exit 1
  fi
  contract "$version" "$root/Casks/artifactbridge.rb"

  # the checked-in Cask must be exactly what the generator emits for its own
  # version and digest, so a repository dispatch can never regenerate a
  # broken contract
  regenerated="$temporary/regenerated.rb"
  render "$version" "$sha256" "$regenerated"
  if ! cmp -s "$regenerated" "$root/Casks/artifactbridge.rb"; then
    echo "Casks/artifactbridge.rb does not match the generator output" >&2
    exit 1
  fi
fi

# syntax gates (ruby is preinstalled on the CI runners)
ruby -c "$sample" >/dev/null
for workflow in "$root"/.github/workflows/*.yml; do
  ruby -e 'require "yaml"; YAML.parse_file(ARGV.fetch(0)) or abort "invalid YAML"' "$workflow"
done
if [[ -f "$root/Casks/artifactbridge.rb" ]]; then
  ruby -c "$root/Casks/artifactbridge.rb" >/dev/null
fi

echo "tap repository contract: PASS"
