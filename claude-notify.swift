import AppKit
import UserNotifications

// MARK: - CLI Argument Parsing

func printUsage() {
    let name = (CommandLine.arguments[0] as NSString).lastPathComponent
    print("Usage: \(name) <message> [--title <title>] [--sound <sound>] [--help]")
    print("")
    print("Arguments:")
    print("  <message>        Notification body text (required)")
    print("  --title <title>  Notification title (default: \"Claude Code\")")
    print("  --sound <sound>  Sound name without extension (default: \"Glass\")")
    print("                   References system sounds at /System/Library/Sounds/")
    print("  --help           Print this usage and exit")
}

struct CLIArgs {
    var message: String
    var title: String = "Claude Code"
    var sound: String = "Glass"
}

func parseArgs() -> CLIArgs {
    var args = CommandLine.arguments.dropFirst() // drop executable name
    var message: String? = nil
    var title = "Claude Code"
    var sound = "Glass"

    while !args.isEmpty {
        let arg = args.removeFirst()

        switch arg {
        case "--help", "-h":
            printUsage()
            exit(0)

        case "--title":
            guard let value = args.first else {
                fputs("Error: --title requires a value\n", stderr)
                exit(1)
            }
            args.removeFirst()
            title = value

        case "--sound":
            guard let value = args.first else {
                fputs("Error: --sound requires a value\n", stderr)
                exit(1)
            }
            args.removeFirst()
            sound = value

        default:
            if arg.hasPrefix("--") {
                fputs("Error: Unknown flag \(arg)\n", stderr)
                printUsage()
                exit(1)
            }
            if message != nil {
                fputs("Error: Unexpected positional argument '\(arg)'\n", stderr)
                printUsage()
                exit(1)
            }
            message = arg
        }
    }

    guard let body = message else {
        fputs("Error: A message body is required\n", stderr)
        printUsage()
        exit(1)
    }

    return CLIArgs(message: body, title: title, sound: sound)
}

// MARK: - Notification Delegate

// Marked @MainActor so all delegate callbacks run on the main actor,
// satisfying Swift 6 Sendable / concurrency requirements.
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let categoryIdentifier = "claude-notify"

    // Show banner + play sound even when the "app" is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle click and dismiss actions.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User clicked the notification — activate VSCode.
            if let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.microsoft.VSCode"
            ) {
                NSWorkspace.shared.openApplication(
                    at: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            }
            exit(0)

        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification.
            exit(0)

        default:
            exit(0)
        }
    }
}

// MARK: - Entry Point

let cliArgs = parseArgs()

// Set up the delegate before touching UNUserNotificationCenter.
let delegate = NotificationDelegate()
let center = UNUserNotificationCenter.current()
center.delegate = delegate

// Request authorization. All notification work happens inside the completion handler.
center.requestAuthorization(options: [.alert, .sound]) { granted, error in
    if let error = error {
        fputs("Error requesting notification authorization: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

    guard granted else {
        fputs("Error: Notification authorization denied by user\n", stderr)
        exit(1)
    }

    // Register a category with .customDismissAction so the dismiss action
    // is delivered to the delegate. Without this, dismiss events are silently
    // swallowed and the process would hang until the safety timeout.
    let category = UNNotificationCategory(
        identifier: NotificationDelegate.categoryIdentifier,
        actions: [],
        intentIdentifiers: [],
        options: [.customDismissAction]
    )
    center.setNotificationCategories([category])

    // Build the notification content.
    let content = UNMutableNotificationContent()
    content.title = cliArgs.title
    content.body = cliArgs.message
    content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: cliArgs.sound))
    content.categoryIdentifier = NotificationDelegate.categoryIdentifier

    // Schedule immediately (nil trigger = fire right away).
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )

    center.add(request) { error in
        if let error = error {
            fputs("Error scheduling notification: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

// Safety timeout: exit after 10 minutes if no user interaction occurs.
DispatchQueue.main.asyncAfter(deadline: .now() + 600) {
    exit(2)
}

// Keep the process alive with a proper AppKit event loop.
// NSApplication.shared.run() integrates more reliably with
// UNUserNotificationCenter delegate callbacks than CFRunLoopRun().
NSApplication.shared.run()
