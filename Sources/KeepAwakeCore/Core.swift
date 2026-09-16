import Foundation

/// Pure logic for KeepAwake, kept free of AppKit so it can be unit-tested
/// without a running app or window server.
public enum Core {
    /// The launchd label / bundle identifier used across the app.
    public static let bundleID = "com.nhat.keepawake"

    /// Normalize a user-entered ping target: trim whitespace; an empty value
    /// stays empty; add `https://` when no scheme is present.
    public static func normalizeTarget(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "" }
        return t.contains("://") ? t : "https://" + t
    }

    /// Resolve a stored ping interval: a non-positive (unset) value falls back
    /// to 60 seconds.
    public static func resolveInterval(_ raw: Double) -> Double {
        raw > 0 ? raw : 60
    }

    /// Whether a user-entered interval is acceptable to store (>= 5s floor).
    public static func isAcceptableInterval(_ raw: Double) -> Bool {
        raw >= 5
    }

    /// Human-readable ping-result line for the menu.
    public static func formatPingResult(exitStatus: Int32, httpCode: String, at time: String) -> String {
        exitStatus == 0 ? "HTTP \(httpCode) @ \(time)" : "unreachable @ \(time)"
    }

    /// The launchd LaunchAgent plist that relaunches the app at login.
    public static func loginPlist(executablePath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(bundleID)</string>
            <key>ProgramArguments</key>
            <array><string>\(executablePath)</string></array>
            <key>RunAtLoad</key><true/>
            <key>LimitLoadToSessionType</key><string>Aqua</string>
            <key>ProcessType</key><string>Interactive</string>
        </dict>
        </plist>
        """
    }
}
