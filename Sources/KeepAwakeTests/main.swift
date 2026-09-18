import Foundation
import KeepAwakeCore

// A tiny dependency-free test runner for KeepAwakeCore. Runs with just the
// Command Line Tools (XCTest requires full Xcode). Exits non-zero on failure
// so it gates CI. Invoke via `swift run KeepAwakeTests` or `make test`.

var failures = 0

func check(_ cond: Bool, _ msg: String) {
    if cond {
        print("  ok  — \(msg)")
    } else {
        failures += 1
        print("  FAIL — \(msg)")
    }
}

func eq(_ got: String, _ want: String, _ msg: String) {
    check(got == want, "\(msg) (got \"\(got)\", want \"\(want)\")")
}

func eq(_ got: Double, _ want: Double, _ msg: String) {
    check(got == want, "\(msg) (got \(got), want \(want))")
}

print("normalizeTarget")
eq(Core.normalizeTarget("example.com"), "https://example.com", "adds https when no scheme")
eq(Core.normalizeTarget("http://intranet.test"), "http://intranet.test", "keeps http scheme")
eq(Core.normalizeTarget("https://intranet.test"), "https://intranet.test", "keeps https scheme")
eq(Core.normalizeTarget("  example.com \n"), "https://example.com", "trims whitespace")
eq(Core.normalizeTarget(""), "", "empty stays empty")
eq(Core.normalizeTarget("   \t"), "", "whitespace-only stays empty")

print("resolveInterval")
eq(Core.resolveInterval(0), 60, "0 (unset) falls back to 60")
eq(Core.resolveInterval(-3), 60, "negative falls back to 60")
eq(Core.resolveInterval(30), 30, "positive kept")
eq(Core.resolveInterval(5), 5, "5 kept")

print("isAcceptableInterval")
check(!Core.isAcceptableInterval(4.9), "4.9 rejected (below 5s floor)")
check(Core.isAcceptableInterval(5), "5 accepted")
check(Core.isAcceptableInterval(120), "120 accepted")

print("formatPingResult")
eq(Core.formatPingResult(exitStatus: 0, httpCode: "200", at: "12:00:00"),
   "HTTP 200 @ 12:00:00", "success line")
eq(Core.formatPingResult(exitStatus: 7, httpCode: "000", at: "12:00:00"),
   "unreachable @ 12:00:00", "failure line")

print("loginPlist")
let path = "/Applications/KeepAwake.app/Contents/MacOS/KeepAwake"
let xml = Core.loginPlist(executablePath: path)
do {
    let obj = try PropertyListSerialization.propertyList(from: Data(xml.utf8), options: [], format: nil)
    if let dict = obj as? [String: Any] {
        check(dict["Label"] as? String == "com.nhat.keepawake", "Label is bundle id")
        check(dict["RunAtLoad"] as? Bool == true, "RunAtLoad is true")
        check(dict["LimitLoadToSessionType"] as? String == "Aqua", "session type is Aqua")
        check((dict["ProgramArguments"] as? [String]) == [path], "ProgramArguments is the exe path")
    } else {
        failures += 1
        print("  FAIL — plist did not parse to a dictionary")
    }
} catch {
    failures += 1
    print("  FAIL — plist is not valid XML: \(error)")
}

print("iconSpec")
// The character carries the state on its own, so the icon stays readable
// without relying on the background color.
let bothOn = Core.iconSpec(keepAwakeOn: true, vpnPingOn: true)
eq(bothOn.text, "2", "both on shows 2")
check(bothOn.color == .green, "both on is green")

let awakeOnly = Core.iconSpec(keepAwakeOn: true, vpnPingOn: false)
eq(awakeOnly.text, "W", "keep-awake only shows W")
check(awakeOnly.color == .brown, "keep-awake only is brown")

let vpnOnly = Core.iconSpec(keepAwakeOn: false, vpnPingOn: true)
eq(vpnOnly.text, "L", "VPN keep-alive only shows L")
check(vpnOnly.color == .purple, "VPN keep-alive only is purple")

let bothOff = Core.iconSpec(keepAwakeOn: false, vpnPingOn: false)
eq(bothOff.text, "\u{2715}", "nothing on shows an X mark")
check(bothOff.color == .red, "nothing on is red")

print("statusSummary")
eq(Core.statusSummary(keepAwakeOn: true, vpnPingOn: true), "keep awake + VPN keep-alive", "both on names both")
eq(Core.statusSummary(keepAwakeOn: true, vpnPingOn: false), "keep awake", "keep-awake only")
eq(Core.statusSummary(keepAwakeOn: false, vpnPingOn: true), "VPN keep-alive", "VPN keep-alive only")
eq(Core.statusSummary(keepAwakeOn: false, vpnPingOn: false), "idle", "neither is idle")

print("statusTooltip")
eq(Core.statusTooltip(keepAwakeOn: true, vpnPingOn: false),
   "Keep awake: on \u{00B7} VPN keep-alive: off", "spells out both toggles")
eq(Core.statusTooltip(keepAwakeOn: false, vpnPingOn: true),
   "Keep awake: off \u{00B7} VPN keep-alive: on", "each state tracks its own toggle")

print("everythingState")
check(Core.everythingState(keepAwakeOn: true, vpnPingOn: true) == .on, "both on is checked")
check(Core.everythingState(keepAwakeOn: false, vpnPingOn: false) == .off, "both off is unchecked")
check(Core.everythingState(keepAwakeOn: true, vpnPingOn: false) == .mixed, "keep-awake only is a dash")
check(Core.everythingState(keepAwakeOn: false, vpnPingOn: true) == .mixed, "VPN only is a dash")

print("everythingTarget")
check(!Core.everythingTarget(keepAwakeOn: true, vpnPingOn: true), "both on: clicking turns both off")
check(Core.everythingTarget(keepAwakeOn: false, vpnPingOn: false), "both off: clicking turns both on")
check(Core.everythingTarget(keepAwakeOn: true, vpnPingOn: false), "mixed: clicking turns both on")
check(Core.everythingTarget(keepAwakeOn: false, vpnPingOn: true), "mixed: clicking turns both on")


print("")
if failures == 0 {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("\(failures) TEST(S) FAILED")
    exit(1)
}
