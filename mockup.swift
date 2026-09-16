import AppKit

// Renders a clean mockup of the KeepAwake menu-bar dropdown for the README.
// (A mockup, not a live capture — so we never commit the user's real desktop.)
// Usage: mockup <output.png>

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: mockup <output.png>\n".data(using: .utf8)!)
    exit(2)
}
let out = CommandLine.arguments[1]

let W: CGFloat = 560, H: CGFloat = 460
let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()

// Desktop backdrop (soft gradient).
NSGradient(starting: NSColor(calibratedRed: 0.80, green: 0.84, blue: 0.91, alpha: 1),
           ending:   NSColor(calibratedRed: 0.90, green: 0.86, blue: 0.92, alpha: 1))?
    .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

func draw(_ s: String, at p: NSPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
    (s as NSString).draw(at: p, withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
    ])
}

let black = NSColor(calibratedWhite: 0.12, alpha: 1)
let gray  = NSColor(calibratedWhite: 0.55, alpha: 1)
let blue  = NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 1)

// Menu bar strip.
let barH: CGFloat = 26
NSColor(calibratedWhite: 0.97, alpha: 0.96).setFill()
NSRect(x: 0, y: H - barH, width: W, height: barH).fill()
NSColor(calibratedWhite: 0.78, alpha: 1).setFill()
NSRect(x: 0, y: H - barH - 0.5, width: W, height: 0.5).fill()
draw("9:41", at: NSPoint(x: W - 56, y: H - barH + 6), size: 13, color: black, weight: .medium)

// Highlighted status icon (menu is open).
let iconX: CGFloat = 330
blue.setFill()
NSBezierPath(roundedRect: NSRect(x: iconX - 6, y: H - barH + 2, width: 30, height: barH - 4),
             xRadius: 5, yRadius: 5).fill()
draw("☕️", at: NSPoint(x: iconX - 2, y: H - barH + 4), size: 15, color: .white)

// Dropdown panel.
let panelW: CGFloat = 260
let panelX: CGFloat = iconX - panelW + 44
let panelTop: CGFloat = H - barH - 6
let panelH: CGFloat = 240
let panelRect = NSRect(x: panelX, y: panelTop - panelH, width: panelW, height: panelH)
let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 10, yRadius: 10)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowBlurRadius = 18
shadow.shadowOffset = NSSize(width: 0, height: -6)
shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.28)
shadow.set()
NSColor(calibratedWhite: 0.99, alpha: 0.99).setFill()
panelPath.fill()
NSGraphicsContext.restoreGraphicsState()

NSColor(calibratedWhite: 0.80, alpha: 1).setStroke()
panelPath.lineWidth = 0.5
panelPath.stroke()

// Rows.
let leftPad: CGFloat = 14
let checkX = panelX + leftPad
let textX = panelX + leftPad + 20
var y = panelTop - 26

func row(_ checked: Bool, _ text: String, color: NSColor = NSColor(calibratedWhite: 0.12, alpha: 1)) {
    if checked { draw("✓", at: NSPoint(x: checkX, y: y), size: 13, color: blue, weight: .bold) }
    draw(text, at: NSPoint(x: textX, y: y), size: 13, color: color)
    y -= 27
}
func sep() {
    NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
    NSRect(x: panelX + 10, y: y + 12, width: panelW - 20, height: 1).fill()
    y -= 14
}

draw("KeepAwake — active", at: NSPoint(x: panelX + leftPad, y: y), size: 12, color: gray, weight: .semibold)
y -= 24
sep()
row(true, "Keep awake")
row(true, "VPN keep-alive")
draw("Last ping: HTTP 200 @ 9:41:03", at: NSPoint(x: textX, y: y), size: 11, color: gray)
y -= 27
sep()
row(false, "Set ping target…")
row(true, "Launch at login")
sep()
row(false, "Quit KeepAwake")

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render mockup\n".data(using: .utf8)!)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: out))
} catch {
    FileHandle.standardError.write("write failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
