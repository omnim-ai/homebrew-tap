#!/usr/bin/env bash
# Tests for scripts/stapler-validate.sh with a fake xcrun that plays back a
# scripted sequence of exit codes, one per call.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validate="$root/scripts/stapler-validate.sh"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT

fake="$temporary/xcrun"
cat >"$fake" <<'FAKE'
#!/usr/bin/env bash
# $FAKE_SCRIPT holds one outcome per line: ok, transport, transport-text,
# exit68-other, exit68-other-url, or invalid. $FAKE_CALLS counts calls.
set -euo pipefail
[[ "$1 $2" == "stapler validate" ]] || { echo "unexpected: $*" >&2; exit 99; }
calls=$(( $(cat "$FAKE_CALLS") + 1 ))
echo "$calls" >"$FAKE_CALLS"
outcome="$(sed -n "${calls}p" "$FAKE_SCRIPT")"
case "$outcome" in
  ok) echo "The validate action worked!"; exit 0 ;;
  transport)
    echo 'error is Error Domain=NSURLErrorDomain Code=-1005 "The network connection was lost."'
    echo "The validate action failed! Error 68."; exit 68 ;;
  transport-text)
    echo 'Error Domain=NSURLErrorDomain NSLocalizedDescription=The network connection was lost.'
    echo "The validate action failed! Error 68."; exit 68 ;;
  exit68-other)
    echo "CloudKit's response is inconsistent with expections: (null)"
    echo "The validate action failed! Error 68."; exit 68 ;;
  exit68-other-url)
    echo 'error is Error Domain=NSURLErrorDomain Code=-1202 "The certificate for this server is invalid."'
    echo "The validate action failed! Error 68."; exit 68 ;;
  invalid) echo "$3 does not have a ticket stapled to it."; exit 65 ;;
  *) echo "fake xcrun: no outcome for call $calls" >&2; exit 98 ;;
esac
FAKE
chmod +x "$fake"

failed=0
run_case() {
  local name="$1" expected_status="$2" expected_calls="$3"
  shift 3
  printf '%s\n' "$@" >"$temporary/script"
  echo 0 >"$temporary/calls"
  local status=0
  FAKE_SCRIPT="$temporary/script" FAKE_CALLS="$temporary/calls" \
    XCRUN="$fake" STAPLER_VALIDATE_ATTEMPTS=3 STAPLER_VALIDATE_DELAY_SECONDS=0 \
    "$validate" /Applications/Example.app >/dev/null 2>&1 || status=$?
  local calls
  calls="$(cat "$temporary/calls")"
  if [[ "$status" != "$expected_status" || "$calls" != "$expected_calls" ]]; then
    echo "case '$name': expected exit $expected_status after $expected_calls call(s), got exit $status after $calls" >&2
    failed=$((failed + 1))
  fi
}

run_case "passes first time"                     0  1 ok
run_case "retries a dropped connection"          0  3 transport transport-text ok
run_case "fails closed when retries run out"     68 3 transport transport transport
run_case "does not retry a missing ticket"       65 1 invalid ok
run_case "does not retry exit 68 without -1005"  68 1 exit68-other ok
run_case "does not retry other URL errors"       68 1 exit68-other-url ok
run_case "missing ticket after a retry fails"    65 2 transport invalid ok

if ((failed > 0)); then
  echo "stapler-validate tests: $failed failed" >&2
  exit 1
fi
echo "stapler-validate tests: PASS"
