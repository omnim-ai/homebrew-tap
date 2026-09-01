#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <version> <sha256> [output]" >&2
  exit 2
}

version="${1:-}"
sha256="${2:-}"
output="${3:-Casks/artifactbridge.rb}"

[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || usage
major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"
[[ "$sha256" =~ ^[0-9a-f]{64}$ ]] || usage
if ((10#$major == 0 && 10#$minor < 5)) \
  || ((10#$major == 0 && 10#$minor == 5 && 10#$patch < 15)); then
  echo "version $version predates the Homebrew ownership contract" >&2
  exit 1
fi

# Release-layout boundary from the immutable published DMGs: tray-v0.5.25 is
# the last release shipping "ArtifactBridge Tray.app" (with the application-
# owned update marker); tray-v0.5.26 is the first shipping the canonical
# "ArtifactBridge.app", after which Homebrew owns updates.
canonical=0
if ((10#$major > 0)) \
  || ((10#$major == 0 && 10#$minor > 5)) \
  || ((10#$major == 0 && 10#$minor == 5 && 10#$patch >= 26)); then
  canonical=1
fi
app_bundle="ArtifactBridge.app"
ownership=""
if ((canonical == 0)); then
  app_bundle="ArtifactBridge Tray.app"
  ownership=$'  auto_updates true\n'
fi

mkdir -p "$(dirname "$output")"
temporary="$(mktemp "${output}.tmp.XXXXXX")"
trap 'rm -f -- "$temporary"' EXIT

cat >"$temporary" <<EOF
cask "artifactbridge" do
  version "$version"
  sha256 "$sha256"

  url "https://app.artifactbridge.com/tray/releases/download/tray-v#{version}/ArtifactBridge-Tray-macos-universal.dmg"
  name "ArtifactBridge"
  desc "Share governed documents with coding agents"
  homepage "https://artifactbridge.com/"

  livecheck do
    url "https://app.artifactbridge.com/tray/releases/latest/download/VERSION"
    strategy :page_match do |page|
      page.scan(/^\\s*(\\d+(?:\\.\\d+){2})\\s*$/).flatten
    end
  end

${ownership}  depends_on :macos

  app "$app_bundle"
  binary "#{appdir}/$app_bundle/Contents/MacOS/artifactbridge",
         target: "artifactbridge"

  postflight do
    system_command "#{appdir}/$app_bundle/Contents/MacOS/artifactbridge",
                   args:         [
                     "installation",
                     "register-homebrew-cask",
                     "--brew-prefix",
                     HOMEBREW_PREFIX,
                     "--json",
                   ],
                   must_succeed: true
  end

  uninstall_preflight do
    system_command "#{appdir}/$app_bundle/Contents/MacOS/artifactbridge",
                   args:         [
                     "installation",
                     "unregister-homebrew-cask",
                     "--brew-prefix",
                     HOMEBREW_PREFIX,
                     "--json",
                   ],
                   must_succeed: true
  end

  uninstall quit: "com.artifactbridge.tray"
end
EOF

chmod 0644 "$temporary"
mv "$temporary" "$output"
trap - EXIT
