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

print("")
if failures == 0 {
    print("ALL TESTS PASSED")
    exit(0)
} else {
    print("\(failures) TEST(S) FAILED")
    exit(1)
}
