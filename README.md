# SDK Playground

An interactive iOS app **inside the SDK repository** for quickly validating `XMPPChatCore` + `XMPPChatUI`: environment setup (Base URL, app token, XMPP), auth via **JWT** (`/users/client`) or **email/password** (`/users/login-with-email`), then chat and a **Logs** tab (XMPP events from `NotificationCenter`).

> The name **SDKPlayground** is intentionally not `Testing` to avoid confusion with unit/UI tests.

## Build

From `Examples/SDKPlayground`:

```bash
./generate_xcodeproj.sh
open SDKPlayground.xcodeproj
```

**Important:** do not run only `xcodegen generate` without the next step. XcodeGen alone does not fully link the local SPM package, and Xcode may show *Missing package product 'XMPPChatCore' / 'XMPPChatUI'*. The `generate_xcodeproj.sh` script runs `xcodegen` and then `fix_local_package_refs.py`.

Select the **SDKPlayground** scheme and a simulator. The local package is connected with `path: ../..` (the `ethora-sdk-swift` root).

The project **must** be opened from `ethora-sdk-swift/Examples/SDKPlayground/`. If you copy only the `SDKPlayground` folder into another repo without the package root, the relative `../..` path to `Package.swift` will break. In that case, update the local package path in Xcode.

## Tabs

| Tab | Purpose |
|--------|------------|
| **Setup** | API/XMPP parameters, auth mode, **Connect** / **Disconnect** |
| **Chat** | `ChatWrapperView` after successful Connect |
| **Logs** | Event stream (including `XMPPConnectionStatusChanged`, `XMPPClientDidConnect`, etc.) |

The form is persisted in `UserDefaults` (including password, for local debugging only).

## Regenerate Project

After editing `project.yml`:

```bash
./generate_xcodeproj.sh
```

## Using SDK Playground Outside This Repository

If you run `SDKPlayground` in another repository/workspace, you need to move not only the playground project itself, but also the SDK sources it depends on.

### What to Copy from the Main Repository

Minimum required:
- `Package.swift`
- `Sources/XMPPChatCore`
- `Sources/XMPPChatUI`
- `Examples/SDKPlayground` (entire folder)

Also recommended:
- `Package.resolved` (to keep dependency versions deterministic)

### Why This Is Required

- `SDKPlayground` imports `XMPPChatCore` and `XMPPChatUI`.
- These modules are built from the local Swift Package (`Package.swift` + `Sources/...`).
- `XMPPChatCore` depends on `Starscream`, and that dependency is declared in `Package.swift`.

### Recommended External Workspace Layout

```text
your-workspace/
  Package.swift
  Sources/
    XMPPChatCore/
    XMPPChatUI/
  Examples/
    SDKPlayground/
```

### Run

From `Examples/SDKPlayground`:

```bash
./generate_xcodeproj.sh
open SDKPlayground.xcodeproj
```

### Important Local Package Path Note

`SDKPlayground` is configured to use a local Swift Package at `../..` (from `Examples/SDKPlayground` to the root containing `Package.swift`).  
If your external workspace has a different directory depth, update the local package path in Xcode (or in `project.yml`).

## Testing

This repo hosts the **Layer 2** end-to-end test flows for the Ethora
iOS SDK. Layer 1 (hermetic XCTest unit tests) lives in
[`ethora-sdk-swift`](https://github.com/dappros/ethora-sdk-swift#testing)
alongside the source it exercises.

### What runs here

[`.maestro/`](.maestro/) holds 19 [Maestro](https://maestro.mobile.dev/)
YAML flows that drive the SDKPlayground app on an iOS Simulator
against `chat-qa.ethora.com`. The same 19 flow YAMLs (with the
same numbering and intent) drive the Android sample app on Android
emulators — see
[`ethora-sample-android/.maestro/`](https://github.com/dappros/ethora-sample-android/tree/main/.maestro).

They run on the sample's CI ([`.github/workflows/maestro.yml`](.github/workflows/maestro.yml))
on every push, PR, and SDK release tag — the gate that catches
integration regressions like config drift, preset URL breakage, or
cross-platform feature parity gaps.

| # | Flow | Covers |
|---|------|--------|
| 01 | login-email | Happy-path email/password login → connected |
| 02 | login-jwt | Bring-your-own-auth client-flow JWT |
| 03 | list-rooms | Room list renders post-login with unread counts |
| 04 | send-text | XMPP send round-trip |
| 05 | receive-text | MAM delivery from a second user |
| 06 | attach-file | Upload + image bubble |
| 07 | reconnect-airplane | Disconnect → reconnect → history survives |
| 08 | push-deep-link | APNs payload → correct room |
| 09 | logout-relogin | State isolation across sessions |
| 10 | switch-app | Multi-tenant app switcher |
| 11 | login-wrong-password | Negative path surfaces error to UI |
| 13 | message-edit | Long-press → Edit → bubble updates |
| 14 | message-delete | Long-press → Delete → tombstone or removal |
| 15 | message-reaction | Long-press → React → emoji + count visible |
| 16 | create-room | "+" → name → room visible + writable |
| 17 | search-rooms | `.searchable` filter narrows + restores list |
| 18 | multi-message-rapid | 5 rapid sends, ordering preserved |
| 19 | room-info | Room info modal → participants + leave control |
| 20 | offline-pending-resend | Send while disconnected → message lands after reconnect |

(Flow 12 reserved for typing-indicator — needs a `sendAsBob`-style
helper for XMPP composing-state.)

Full coverage table with per-flow assertions and the regression
classes each catches:
[`.maestro/README.md`](.maestro/README.md#coverage-table).

### Adding a new flow

Each flow is ~10–30 lines of YAML; copy
[`flows/01-login-email.yaml`](.maestro/flows/01-login-email.yaml)
as a template. See [`.maestro/README.md`](.maestro/README.md) for
authoring conventions and how to run flows locally.
