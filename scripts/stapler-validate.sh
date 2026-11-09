#!/usr/bin/env bash
# Validate the stapled notarization ticket of an installed app.
#
# `xcrun stapler validate` asks Apple's CloudKit ticket service, and on hosted
# macOS runners that connection is sometimes dropped (NSURLErrorDomain -1005,
# "The network connection was lost.", stapler exit 68). Only that transport
# failure is retried, a bounded number of times. Any other failure, including
# a missing or invalid ticket, fails on the first attempt, and exhausting the
# retries fails with stapler's last exit code.
#
# Overrides for tests: XCRUN (the xcrun executable),
# STAPLER_VALIDATE_ATTEMPTS (default 5), STAPLER_VALIDATE_DELAY_SECONDS
# (default 10).

set -euo pipefail

app="${1:?usage: $0 <app-path>}"
xcrun="${XCRUN:-xcrun}"
attempts="${STAPLER_VALIDATE_ATTEMPTS:-5}"
delay="${STAPLER_VALIDATE_DELAY_SECONDS:-10}"

transport_failure() {
  local status="$1" output="$2"
  [[ "$status" -eq 68 ]] \
    && [[ "$output" == *NSURLErrorDomain* ]] \
    && [[ "$output" == *"Code=-1005"* || "$output" == *"The network connection was lost."* ]]
}

for ((attempt = 1; ; attempt++)); do
  status=0
  output="$("$xcrun" stapler validate "$app" 2>&1)" || status=$?
  printf '%s\n' "$output"
  if ((status == 0)); then
    exit 0
  fi
  if ! transport_failure "$status" "$output"; then
    echo "stapler validate failed (exit $status); not a transport failure, not retrying" >&2
    exit "$status"
  fi
  if ((attempt >= attempts)); then
    echo "stapler validate lost its connection on all $attempts attempts" >&2
    exit "$status"
  fi
  echo "stapler validate lost its connection (attempt $attempt of $attempts); retrying in ${delay}s" >&2
  sleep "$delay"
done
