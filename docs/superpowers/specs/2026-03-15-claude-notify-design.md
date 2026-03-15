# claude-notify Design Spec

## Overview

A macOS CLI tool that sends native notifications via `UNUserNotificationCenter`. When clicked, it activates VSCode. The process stays alive indefinitely until the notification is clicked or dismissed. A safety timeout of 10 minutes exits the process if no interaction occurs.

## CLI Interface

- Positional argument: message body (required)
- `--title`: notification title (default: "Claude Code")
- `--sound`: notification sound name without extension (default: "Glass") — references system sounds at `/System/Library/Sounds/`
- `--help`: print usage and exit

Usage: `claude-notify "your message here" --title "Custom Title" --sound "Ping"`

## Architecture

Single Swift file (`claude-notify.swift`) compiled with `swiftc`. The binary lives inside a minimal `.app` bundle so macOS recognizes it as a proper notification source.

### Bundle Structure

```text
~/bin/claude-notify.app/
  Contents/
    Info.plist
    MacOS/
      claude-notify     (compiled binary)
~/bin/claude-notify     (symlink → claude-notify.app/Contents/MacOS/claude-notify)
```

### Why a Bundle

`UNUserNotificationCenter` requires the process to have a bundle identifier. A bare binary without a bundle won't register as a notification source — notifications silently fail or appear under a generic source. The `.app` wrapper with `Info.plist` provides the identity.

## Info.plist

XML plist with proper types:

- `CFBundleIdentifier` (string): `com.claude.notify`
- `CFBundleName` (string): `Claude Notify`
- `CFBundleExecutable` (string): `claude-notify`
- `LSUIElement` (boolean): `true` (no dock icon — must be `<true/>` not `<string>true</string>`)

## Notification Flow

1. Parse CLI arguments (manual parsing of `CommandLine.arguments`)
2. Set self as `UNUserNotificationCenterDelegate`
3. Request notification authorization via `UNUserNotificationCenter.requestAuthorization`
4. **Inside the authorization completion handler** (gated on `granted == true`):
   a. Register a `UNNotificationCategory` with `.customDismissAction` option, assign a category identifier (e.g., `"claude-notify"`)
   b. Create `UNMutableNotificationContent` with title, body, sound, and `categoryIdentifier`
   c. Schedule with `UNNotificationRequest` (nil trigger = fire immediately)
5. Schedule a 10-minute safety timeout via `DispatchQueue.main.asyncAfter` that calls `exit(2)`
6. Start `NSApplication.shared.run()` to keep process alive with proper AppKit event loop

### Why NSApplication.shared.run() over CFRunLoopRun()

`UNUserNotificationCenter` delegate callbacks integrate more reliably with an `NSApplication` run loop. Using `NSApplication.shared.run()` ensures proper AppKit event system integration.

### Why .customDismissAction

By default, `UNNotificationDismissActionIdentifier` is NOT delivered to the delegate. A `UNNotificationCategory` must be registered with `.customDismissAction` in its options, and the notification content must reference that category via `categoryIdentifier`. Without this, dismiss events are silently swallowed and the process would hang forever.

## Delegate Handling

### Click (`UNNotificationDefaultActionIdentifier`)

Activate VSCode using the correct NSWorkspace API:

```swift
if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") {
    NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
}
```

Then `exit(0)`.

### Dismiss (`UNNotificationDismissActionIdentifier`)

`exit(0)`

### Foreground presentation (`willPresent`)

Return `.banner, .sound` so the notification displays even if the "app" is frontmost.

## Error Handling

- Authorization denied: print error to stderr, exit code 1
- Notification scheduling failure: print error to stderr, exit code 1
- VSCode not found on click: exit silently (best effort)
- Safety timeout (10 min): exit code 2

## Build Process

1. Compile: `swiftc claude-notify.swift -o claude-notify -framework UserNotifications -framework AppKit`
2. Create `.app` bundle structure at `~/bin/claude-notify.app/Contents/MacOS/`
3. Move binary into the bundle
4. Write `Info.plist` (proper XML plist with boolean types)
5. Create symlink: `~/bin/claude-notify → ~/bin/claude-notify.app/Contents/MacOS/claude-notify`

Note: The binary will be unsigned. On first run, macOS Gatekeeper may require the user to right-click and open, or run `xattr -cr ~/bin/claude-notify.app`.

## Hook Integration

Add to `~/.claude/settings.json` under the `"Notification"` hook event:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/bin/claude-notify 'Claude Code needs your attention'"
          }
        ]
      }
    ]
  }
}
```

## First Run

macOS will prompt the user to allow notifications for "Claude Notify". After approval, notifications work without further prompts.

## Constraints

- Pure Swift, no external dependencies
- No Xcode project — compile with `swiftc` directly
- Target: macOS Sequoia+ (arm64)
- Single binary (plus bundle wrapper)
- VSCode activation is best-effort (no specific window targeting)
