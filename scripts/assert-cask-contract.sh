#!/usr/bin/env bash
# Closed-grammar contract for the ArtifactBridge Cask.
#
# The generator owns a narrow known output format, so this contract enforces
# the exact ordered line sequence of a valid Cask instead of permissively
# parsing Ruby. The file must byte-match the expected layout for its version,
# parameterized only by the version argument and the file's own single
# well-formed sha256 line. Consequences (all fail closed):
#   - required stanzas are direct children of exactly one outer
#     `cask "artifactbridge"` block in the pinned order (an on_arm/on_intel or
#     any nested wrapper inserts lines and fails);
#   - postflight/uninstall_preflight each carry exactly one system_command
#     with the version-correct path, exact argument sequence, and
#     must_succeed: true;
#   - comments, heredocs, multiline strings, interpolation tricks, unknown
#     blocks/statements, duplicates, reorderings, or extra/missing lines fail.
#
# The expected layout below is deliberately an independent copy of the
# contract requirements (bundle layout from the immutable published DMGs:
# tray-v0.5.25 = "ArtifactBridge Tray.app", tray-v0.5.26 = "ArtifactBridge.app";
# boundary constant independent from the generator). Generator/template
# divergence fails the repository contract tests. Cask content is never
# executed or evaluated.

set -euo pipefail

usage() {
  echo "usage: $0 <cask-file> <version>" >&2
  exit 2
}

cask="${1:-}"
version="${2:-}"
[[ -n "$cask" && -f "$cask" ]] || usage
[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || usage

fail() {
  echo "Cask contract violation in $cask (version $version): $1" >&2
  exit 1
}

boundary_major=0
boundary_minor=5
boundary_patch=26

IFS=. read -r major minor patch <<<"$version"
historical=1
if ((10#$major > boundary_major)) \
  || ((10#$major == boundary_major && 10#$minor > boundary_minor)) \
  || ((10#$major == boundary_major && 10#$minor == boundary_minor \
       && 10#$patch >= boundary_patch)); then
  historical=0
fi

if ((historical)); then
  app_bundle='ArtifactBridge Tray.app'
else
  app_bundle='ArtifactBridge.app'
fi

# exactly one well-formed sha256 line may exist anywhere in the file; its
# digest is the only free parameter of the expected layout
sha_line_count="$(grep -cE '^  sha256 "[0-9a-f]{64}"$' "$cask" || true)"
((sha_line_count == 1)) \
  || fail "expected exactly one well-formed sha256 line, found $sha_line_count"
sha256="$(sed -n 's/^  sha256 "\([0-9a-f]\{64\}\)"$/\1/p' "$cask")"

ownership=""
if ((historical)); then
  ownership=$'  auto_updates true\n'
fi

expected="$(mktemp)"
trap 'rm -f -- "$expected"' EXIT

cat >"$expected" <<EOF
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

if ! cmp -s "$expected" "$cask"; then
  {
    echo "Cask does not match the closed-grammar layout for version $version; differences (expected vs actual):"
    diff "$expected" "$cask" || true
  } >&2
  exit 1
fi
