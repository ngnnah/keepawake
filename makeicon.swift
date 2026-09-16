import AppKit

// Renders a 1024×1024 app-icon PNG (a coffee cup on a cream squircle).
// Usage: makeicon <output.png>

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: makeicon <output.png>\n".data(using: .utf8)!)
    exit(2)
}
let outPath = CommandLine.arguments[1]

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Cream rounded-rect background (macOS squircle-ish).
let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                      xRadius: 185, yRadius: 185)
NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.83, alpha: 1).setFill()
bg.fill()

// Centered coffee emoji.
let emoji = "☕️" as NSString
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 620)]
let strSize = emoji.size(withAttributes: attrs)
emoji.draw(at: NSPoint(x: (size - strSize.width) / 2, y: (size - strSize.height) / 2),
           withAttributes: attrs)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render icon\n".data(using: .utf8)!)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outPath))
} catch {
    FileHandle.standardError.write("write failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
