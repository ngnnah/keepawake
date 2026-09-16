import AppKit
import Foundation

// KeepAwake — a menu-bar app that prevents sleep (via `caffeinate`) and
// periodically pings a host over the VPN to defeat idle timeouts.

final class AppDelegate: NSObject, NSApplicationDelegate {
    let defaults = UserDefaults.standard
    var statusItem: NSStatusItem!
    var caffeinate: Process?
    var pingTimer: Timer?
    var lastPing = "—"

    // MARK: - Persisted state

    var keepAwakeOn: Bool {
        get { defaults.object(forKey: "keepAwakeOn") == nil ? true : defaults.bool(forKey: "keepAwakeOn") }
        set { defaults.set(newValue, forKey: "keepAwakeOn") }
    }
    var vpnPingOn: Bool {
        get { defaults.object(forKey: "vpnPingOn") == nil ? true : defaults.bool(forKey: "vpnPingOn") }
        set { defaults.set(newValue, forKey: "vpnPingOn") }
    }
    var pingTarget: String {
        get { defaults.string(forKey: "pingTarget") ?? "https://example.com" }
        set { defaults.set(newValue, forKey: "pingTarget") }
    }
    var pingInterval: Double {
        get { let v = defaults.double(forKey: "pingIntervalSeconds"); return v > 0 ? v : 60 }
        set { defaults.set(newValue, forKey: "pingIntervalSeconds") }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        reapOrphanCaffeinate() // clean up any caffeinate left by a prior crash
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        rebuildMenu()
        if keepAwakeOn { startCaffeinate() }
        if vpnPingOn { startPingTimer() }
    }

