import AppKit
import SwiftUI

/// Background of the DMG installer window (660×400), from the "Instalador — fundo da janela"
/// design. It deliberately has no icons: Finder draws the app and the Applications shortcut on
/// top at the positions set in scripts/dmg-settings.py.
struct InstallerBackground: View {
    var version: String
    var minimumOS: String

    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, opacity: Double)] = [
        (38, 44, 1, 0.7), (92, 118, 0.8, 0.5), (146, 30, 1.2, 0.6), (214, 96, 0.7, 0.5),
        (268, 22, 0.9, 0.6), (452, 28, 1, 0.6), (508, 102, 0.8, 0.5), (574, 40, 1.3, 0.7),
        (624, 128, 0.8, 0.5), (604, 250, 1, 0.5), (26, 232, 0.9, 0.5), (58, 300, 0.7, 0.4),
        (636, 312, 0.8, 0.4), (330, 58, 0.6, 0.4), (398, 88, 0.7, 0.4)
    ]

    private static let craters: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (250, 372, 9), (452, 364, 5), (540, 380, 12), (120, 384, 6)
    ]

    var body: some View {
        ZStack {
            Brand.vacuo

            Canvas { context, _ in
                func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                }

                for star in Self.stars {
                    context.fill(circle(star.x, star.y, star.r), with: .color(Brand.poeira.opacity(star.opacity)))
                }

                // The "moon" horizon at the bottom, with a few craters.
                let moon = circle(330, 1180, 840)
                context.fill(moon, with: .color(IconPalette.night))
                context.stroke(moon, with: .color(Brand.orbita), lineWidth: 1)
                for crater in Self.craters {
                    context.stroke(
                        circle(crater.x, crater.y, crater.r),
                        with: .color(Color(hex: 0x1C2230)),
                        lineWidth: 1.5
                    )
                }

                // Dotted trajectory from the app to Applications, ending in an arrowhead.
                var arc = Path()
                arc.move(to: CGPoint(x: 250, y: 180))
                arc.addQuadCurve(to: CGPoint(x: 410, y: 180), control: CGPoint(x: 330, y: 110))
                context.stroke(
                    arc,
                    with: .color(Brand.poeira),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 9])
                )

                var arrow = Path()
                arrow.move(to: CGPoint(x: 408.8, y: 172.5))
                arrow.addLine(to: CGPoint(x: 412, y: 182))
                arrow.addLine(to: CGPoint(x: 402.2, y: 180))
                context.stroke(
                    arrow,
                    with: .color(Brand.poeira),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                // The spacecraft: accent dot with a soft halo.
                context.fill(circle(378, 157.6, 11), with: .color(Brand.ignicao.opacity(0.18)))
                context.fill(circle(378, 157.6, 5), with: .color(Brand.ignicao))
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    FlybyGlyph(ink: Brand.lua, dot: Brand.ignicao, weight: .medium)
                        .frame(width: 22, height: 22)
                    Text("flyby")
                        .font(Brand.sans(20, .semibold))
                        .tracking(-0.6)
                        .foregroundStyle(Brand.lua)
                }
                Text("Arraste o Flyby para Aplicativos para instalar")
                    .font(Brand.sans(14))
                    .foregroundStyle(Brand.textSoft)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 34)

            Text("V\(version) · REQUER MACOS \(minimumOS)")
                .font(Brand.mono(11))
                .tracking(0.88)
                .foregroundStyle(Brand.poeira)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 18)
        }
        .frame(width: 660, height: 400)
        .clipped()
    }

    /// Writes `background.png` (660×400) and `background@2x.png` (1320×800) into `directory`.
    @MainActor
    static func export(to directory: URL, version: String, minimumOS: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for (name, scale) in [("background.png", 1.0), ("background@2x.png", 2.0)] {
            let renderer = ImageRenderer(content: InstallerBackground(version: version, minimumOS: minimumOS))
            renderer.scale = scale
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try png.write(to: directory.appendingPathComponent(name))
        }
    }
}
