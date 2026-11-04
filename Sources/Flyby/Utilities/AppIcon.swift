import AppKit
import SwiftUI

/// The three app icon variations: "Vácuo" (default, dark), "Lua" (light) and "Ignição" (accent).
enum AppIconStyle: String, CaseIterable, Identifiable {
    case vacuo
    case lua
    case ignicao

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vacuo: return "Vácuo"
        case .lua: return "Lua"
        case .ignicao: return "Ignição"
        }
    }

    var subtitle: String {
        switch self {
        case .vacuo: return "Default"
        case .lua: return "Light"
        case .ignicao: return "Accent"
        }
    }
}

enum IconPalette {
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.17)      // #FF6B2C
    static let ink = Color(red: 0.043, green: 0.055, blue: 0.078)     // #0B0E14
    static let paper = Color(red: 0.902, green: 0.910, blue: 0.933)   // #E6E8EE
    static let night = Color(red: 0.071, green: 0.094, blue: 0.149)   // #121826
    static let star = Color(red: 0.541, green: 0.576, blue: 0.651)    // #8A93A6
}

/// Stroke weights from the design: thicker strokes keep the glyph legible at small sizes.
enum GlyphWeight {
    case regular   // large icons
    case medium    // ~64pt
    case heavy     // small sizes and the menu bar

    fileprivate var line: CGFloat {
        switch self {
        case .regular: return 7
        case .medium: return 10
        case .heavy: return 11
        }
    }

    fileprivate var head: CGFloat {
        switch self {
        case .regular: return 11
        case .medium: return 12
        case .heavy: return 13
        }
    }

    fileprivate var dot: CGFloat {
        switch self {
        case .regular: return 6.5
        case .medium: return 8
        case .heavy: return 9
        }
    }
}

/// The Flyby glyph: a comet-like trail curling around a bright head, drawn in a 120×120 box.
struct FlybyGlyph: View {
    var ink: Color
    var dot: Color
    var weight: GlyphWeight = .regular
    var stars: Color?

    var body: some View {
        Canvas { context, size in
            let k = min(size.width, size.height) / 120
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }
            func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: (x - r) * k, y: (y - r) * k, width: 2 * r * k, height: 2 * r * k))
            }

            if let stars {
                for (x, y, r) in [(18, 22, 1.2), (104, 98, 1.0), (40, 12, 0.8), (112, 16, 0.9)] as [(CGFloat, CGFloat, CGFloat)] {
                    context.fill(circle(x, y, r), with: .color(stars))
                }
            }

            context.fill(circle(84, 50, weight.head), with: .color(ink))

            var trail = Path()
            trail.move(to: point(14, 100))
            trail.addCurve(to: point(84, 76), control1: point(40, 92), control2: point(60, 76))
            // Three-quarter ring around the head: from the bottom, counter-clockwise on screen.
            trail.addRelativeArc(center: point(84, 50), radius: 26 * k, startAngle: .degrees(90), delta: .degrees(-240))
            trail.addCurve(to: point(26, 70), control1: point(52, 52), control2: point(40, 62))
            context.stroke(
                trail,
                with: .color(ink),
                style: StrokeStyle(lineWidth: weight.line * k, lineCap: .round, lineJoin: .round)
            )

            context.fill(circle(26, 70, weight.dot), with: .color(dot))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// The full rounded-square app icon for a given variation.
struct AppIconArtwork: View {
    let style: AppIconStyle
    var weight: GlyphWeight = .regular

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 50 / 220, style: .continuous)
                    .fill(background)

                if style == .vacuo {
                    RoundedRectangle(cornerRadius: side * 50 / 220, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: max(1, side / 220))
                }

                FlybyGlyph(ink: glyph, dot: dot, weight: weight, stars: style == .vacuo ? IconPalette.star : nil)
                    .frame(width: side * 150 / 220, height: side * 150 / 220)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var background: Color {
        switch style {
        case .vacuo: return IconPalette.night
        case .lua: return IconPalette.paper
        case .ignicao: return IconPalette.accent
        }
    }

    private var glyph: Color { style == .vacuo ? IconPalette.paper : IconPalette.ink }
    private var dot: Color { style == .ignicao ? IconPalette.paper : IconPalette.accent }
}

// MARK: - Rendering

enum AppIconRenderer {
    @MainActor
    private static func render<V: View>(_ view: V, side: CGFloat, scale: CGFloat) -> ImageRenderer<some View> {
        let renderer = ImageRenderer(content: view.frame(width: side, height: side))
        renderer.scale = scale
        return renderer
    }

    /// Monochrome template glyph for the menu bar; macOS tints it for light/dark menu bars.
    @MainActor
    static func menuBarImage(side: CGFloat = 18) -> NSImage? {
        let glyph = FlybyGlyph(ink: .black, dot: .black, weight: .heavy)
        let image = render(glyph, side: side, scale: 3).nsImage
        image?.isTemplate = true
        return image
    }

    /// App icon with the standard macOS margin around the rounded square.
    @MainActor
    static func applicationIcon(_ style: AppIconStyle, side: CGFloat = 512) -> NSImage? {
        render(paddedIcon(style, weight: .regular), side: side, scale: 2).nsImage
    }

    @MainActor
    static func paddedIcon(_ style: AppIconStyle, weight: GlyphWeight) -> some View {
        AppIconArtwork(style: style, weight: weight)
            .padding(.all, 100 / 1024 * 512)
            .frame(width: 512, height: 512)
    }

    /// Writes an `.iconset` folder (for `iconutil -c icns`) for the given style.
    @MainActor
    static func exportIconset(style: AppIconStyle, to directory: URL) throws {
        let sizes: [(name: String, pixels: Int, weight: GlyphWeight)] = [
            ("icon_16x16", 16, .heavy), ("icon_16x16@2x", 32, .heavy),
            ("icon_32x32", 32, .heavy), ("icon_32x32@2x", 64, .medium),
            ("icon_128x128", 128, .regular), ("icon_128x128@2x", 256, .regular),
            ("icon_256x256", 256, .regular), ("icon_256x256@2x", 512, .regular),
            ("icon_512x512", 512, .regular), ("icon_512x512@2x", 1024, .regular)
        ]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for entry in sizes {
            let side = CGFloat(entry.pixels)
            let view = AppIconArtwork(style: style, weight: entry.weight)
                .padding(.all, side * 100 / 1024)
                .frame(width: side, height: side)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            guard let cgImage = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try png.write(to: directory.appendingPathComponent("\(entry.name).png"))
        }
    }
}
