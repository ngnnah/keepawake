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

    /// The menu's "Last ping" line. Shared by the initial menu build and the
    /// in-place refresh so the two can't drift apart.
    public static func lastPingLine(_ result: String) -> String {
        "Last ping: \(result)"
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

    // MARK: - Menu-bar icon

    /// Background color of the status chip.
    public enum IconColor { case green, brown, purple, red }

    /// What the menu-bar icon should draw: a short character on a colored
    /// chip. The character alone identifies the state, so the icon is still
    /// readable if the colors are hard to tell apart.
    public struct IconSpec: Equatable {
        public let text: String
        public let color: IconColor
        public init(text: String, color: IconColor) {
            self.text = text
            self.color = color
        }
    }

    /// 2 green = both on            W brown = keep awake only
    /// L purple = keep-alive only   ✕ red   = nothing on
    ///
    /// W for aWake, L for aLive, 2 for both, ✕ for neither.
    public static func iconSpec(keepAwakeOn: Bool, vpnPingOn: Bool) -> IconSpec {
        switch (keepAwakeOn, vpnPingOn) {
        case (true, true):   return IconSpec(text: "2", color: .green)
        case (true, false):  return IconSpec(text: "W", color: .brown)
        case (false, true):  return IconSpec(text: "L", color: .purple)
        case (false, false): return IconSpec(text: "\u{2715}", color: .red)
        }
    }

    /// Menu header suffix, e.g. "KeepAwake — keep awake + VPN keep-alive".
    public static func statusSummary(keepAwakeOn: Bool, vpnPingOn: Bool) -> String {
        switch (keepAwakeOn, vpnPingOn) {
        case (true, true):   return "keep awake + VPN keep-alive"
        case (true, false):  return "keep awake"
        case (false, true):  return "VPN keep-alive"
        case (false, false): return "idle"
        }
    }

    /// Status-item tooltip: spells out both toggles for anyone who can't read
    /// the badge color.
    public static func statusTooltip(keepAwakeOn: Bool, vpnPingOn: Bool) -> String {
        func onOff(_ b: Bool) -> String { b ? "on" : "off" }
        return "Keep awake: \(onOff(keepAwakeOn)) \u{00B7} VPN keep-alive: \(onOff(vpnPingOn))"
    }

    // MARK: - "Everything on" menu item

    /// Checkbox state of the "Everything on" item: a dash when exactly one
    /// toggle is on, so the item doubles as a summary.
    public enum EverythingState { case on, off, mixed }

    public static func everythingState(keepAwakeOn: Bool, vpnPingOn: Bool) -> EverythingState {
        switch (keepAwakeOn, vpnPingOn) {
        case (true, true):   return .on
        case (false, false): return .off
        default:             return .mixed
        }
    }

    /// What clicking "Everything on" should set both toggles to: off only when
    /// everything is already on, so the item is never a no-op.
    public static func everythingTarget(keepAwakeOn: Bool, vpnPingOn: Bool) -> Bool {
        !(keepAwakeOn && vpnPingOn)
    }
}
