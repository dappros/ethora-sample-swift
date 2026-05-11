# Maestro flows for `ethora-sample-swift`

End-to-end smoke tests that drive the SDKPlayground app on an iOS
Simulator (or a real device) against an Ethora server. Layer 2 of
the SDK testing strategy — see [`ethora-sdk-swift` README → Testing](https://github.com/dappros/ethora-sdk-swift/blob/main/README.md#testing)
for the split with hermetic XCTest unit tests.

## Cross-platform parity

The flow YAMLs here mirror the Android sample's flows
(`ethora-sample-android/.maestro/flows/`) one-for-one, with the
same numbering and intent. They resolve UI nodes by accessibility
identifier — the same string IDs Compose's `testTag(...)` uses on
Android — so a single flow exercises the same intent on either
platform.

iOS-specific differences from the Android equivalents:
- `appId: com.ethora.SDKPlayground` (Android uses `com.ethora`)
- Tab labels are `"Setup"`, `"Chat"`, `"Logs"` in title-case
  (Android uses `"SETUP"`, `"CHAT"`, `"LOGS"` in the segmented
  control)
- The system search bar (iOS `.searchable`) renders differently
  from Android's RoomListView search; flow `17-search-rooms`
  resolves it via SwiftUI's default search affordance, not via
  the `rooms_search_input` ID

Otherwise the YAMLs are byte-for-byte aligned where they can be.

## Repo layout

```
.maestro/
├── README.md         (you are here)
├── config.yaml       project-level Maestro config
├── assets/           binary fixtures (test images etc.)
│   └── test-image.png   8×8 PNG used by 06-attach-file
├── fixtures/         shared test data (do not commit real credentials)
│   └── test-users.yaml
├── scripts/          helpers invoked by flows or by CI before flows
│   ├── sendAsBob.js     Maestro JS helper — POSTs a message as bob
│   │                    via REST, used by 05-receive-text
│   └── sendPushIntent.sh
│                        adb-equivalent for iOS via xcrun simctl
│                        push, invoked by CI BEFORE 08-push-deep-link
└── flows/
    ├── 01-login-email.yaml
    ├── 02-login-jwt.yaml
    ├── 03-list-rooms.yaml
    ├── 04-send-text.yaml
    ├── 05-receive-text.yaml      uses scripts/sendAsBob.js
    ├── 06-attach-file.yaml       uses assets/test-image.png seeded
    │                              into the simulator's Photos library
    │                              by CI
    ├── 07-reconnect-airplane.yaml drives reconnect via the Setup
    │                              tab's Disconnect button (no shell
    │                              dependency)
    ├── 08-push-deep-link.yaml    CI runs sendPushIntent.sh first
    ├── 09-logout-relogin.yaml
    ├── 10-switch-app.yaml
    ├── 11-login-wrong-password.yaml
    ├── 13-message-edit.yaml
    ├── 14-message-delete.yaml
    ├── 15-message-reaction.yaml
    ├── 16-create-room.yaml
    ├── 17-search-rooms.yaml
    ├── 18-multi-message-rapid.yaml
    ├── 19-room-info.yaml
    └── 20-offline-pending-resend.yaml
```

(Flow 12 reserved for typing-indicator — needs a `sendAsBob`-style
helper for XMPP composing-state.)

## Running locally

1. Install Maestro: `brew install maestro` (or `curl -fsSL https://get.maestro.mobile.dev | bash`).
2. Boot a Simulator and install the app:

   ```bash
   ./generate_xcodeproj.sh    # if SDKPlayground.xcodeproj is stale
   xcodebuild -project SDKPlayground.xcodeproj \
     -scheme SDKPlayground \
     -destination 'platform=iOS Simulator,name=iPhone 15' \
     -configuration Debug \
     -derivedDataPath build/
   xcrun simctl install booted \
     build/Build/Products/Debug-iphonesimulator/SDKPlayground.app
   ```

3. Populate `SDKPlayground/PlaygroundSession.swift`'s defaults via
   `npx @ethora/setup` against your QA app — same flow as Android.
4. Run a single flow:

   ```bash
   maestro test .maestro/flows/01-login-email.yaml
   ```

   Or all flows:

   ```bash
   maestro test .maestro/flows
   ```

## Running in CI

`.github/workflows/maestro.yml` runs the suite on every push, PR,
and SDK release tag on a macOS runner with an iOS Simulator.

## Coverage table

What each flow proves end-to-end against `chat-qa.ethora.com`.
Identical to the Android sample's coverage table — the same 19
flows, the same regression classes, same expected assertions.

| # | Flow | Asserts | Catches |
|---|------|---------|---------|
| 01 | `login-email` | Email + password → connected | Wrong app token, broken `/users/login-with-email` shape |
| 02 | `login-jwt` | Custom JWT → `/users/client` accepts | `TOKEN_WRONG_TYPE`, missing JWTLoginConfig wiring |
| 03 | `list-rooms` | After login, room list renders | `GET /chats/my` regression, unread-count desync |
| 04 | `send-text` | Send round-trips and renders the bubble | XMPP BIND-result match, ConnectionStore stuck CONNECTING |
| 05 | `receive-text` | Bob's REST-sent message arrives via XMPP | MAM subscription missing, XMPPClient duplication |
| 06 | `attach-file` | Pick from gallery → upload → image bubble | Upload 401 (wrong auth), MIME rejection |
| 07 | `reconnect-airplane` | Disconnect → Connect → history survives | XMPP client not torn down, banner stuck |
| 08 | `push-deep-link` | Synthetic notification → right room | Intent extras lost, room JID URL-decoded wrong |
| 09 | `logout-relogin` | Full logout → re-login same user → state isolated | Persisted state leaking across sessions |
| 10 | `switch-app` | App A → App B in-process | Store not flushed, XMPP client persisting wrong-app JID |
| 11 | `login-wrong-password` | 401 surfaces as error, form remains editable | Error suppressed, retry loop |
| 13 | `message-edit` | Long-press → Edit → bubble updates | edit prop not flowing, optimistic-update reconciliation |
| 14 | `message-delete` | Long-press → Delete → bubble gone or tombstoned | Delete RPC silently failing, MAM still returning deleted |
| 15 | `message-reaction` | Long-press → React → emoji + count visible | Reaction not stored, picker missing presets |
| 16 | `create-room` | "+" → Create dialog → new room visible + writable | Create-room RPC silent failure, JID collision |
| 17 | `search-rooms` | RoomListView SearchBar narrows + restores list | Predicate not case-insensitive, list not re-rendering |
| 18 | `multi-message-rapid` | 5 back-to-back sends all visible in order | Out-of-order ack reorder, optimistic UI dropping bubbles |
| 19 | `room-info` | Room info → participants + leave control | `GET /chats/:jid/details` regression |
| 20 | `offline-pending-resend` | Disconnect → send → reconnect → message lands | Send dropped silently, sendFailed never clearing |

## Why some helpers live outside the flow YAML

Maestro's JS runtime can drive HTTP (`http.post(...)`) but can't
shell out — anything that needs `xcrun simctl` (synthetic push
intents, pushing files into the Photos library, network simulation)
is invoked from the CI workflow before/after the flow runs. The
flow then asserts on the resulting state.

## Authoring a new flow

- Use accessibility-identifier anchors (`id: "chat_input"`) over
  text matching where possible — labels move under localization /
  copy edits, IDs don't.
- Keep each flow under ~30 lines. If you need more, split it.
- Pull credentials from `fixtures/` rather than inlining them.
- Always end with at least one `assertVisible` / `assertNotVisible`
  so a flow that silently no-ops fails loudly.

When a regression slips through Layer 1 unit tests, add a flow for
it in the same PR as the fix.
