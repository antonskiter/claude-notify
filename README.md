# claude-notify

macOS CLI tool that sends native notifications. Clicking the notification activates VSCode. Built for use with Claude Code hooks.

## Requirements

- macOS Sequoia or later (arm64)
- Swift 6.2 or later

## Install

```sh
git clone https://github.com/antonskiter/claude-notify
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

Add to `~/.claude/settings.json`. This is a global config — every Claude Code session on your machine will use it.

The hook receives JSON on stdin with `message`, `cwd`, and other fields. This config extracts the message as the notification body and the project folder name as the title:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'read -r JSON; MSG=$(echo \"$JSON\" | jq -r .message); PROJ=$(echo \"$JSON\" | jq -r \".cwd | split(\\\"/\\\") | last\"); ~/bin/claude-notify \"$MSG\" --title \"$PROJ\"'"
          }
        ]
      }
    ]
  }
}
```

### When you'll get notified

The `Notification` hook fires whenever Claude Code needs your attention:

- **Task finished** — Claude completed a long coding session and is waiting for your next instruction
- **Permission needed** — Claude wants to run a tool and needs your approval
- **Question asked** — Claude is asking you a question and waiting for your answer
- **Auth completed** — a background authentication flow finished

The `"matcher": ""` catches all of these. To filter, set the matcher to match specific `notification_type` values: `permission_prompt`, `idle_prompt`, `elicitation_dialog`, or `auth_success`.

## How it works

`UNUserNotificationCenter` requires an `.app` bundle identity to send and receive notifications, so the tool is compiled into a minimal app bundle (`claude-notify.app`). A thin wrapper shell script in `~/bin/claude-notify` forwards all arguments to the binary inside the bundle.

The process stays alive after posting the notification to handle the user's response. It exits when the notification is clicked (and VSCode is activated), dismissed, or after a 10-minute safety timeout.

## First run

macOS will prompt for notification permission the first time `claude-notify` runs. Allow it to enable notifications.

## License

MIT
