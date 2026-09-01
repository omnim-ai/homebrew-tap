#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "usage: $0 <version>" >&2
  exit 2
}

app="/Applications/ArtifactBridge.app"
# The bundle name follows the immutable release layout: tray-v0.5.25 is the
# last release shipping "ArtifactBridge Tray.app", tray-v0.5.26 is the first
# shipping "ArtifactBridge.app".
IFS=. read -r major minor patch <<<"$version"
if ((10#$major == 0 && 10#$minor == 5 && 10#$patch < 26)) \
  || ((10#$major == 0 && 10#$minor < 5)); then
  app="/Applications/ArtifactBridge Tray.app"
fi
cli="$(brew --prefix)/bin/artifactbridge"
record="$HOME/.artifactbridge/installation.json"

codesign --verify --deep --strict "$app"
spctl --assess --verbose=2 --type execute "$app"
xcrun stapler validate "$app"
[[ "$(defaults read "$app/Contents/Info" CFBundleIdentifier)" == "com.artifactbridge.tray" ]]
[[ "$(defaults read "$app/Contents/Info" CFBundleShortVersionString)" == "$version" ]]
[[ "$(defaults read "$app/Contents/Info" CFBundleVersion)" == "$version" ]]

for executable in "$app/Contents/MacOS/artifactbridge" "$app/Contents/MacOS/artifactbridge-tray"; do
  [[ -x "$executable" ]]
  arches="$(lipo -archs "$executable")"
  [[ " $arches " == *" arm64 "* && " $arches " == *" x86_64 "* ]]
done

[[ -L "$cli" ]]
[[ "$(realpath "$cli")" == "$app/Contents/MacOS/artifactbridge" ]]
identity="$("$cli" version --json)"
[[ "$(jq -r '.version' <<<"$identity")" == "$version" ]]
[[ "$(jq -r '.installation_owner' <<<"$identity")" == "macos-homebrew" ]]

[[ -f "$record" ]]
jq -e --arg version "$version" --arg prefix "$(brew --prefix)" '
  .schema == 1 and
  .owner == "macos-homebrew" and
  .version == $version and
  .homebrew.prefix == $prefix and
  .homebrew.brew_executable == ($prefix + "/bin/brew") and
  .homebrew.binary_link == ($prefix + "/bin/artifactbridge") and
  .homebrew.tap == "omnim-ai/tap" and
  .homebrew.cask == "artifactbridge"
' "$record" >/dev/null

[[ ! -e "$HOME/.local/bin/artifactbridge" ]]
sentinel="$HOME/.artifactbridge/homebrew-ci-sentinel"
printf '%s\n' preserve >"$sentinel"
brew uninstall --cask artifactbridge
[[ ! -e "$app" && ! -e "$cli" ]]
[[ -f "$sentinel" && "$(cat "$sentinel")" == "preserve" ]]
[[ ! -e "$record" ]]

echo "installed Cask contract: PASS"
