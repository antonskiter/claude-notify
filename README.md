# claude-notify

macOS CLI tool that sends native notifications. Clicking the notification activates VSCode. Built for use with Claude Code hooks.

## Requirements

- macOS Sequoia or later (arm64)
- Swift 6.2 or later

## Install

```sh
git clone https://github.com/your-username/claude-notify
cd claude-notify
./build-and-install.sh
```

Installs the `.app` bundle and a wrapper script to `~/bin/`. Make sure `~/bin` is on your `PATH`.

## Usage

```sh
claude-notify "message" [--title "Title"] [--sound "Sound"]
```

- `--title` defaults to `Claude Code`
- `--sound` defaults to `Glass` (system sounds from `/System/Library/Sounds/`)

## Claude Code hook

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "claude-notify \"$CLAUDE_NOTIFICATION\""
          }
        ]
      }
    ]
  }
}
```

## How it works

`UNUserNotificationCenter` requires an `.app` bundle identity to send and receive notifications, so the tool is compiled into a minimal app bundle (`claude-notify.app`). A thin wrapper shell script in `~/bin/claude-notify` forwards all arguments to the binary inside the bundle.

The process stays alive after posting the notification to handle the user's response. It exits when the notification is clicked (and VSCode is activated), dismissed, or after a 10-minute safety timeout.

## First run

macOS will prompt for notification permission the first time `claude-notify` runs. Allow it to enable notifications.

## License

MIT
