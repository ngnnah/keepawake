import AppKit
import KeepAwakeCore

/// Draws the menu-bar status icon: the coffee mug, with a small colored chip
/// badged onto its corner naming the current state. Split out of `main.swift`
/// because it's the one piece of drawing code here, and keeping it separate
/// lets it be rendered and eyeballed on its own.
enum StatusIcon {
    /// The mug is the app's identity, so it stays the same in every state —
    /// the chip carries all of the status.
    private static let mugSymbol = "cup.and.saucer.fill"

    private static let textAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 8, weight: .bold),
        .foregroundColor: NSColor.white,
    ]

    /// One chip size for every state, sized to the widest character (`W`), so
    /// the menu bar doesn't shift its other icons when a toggle flips.
    private static let chipSize: NSSize = {
        let widest = [(true, true), (true, false), (false, true), (false, false)]
            .map { Core.iconSpec(keepAwakeOn: $0.0, vpnPingOn: $0.1).text }
            .map { ($0 as NSString).size(withAttributes: textAttrs).width }
            .max() ?? 0
        let height: CGFloat = 11
        return NSSize(width: max(height, ceil(widest) + 5), height: height)
    }()

    /// AppKit color for each chip. Lives here, not in Core, so Core stays
    /// AppKit-free and headlessly testable.
    static func chipNSColor(_ color: Core.IconColor) -> NSColor {
        switch color {
        case .green:  return .systemGreen
        case .brown:  return .systemBrown
        case .purple: return .systemPurple
        case .red:    return .systemRed
        }
    }

    /// The mug with its state chip badged onto the bottom-right.
    ///
    /// The chip is colored, so this can't be a template image — AppKit would
    /// flatten it to a single menu-bar tint. The mug is therefore drawn in a
    /// dynamic color resolved *inside* the drawing handler, which AppKit runs
    /// with the menu bar's current appearance, so it still follows light/dark.
    static func image(_ spec: Core.IconSpec, menuOpen: Bool) -> NSImage? {
        guard let mug = NSImage(systemSymbolName: mugSymbol, accessibilityDescription: "KeepAwake")?
                .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
        else { return nil }

        let size = NSSize(width: mug.size.width + 5, height: mug.size.height + 2)
        let mugRect = NSRect(x: 0, y: size.height - mug.size.height,
                             width: mug.size.width, height: mug.size.height)
        let chipRect = NSRect(x: size.width - chipSize.width, y: 0,
                              width: chipSize.width, height: chipSize.height)
        let fill = chipNSColor(spec.color)
        let text = spec.text as NSString
        let textSize = text.size(withAttributes: textAttrs)

        let image = NSImage(size: size, flipped: false) { _ in
            // Inside a status button AppKit makes the menu bar's appearance
            // current, so this dynamic color resolves to the right variant.
            let glyph: NSColor = menuOpen ? .selectedMenuItemTextColor : .labelColor
            mug.draw(in: mugRect, from: .zero, operation: .sourceOver, fraction: 1)
            glyph.set()
            mugRect.fill(using: .sourceAtop)

            // Knock a hole in the mug behind the chip so the two don't tangle.
            // Erasing to transparent (rather than painting a fake backdrop)
            // keeps it correct on any menu-bar background.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSColor.black.setFill()
            NSBezierPath(roundedRect: chipRect.insetBy(dx: -1.5, dy: -1.5),
                         xRadius: 4.5, yRadius: 4.5).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver

            fill.setFill()
            NSBezierPath(roundedRect: chipRect, xRadius: 3, yRadius: 3).fill()
            text.draw(at: NSPoint(x: chipRect.minX + (chipRect.width - textSize.width) / 2,
                                  y: chipRect.minY + (chipRect.height - textSize.height) / 2),
                      withAttributes: textAttrs)
            return true
        }
        image.isTemplate = false // the chip carries its own color
        return image
    }
}