    /// Kill any `caffeinate -dimu` left over from a previous crash. We are
    /// single-instance, so any such process is a stale orphan that would
    /// otherwise keep the Mac awake forever with no UI to stop it. Runs before
    /// we start our own caffeinate, so it never kills the live one.
    func reapOrphanCaffeinate() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        p.arguments = ["-f", "caffeinate -dimu"]
        try? p.run()
        p.waitUntilExit()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopCaffeinate()
    }

    // MARK: - Menu-bar icon

    func updateIcon() {
        let name = keepAwakeOn ? "cup.and.saucer.fill" : "cup.and.saucer"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "KeepAwake")
        img?.isTemplate = true // adapts to light/dark menu bar
        statusItem.button?.image = img
    }

    // MARK: - Menu

    func rebuildMenu() {
        let menu = NSMenu()

        let header = NSMenuItem(title: keepAwakeOn ? "KeepAwake — active" : "KeepAwake — idle",
                                action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let awake = NSMenuItem(title: "Keep awake", action: #selector(toggleKeepAwake), keyEquivalent: "")
        awake.target = self
        awake.state = keepAwakeOn ? .on : .off
        menu.addItem(awake)

        let ping = NSMenuItem(title: "VPN keep-alive", action: #selector(toggleVpnPing), keyEquivalent: "")
        ping.target = self
        ping.state = vpnPingOn ? .on : .off
        menu.addItem(ping)

        let last = NSMenuItem(title: "Last ping: \(lastPing)", action: nil, keyEquivalent: "")
        last.isEnabled = false
        menu.addItem(last)

        menu.addItem(.separator())

        let setTarget = NSMenuItem(title: "Set ping target…", action: #selector(setPingTarget), keyEquivalent: "")
        setTarget.target = self
        menu.addItem(setTarget)

        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = isLoginEnabled() ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit KeepAwake", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc func toggleKeepAwake() {
        keepAwakeOn.toggle()
        if keepAwakeOn { startCaffeinate() } else { stopCaffeinate() }
        updateIcon()
        rebuildMenu()
    }

    @objc func toggleVpnPing() {
        vpnPingOn.toggle()
        if vpnPingOn { startPingTimer() } else { stopPingTimer() }
        rebuildMenu()
    }

    @objc func setPingTarget() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "VPN keep-alive settings"
        alert.informativeText = "URL or host to ping over the VPN, and the interval in seconds."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let width: CGFloat = 300
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 92))

        let targetLabel = NSTextField(labelWithString: "Target URL or host:")
        targetLabel.frame = NSRect(x: 0, y: 70, width: width, height: 16)
        let targetField = NSTextField(frame: NSRect(x: 0, y: 46, width: width, height: 22))
        targetField.stringValue = pingTarget
        targetField.placeholderString = "https://example.com"

        let intervalLabel = NSTextField(labelWithString: "Interval (seconds, min 5):")
        intervalLabel.frame = NSRect(x: 0, y: 24, width: width, height: 16)
        let intervalField = NSTextField(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        intervalField.stringValue = String(Int(pingInterval))
        intervalField.placeholderString = "60"

        container.addSubview(targetLabel)
        container.addSubview(targetField)
        container.addSubview(intervalLabel)
        container.addSubview(intervalField)
        alert.accessoryView = container

        if alert.runModal() == .alertFirstButtonReturn {
            let t = targetField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { pingTarget = t }
            if let iv = Double(intervalField.stringValue), iv >= 5 { pingInterval = iv }
            if vpnPingOn { startPingTimer() } // restart with new interval / target
            rebuildMenu()
        }
    }

    @objc func toggleLogin() {
        setLoginEnabled(!isLoginEnabled())
        rebuildMenu()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - caffeinate

    func startCaffeinate() {
        guard caffeinate == nil else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        // -d display, -i idle (works on battery too), -m disk, -u declare user active
        p.arguments = ["-dimu"]
        do { try p.run(); caffeinate = p } catch { caffeinate = nil }
    }

    func stopCaffeinate() {
        caffeinate?.terminate()
        caffeinate = nil
    }

    // MARK: - VPN keep-alive ping

    func startPingTimer() {
        stopPingTimer()
        performPing()
        let t = Timer(timeInterval: pingInterval, target: self,
                      selector: #selector(fireTimer), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        pingTimer = t
    }

    func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    @objc func fireTimer() { performPing() }

    func performPing() {
        guard vpnPingOn else { return }
        let target = normalizedTarget()
        guard !target.isEmpty else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            p.arguments = ["-s", "-o", "/dev/null", "-m", "5", "-w", "%{http_code}", target]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()

            var result: String
            do {
                try p.run()
                p.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let code = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"
                result = p.terminationStatus == 0
                    ? "HTTP \(code) @ \(self.timeString())"
                    : "unreachable @ \(self.timeString())"
            } catch {
                result = "error @ \(self.timeString())"
            }

            DispatchQueue.main.async {
                self.lastPing = result
                self.rebuildMenu()
            }
        }
    }

    func normalizedTarget() -> String {
        var t = pingTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return t }
        if !t.contains("://") { t = "https://" + t }
        return t
    }

    func timeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    // MARK: - Launch at login (launchd LaunchAgent)

    func loginPlistURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.nhat.keepawake.plist")
    }

    func isLoginEnabled() -> Bool {
        FileManager.default.fileExists(atPath: loginPlistURL().path)
    }

    func setLoginEnabled(_ on: Bool) {
        let url = loginPlistURL()
        if on {
            let exe = Bundle.main.executableURL?.path
                ?? "/Applications/KeepAwake.app/Contents/MacOS/KeepAwake"
            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key><string>com.nhat.keepawake</string>
                <key>ProgramArguments</key>
                <array><string>\(exe)</string></array>
                <key>RunAtLoad</key><true/>
                <key>LimitLoadToSessionType</key><string>Aqua</string>
                <key>ProcessType</key><string>Interactive</string>
            </dict>
            </plist>
            """
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? plist.write(to: url, atomically: true, encoding: .utf8)
            // Loads on next login. Not bootstrapped now, so we never spawn a
            // second instance alongside the one the user is already running.
        } else {
            try? FileManager.default.removeItem(at: url)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["bootout", "gui/\(getuid())/com.nhat.keepawake"]
            try? task.run()
            task.waitUntilExit()
        }
    }
}

// MARK: - Entry point

// Single-instance guard: if launchd starts us at login while an instance is
// already running (or vice versa), the newcomer exits quietly.
let bundleID = Bundle.main.bundleIdentifier ?? "com.nhat.keepawake"
if NSWorkspace.shared.runningApplications.filter({ $0.bundleIdentifier == bundleID }).count > 1 {
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu-bar only, no Dock icon
app.run()
