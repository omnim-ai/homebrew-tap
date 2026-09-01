#!/usr/bin/env bash
# Structural contract for the ArtifactBridge Cask.
#
# Strict and fail-closed: commented-out lines never satisfy a requirement,
# duplicate/missing stanzas fail, malformed nesting fails, system_command is
# only valid as exactly one register call inside exactly one postflight block
# and exactly one unregister call inside exactly one uninstall_preflight block
# with the exact argument sequence and must_succeed: true.
#
# The expected bundle layout is bound to the version against the immutable
# published DMGs: tray-v0.5.25 ships "ArtifactBridge Tray.app", tray-v0.5.26
# ships "ArtifactBridge.app" (each digest-verified against its SHA256SUMS).
# The boundary constant here is deliberately independent from the generator's
# copy; disagreement fails the repository contract tests.

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
  expected_app='ArtifactBridge Tray.app'
else
  expected_app='ArtifactBridge.app'
fi
expected_cli="#{appdir}/${expected_app}/Contents/MacOS/artifactbridge"

depth=0
app_count=0
binary_count=0
binary_pending=0
sc_open_count=0
sc_register_count=0
sc_unregister_count=0
sc_state=0
sc_step=0
sc_block=""
livecheck_count=0
depends_on_count=0
uninstall_quit_count=0
auto_updates_count=0
auto_updates_text=""
version_line_count=0
sha256_line_count=0
zap_count=0
postflight_count=0
uninstall_preflight_count=0
in_postflight=0
in_uninstall_preflight=0
postflight_depth=0
uninstall_preflight_depth=0
line_no=0

while IFS= read -r line || [[ -n "$line" ]]; do
  line_no=$((line_no + 1))
  line="${line%$'\r'}"

  # comments never satisfy anything
  if [[ "$line" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  if [[ -z "${line//[[:space:]]/}" ]]; then
    if ((sc_state == 1)); then
      fail "line $line_no: blank line inside system_command argument list"
    fi
    continue
  fi

  if ((binary_pending)); then
    if [[ "$line" =~ ^[[:space:]]*target:[[:space:]]*\"artifactbridge\"$ ]]; then
      binary_pending=0
      continue
    fi
    fail "line $line_no: binary stanza must declare target: \"artifactbridge\" on the next line"
  fi

  if ((sc_state == 1)); then
    sc_step=$((sc_step + 1))
    case "$sc_step" in
      1)
        [[ "$line" =~ ^[[:space:]]*args:[[:space:]]*\[$ ]] \
          || fail "line $line_no: expected 'args: [' opening the $sc_block command arguments"
        ;;
      2)
        [[ "$line" =~ ^[[:space:]]*\"installation\",$ ]] \
          || fail "line $line_no: expected '\"installation\",' in the $sc_block command arguments"
        ;;
      3)
        if [[ "$sc_block" == "postflight" ]]; then
          [[ "$line" =~ ^[[:space:]]*\"register-homebrew-cask\",$ ]] \
            || fail "line $line_no: postflight must run 'register-homebrew-cask'"
        else
          [[ "$line" =~ ^[[:space:]]*\"unregister-homebrew-cask\",$ ]] \
            || fail "line $line_no: uninstall_preflight must run 'unregister-homebrew-cask'"
        fi
        ;;
      4)
        [[ "$line" =~ ^[[:space:]]*\"--brew-prefix\",$ ]] \
          || fail "line $line_no: expected '\"--brew-prefix\",' in the $sc_block command arguments"
        ;;
      5)
        [[ "$line" =~ ^[[:space:]]*HOMEBREW_PREFIX,$ ]] \
          || fail "line $line_no: expected 'HOMEBREW_PREFIX,' in the $sc_block command arguments"
        ;;
      6)
        [[ "$line" =~ ^[[:space:]]*\"--json\",$ ]] \
          || fail "line $line_no: expected '\"--json\",' in the $sc_block command arguments"
        ;;
      7)
        [[ "$line" =~ ^[[:space:]]*\],$ ]] \
          || fail "line $line_no: expected '],' closing the $sc_block command arguments"
        ;;
      8)
        [[ "$line" =~ ^[[:space:]]*must_succeed:[[:space:]]*true$ ]] \
          || fail "line $line_no: the $sc_block command must end with 'must_succeed: true'"
        sc_state=0
        ;;
    esac
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]*end$ ]]; then
    depth=$((depth - 1))
    ((depth >= 0)) || fail "line $line_no: unbalanced 'end'"
    if ((in_postflight && depth < postflight_depth)); then
      in_postflight=0
    fi
    if ((in_uninstall_preflight && depth < uninstall_preflight_depth)); then
      in_uninstall_preflight=0
    fi
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]*postflight[[:space:]]+do$ ]]; then
    postflight_count=$((postflight_count + 1))
    ((postflight_count <= 1)) || fail "line $line_no: duplicate postflight block"
    depth=$((depth + 1))
    postflight_depth=$depth
    in_postflight=1
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]*uninstall_preflight[[:space:]]+do$ ]]; then
    uninstall_preflight_count=$((uninstall_preflight_count + 1))
    ((uninstall_preflight_count <= 1)) || fail "line $line_no: duplicate uninstall_preflight block"
    depth=$((depth + 1))
    uninstall_preflight_depth=$depth
    in_uninstall_preflight=1
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]*system_command[[:space:]]+\"(.+)\",$ ]]; then
    sc_open_count=$((sc_open_count + 1))
    if ((in_postflight)); then
      sc_block="postflight"
      sc_register_count=$((sc_register_count + 1))
    elif ((in_uninstall_preflight)); then
      sc_block="uninstall_preflight"
      sc_unregister_count=$((sc_unregister_count + 1))
    else
      fail "line $line_no: system_command outside postflight/uninstall_preflight"
    fi
    [[ "${BASH_REMATCH[1]}" == "$expected_cli" ]] \
      || fail "line $line_no: system_command must target ${expected_cli}"
    sc_state=1
    sc_step=0
    continue
  fi

  if ((in_postflight || in_uninstall_preflight)); then
    fail "line $line_no: unexpected content inside a registration block"
  fi

  if [[ "$line" =~ ^[[:space:]]+app[[:space:]]+\"(.+)\"$ ]]; then
    app_count=$((app_count + 1))
    [[ "${BASH_REMATCH[1]}" == "$expected_app" ]] \
      || fail "line $line_no: app stanza must be \"${expected_app}\" for version $version"
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]+binary[[:space:]]+\"(.+)\",$ ]]; then
    binary_count=$((binary_count + 1))
    ((binary_count <= 1)) || fail "line $line_no: duplicate binary stanza"
    [[ "${BASH_REMATCH[1]}" == "$expected_cli" ]] \
      || fail "line $line_no: binary stanza must link ${expected_cli} for version $version"
    binary_pending=1
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]+livecheck[[:space:]]+do$ ]]; then
    livecheck_count=$((livecheck_count + 1))
    depth=$((depth + 1))
    continue
  fi

  if [[ "$line" =~ [[:space:]]do[[:space:]]*$ || "$line" =~ [[:space:]]do[[:space:]]+\|[^|]*\|[[:space:]]*$ ]]; then
    depth=$((depth + 1))
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]+version[[:space:]]+\"([^\"]+)\"$ ]]; then
    version_line_count=$((version_line_count + 1))
    [[ "${BASH_REMATCH[1]}" == "$version" ]] \
      || fail "line $line_no: Cask version must be $version"
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]+sha256[[:space:]]+\"([0-9a-f]{64})\"$ ]]; then
    sha256_line_count=$((sha256_line_count + 1))
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]+depends_on[[:space:]]+:macos$ ]]; then
    depends_on_count=$((depends_on_count + 1))
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]+uninstall[[:space:]]+quit:[[:space:]]+\"com.artifactbridge.tray\"$ ]]; then
    uninstall_quit_count=$((uninstall_quit_count + 1))
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]+auto_updates ]]; then
    auto_updates_count=$((auto_updates_count + 1))
    trimmed="${line#"${line%%[![:space:]]*}"}"
    auto_updates_text="$trimmed"
    continue
  fi

  if [[ "$line" =~ ^[[:space:]]+zap([[:space:]]|$) ]]; then
    zap_count=$((zap_count + 1))
    fail "line $line_no: the ArtifactBridge Cask must not contain a zap stanza"
  fi
