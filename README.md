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
