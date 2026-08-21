#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <tray-v-version> <output-directory>" >&2
  exit 2
}

tag="${1:-}"
output="${2:-}"
[[ "$tag" =~ ^tray-v((0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*))$ ]] || usage
[[ -n "$output" && "$output" != "/" ]] || usage
version="${BASH_REMATCH[1]}"
major="${BASH_REMATCH[2]}"
minor="${BASH_REMATCH[3]}"
patch="${BASH_REMATCH[4]}"
if ((10#$major == 0 && 10#$minor < 5)) \
  || ((10#$major == 0 && 10#$minor == 5 && 10#$patch < 15)); then
  echo "version $version predates the Homebrew ownership contract" >&2
  exit 1
fi

mkdir -p "$output"
base="https://app.artifactbridge.com/tray/releases/download/$tag"
assets=(
  VERSION
  RELEASE-METADATA.json
  SHA256SUMS
  ArtifactBridge-Tray-macos-universal.dmg
)
for asset in "${assets[@]}"; do
  curl --fail --silent --show-error --location \
    --retry 12 --retry-all-errors --retry-delay 10 \
    "$base/$asset" \
    --output "$output/$asset"
done

actual_version="$(tr -d '\r\n' <"$output/VERSION")"
[[ "$actual_version" == "$version" ]] || {
  echo "VERSION does not match $tag" >&2
  exit 1
}

jq -e --arg version "$version" '
  .schema == 1 and
  .version == $version and
  (.build_sha | type == "string" and test("^[0-9a-fA-F]{40}$")) and
  (.release_date | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")) and
  .channel == "stable" and
  .packaging_format == "multi-platform" and
  .formats == ["appimage", "deb", "rpm", "macos-zip"] and
  any(.artifacts[];
    .platform == "macos" and
    .architecture == "universal" and
    .format == "macos-dmg" and
    .asset_name == "ArtifactBridge-Tray-macos-universal.dmg")
' "$output/RELEASE-METADATA.json" >/dev/null

digest_for() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

for asset in VERSION RELEASE-METADATA.json ArtifactBridge-Tray-macos-universal.dmg; do
  mapfile -t expected < <(
    awk -v wanted="$asset" '{ name=$2; sub(/^\*/, "", name); if (name == wanted) print $1 }' \
      "$output/SHA256SUMS"
  )
  [[ "${#expected[@]}" -eq 1 && "${expected[0]}" =~ ^[0-9a-f]{64}$ ]] || {
    echo "SHA256SUMS must contain exactly one valid digest for $asset" >&2
    exit 1
  }
  actual="$(digest_for "$output/$asset")"
  [[ "$actual" == "${expected[0]}" ]] || {
    echo "$asset does not match SHA256SUMS" >&2
    exit 1
  }
done

printf '%s\n' "$(digest_for "$output/ArtifactBridge-Tray-macos-universal.dmg")" \
  >"$output/DMG-SHA256"
echo "verified ArtifactBridge $version from $tag"
