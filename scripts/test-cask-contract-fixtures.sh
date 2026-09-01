#!/usr/bin/env bash
# Negative fixtures for the ArtifactBridge Cask contract.
#
# Each mutation of a rendered Cask MUST fail scripts/assert-cask-contract.sh:
# commented-out or missing app/binary/postflight-register/uninstall_preflight-
# unregister behavior, duplicated stanzas, misplaced or malformed blocks,
# wrong bundle layout for the version, and wrong ownership marker.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
contract="$root/scripts/assert-cask-contract.sh"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT

placeholder=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
checked=0
failed=0

render() {
  local version="$1" out="$2"
  "$root/scripts/render-artifactbridge-cask.sh" "$version" "$placeholder" "$out"
}

expect_pass() {
  local name="$1" version="$2" file="$3"
  if "$contract" "$file" "$version" >/dev/null 2>&1; then
    checked=$((checked + 1))
  else
    echo "fixture '$name': expected PASS but the contract failed:" >&2
    "$contract" "$file" "$version" >&2 || true
    failed=$((failed + 1))
  fi
}

expect_fail() {
  local name="$1" version="$2" file="$3"
  if "$contract" "$file" "$version" >/dev/null 2>&1; then
    echo "fixture '$name': expected FAIL but the contract passed" >&2
    failed=$((failed + 1))
  else
    checked=$((checked + 1))
  fi
}

mutant() {
  # mutant <name> <base-version> <mutation> [<version-under-test>]
  local name="$1" base_version="$2" mutation="$3"
  local under_test="${4:-$base_version}"
  local base="$temporary/base-$name.rb" out="$temporary/mutant-$name.rb"
  render "$base_version" "$base"
  case "$mutation" in
    comment-sole-app)
      awk '{ if ($0 ~ /^  app "/) sub(/^/, "#"); print }' "$base" >"$out" ;;
    remove-app)
      awk '{ if ($0 !~ /^  app "/) print }' "$base" >"$out" ;;
    comment-binary)
      awk '{ if ($0 ~ /^  binary "/) sub(/^/, "#"); print }' "$base" >"$out" ;;
    remove-binary)
      awk '{ if ($0 !~ /^  binary "/) print }' "$base" >"$out" ;;
    comment-postflight-block)
      awk '
        /^  postflight do$/ { inblk = 1 }
        inblk { sub(/^/, "#") }
        inblk && /^# *end$/ { inblk = 0 }
        { print }
      ' "$base" >"$out" ;;
    remove-postflight-block)
      awk '
        /^  postflight do$/ { inblk = 1; next }
        inblk && /^  end$/ { inblk = 0; next }
        inblk { next }
        { print }
      ' "$base" >"$out" ;;
    comment-uninstall-preflight-block)
      awk '
        /^  uninstall_preflight do$/ { inblk = 1 }
        inblk { sub(/^/, "#") }
        inblk && /^# *end$/ { inblk = 0 }
        { print }
      ' "$base" >"$out" ;;
    remove-uninstall-preflight-block)
      awk '
        /^  uninstall_preflight do$/ { inblk = 1; next }
        inblk && /^  end$/ { inblk = 0; next }
        inblk { next }
        { print }
      ' "$base" >"$out" ;;
    drop-register-json)
      awk '
        /^  postflight do$/ { inblk = 1 }
        inblk && /^ +"--json",$/ { next }
        inblk && /^  end$/ { inblk = 0 }
        { print }
      ' "$base" >"$out" ;;
    drop-register-must-succeed)
      awk '
        /^  postflight do$/ { inblk = 1 }
        inblk { sub(/must_succeed: true/, "must_succeed: false") }
        inblk && /^  end$/ { inblk = 0 }
        { print }
      ' "$base" >"$out" ;;
    drop-unregister-must-succeed)
      awk '
        /^  uninstall_preflight do$/ { inblk = 1 }
        inblk { sub(/must_succeed: true/, "must_succeed: false") }
        inblk && /^  end$/ { inblk = 0 }
        { print }
      ' "$base" >"$out" ;;
    duplicate-app)
      awk '{ print } /^  app "/ { print }' "$base" >"$out" ;;
    duplicate-postflight)
      awk '{ print } /^  postflight do$/ { print "  postflight do" }' "$base" >"$out" ;;
    auto-updates-in-canonical)
      awk '{ print } /^  depends_on :macos$/ { print "  auto_updates true" }' "$base" >"$out" ;;
    auto-updates-missing-historical)
      awk '{ if ($0 == "  auto_updates true") next; print }' "$base" >"$out" ;;
    wrong-bundle-name)
      sed 's/^  app "ArtifactBridge.app"/  app "ArtifactBridge Tray.app"/' "$base" >"$out" ;;
    wrong-binary-path)
      sed 's|^  binary "#{appdir}/ArtifactBridge.app/Contents/MacOS/artifactbridge",|  binary "#{appdir}/Other.app/Contents/MacOS/artifactbridge",|' "$base" >"$out" ;;
    comment-uninstall-quit)
      awk '{ if ($0 ~ /^  uninstall quit:/) sub(/^/, "#"); print }' "$base" >"$out" ;;
    add-zap)
      awk '{ print } /^  uninstall quit:/ { print "  zap trash: [\"~/.artifactbridge\"]" }' "$base" >"$out" ;;
    comment-livecheck)
      awk '{ if ($0 == "  livecheck do") sub(/^/, "#"); print }' "$base" >"$out" ;;
    unclosed-block)
      awk '{ lines[NR] = $0 } END { for (i = 1; i < NR; i++) print lines[i] }' "$base" >"$out" ;;
    system-command-outside-blocks)
      awk '{ print } /^  depends_on :macos$/ { print "  system_command \"/bin/true\"," }' "$base" >"$out" ;;
    swapped-register-command)
      sed 's/"register-homebrew-cask"/"unregister-homebrew-cask"/' "$base" >"$out" ;;
    wrap-app-on_arm)
      awk '/^  app "/ { print "  on_arm do"; print; print "  end"; next } { print }' "$base" >"$out" ;;
    wrap-app-on_intel)
      awk '/^  app "/ { print "  on_intel do"; print; print "  end"; next } { print }' "$base" >"$out" ;;
    wrap-binary-on_arm)
      awk '
        /^  binary "/ { print "  on_arm do"; print; pend = 1; next }
        pend { print; pend = 0; print "  end"; next }
        { print }
      ' "$base" >"$out" ;;
    wrap-postflight-on_arm)
      awk '
        /^  postflight do$/ { inpf = 1; print "  on_arm do"; print; next }
        inpf && /^  end$/ { inpf = 0; print; print "  end"; next }
        { print }
      ' "$base" >"$out" ;;
    wrap-uninstall-preflight-on_intel)
      awk '
        /^  uninstall_preflight do$/ { inup = 1; print "  on_intel do"; print; next }
        inup && /^  end$/ { inup = 0; print; print "  end"; next }
        { print }
      ' "$base" >"$out" ;;
    wrap-uninstall-quit-on_arm)
      awk '/^  uninstall quit:/ { print "  on_arm do"; print; print "  end"; next } { print }' "$base" >"$out" ;;
    heredoc-entire-cask)
      { printf 'cask "artifactbridge" do\n'
        printf '  text = <<~CASK\n'
        cat "$base"
        printf 'CASK\n'
        printf 'end\n'
      } >"$out" ;;
    qstring-entire-cask)
      { printf '%%q{\n'
        cat "$base"
        printf '}\n'
      } >"$out" ;;
    unknown-block-inserted)
      awk '{ print } /^  uninstall quit:/ { print "  hardware do"; print "    true"; print "  end" }' "$base" >"$out" ;;
    unknown-statement-inserted)
      awk '{ print } /^  uninstall quit:/ { print "  exec_utils \"/usr/bin/true\"" }' "$base" >"$out" ;;
    *)
      echo "unknown mutation: $mutation" >&2
      exit 2
      ;;
  esac
  expect_fail "$name ($base_version, $mutation)" "$under_test" "$out"
}

