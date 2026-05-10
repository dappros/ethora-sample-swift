#!/usr/bin/env bash
# Synthesises a push-notification tap for the SDKPlayground app on a
# booted iOS Simulator, mimicking what an APNs payload with a
# notification_jid extra would do. Used by `flows/08-push-deep-link.yaml`.
#
# Maestro's JS runtime can't shell out, so this script runs from the
# CI workflow (`.github/workflows/maestro.yml`) **before** Maestro
# runs the flow — the flow then asserts on the launched state.
#
# Required args / env:
#   $1  room JID, e.g. abc123_def456@conference.xmpp.chat-qa.ethora.com
#
# Optional env:
#   SIMCTL_DEVICE  device UDID (when more than one simulator booted).
#                  Defaults to "booted".

set -euo pipefail

JID="${1:-${JID:-}}"
if [[ -z "$JID" ]]; then
  echo "sendPushIntent.sh: missing room JID. Usage: $0 <room-jid>" >&2
  exit 1
fi

DEVICE="${SIMCTL_DEVICE:-booted}"
BUNDLE_ID="com.ethora.SDKPlayground"

# Compose a minimal APNs payload. The SDK reads the room JID from
# the custom `notification_jid` claim — keep this in sync with
# PushNotificationManager.swift's payload parsing.
PAYLOAD_FILE="$(mktemp -t ethora_push_payload.XXXXXX).json"
trap 'rm -f "$PAYLOAD_FILE"' EXIT

cat > "$PAYLOAD_FILE" <<EOF
{
  "Simulator Target Bundle": "$BUNDLE_ID",
  "aps": {
    "alert": {
      "title": "Ethora",
      "body": "New message"
    }
  },
  "notification_jid": "$JID"
}
EOF

xcrun simctl push "$DEVICE" "$BUNDLE_ID" "$PAYLOAD_FILE"