done <"$cask"

((depth == 0)) || fail "unbalanced do/end nesting (depth $depth at end of file)"
((sc_state == 0)) || fail "unterminated system_command argument list"
((in_postflight == 0 && in_uninstall_preflight == 0)) || fail "unterminated registration block"
((postflight_count == 1)) || fail "expected exactly one postflight block, found $postflight_count"
((uninstall_preflight_count == 1)) || fail "expected exactly one uninstall_preflight block, found $uninstall_preflight_count"
((sc_open_count == 2)) || fail "expected exactly two system_command calls, found $sc_open_count"
((sc_register_count == 1)) || fail "expected exactly one register-homebrew-cask system_command in postflight, found $sc_register_count"
((sc_unregister_count == 1)) || fail "expected exactly one unregister-homebrew-cask system_command in uninstall_preflight, found $sc_unregister_count"
((app_count == 1)) || fail "expected exactly one active app stanza, found $app_count"
((binary_count == 1)) || fail "expected exactly one active binary stanza, found $binary_count"
((livecheck_count == 1)) || fail "expected exactly one livecheck block, found $livecheck_count"
((depends_on_count == 1)) || fail "expected exactly one depends_on :macos stanza, found $depends_on_count"
((uninstall_quit_count == 1)) || fail "expected exactly one 'uninstall quit: \"com.artifactbridge.tray\"' stanza, found $uninstall_quit_count"
((version_line_count == 1)) || fail "expected exactly one version stanza, found $version_line_count"
((sha256_line_count == 1)) || fail "expected exactly one sha256 stanza, found $sha256_line_count"
((zap_count == 0)) || fail "found $zap_count zap stanzas"

if ((historical)); then
  ((auto_updates_count == 1)) || fail "historical version $version must declare its ownership marker exactly once, found $auto_updates_count"
  [[ "$auto_updates_text" == "auto_updates true" ]] \
    || fail "historical ownership marker must be 'auto_updates true', found '$auto_updates_text'"
else
  ((auto_updates_count == 0)) || fail "version $version must not declare auto_updates (Homebrew owns updates), found $auto_updates_count"
fi