# sanity: unmutated renders pass on both sides of the boundary
render 1.2.3 "$temporary/base-canonical.rb"
expect_pass "canonical base render" 1.2.3 "$temporary/base-canonical.rb"
render 0.5.25 "$temporary/base-historical.rb"
expect_pass "historical base render" 0.5.25 "$temporary/base-historical.rb"

# commented or missing semantic blocks (canonical side)
for mutation in \
  comment-sole-app \
  remove-app \
  comment-binary \
  remove-binary \
  comment-postflight-block \
  remove-postflight-block \
  comment-uninstall-preflight-block \
  remove-uninstall-preflight-block \
  drop-register-json \
  drop-register-must-succeed \
  drop-unregister-must-succeed \
  duplicate-app \
  duplicate-postflight \
  auto-updates-in-canonical \
  wrong-bundle-name \
  wrong-binary-path \
  comment-uninstall-quit \
  add-zap \
  comment-livecheck \
  unclosed-block \
  system-command-outside-blocks \
  swapped-register-command \
  wrap-app-on_arm \
  wrap-app-on_intel \
  wrap-binary-on_arm \
  wrap-postflight-on_arm \
  wrap-uninstall-preflight-on_intel \
  wrap-uninstall-quit-on_arm \
  heredoc-entire-cask \
  qstring-entire-cask \
  unknown-block-inserted \
  unknown-statement-inserted; do
  mutant "canonical-$mutation" 1.2.3 "$mutation"
done

# the same semantic blocks on the historical side of the boundary
for mutation in \
  comment-sole-app \
  remove-app \
  comment-binary \
  remove-binary \
  comment-postflight-block \
  remove-postflight-block \
  comment-uninstall-preflight-block \
  remove-uninstall-preflight-block \
  auto-updates-missing-historical \
  comment-uninstall-quit \
  add-zap \
  comment-livecheck \
  unclosed-block \
  wrap-app-on_arm \
  wrap-postflight-on_arm \
  heredoc-entire-cask; do
  mutant "historical-$mutation" 0.5.25 "$mutation"
done

# a wrong version argument must fail even on an untouched Cask
expect_fail "version-argument-mismatch" 9.9.9 "$temporary/base-canonical.rb"

if ((failed > 0)); then
  echo "cask contract fixtures: $failed FAILED, $checked passed" >&2
  exit 1
fi
echo "cask contract fixtures: PASS ($checked fixtures)"
