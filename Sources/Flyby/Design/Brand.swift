import SwiftUI

/// Flyby visual identity ("direção Órbita"): vacuum-dark surfaces, thin lines, mono numbers
/// and a single orange accent. See .claude/skills/flyby-brand/SKILL.md.
enum Brand {
    static let vacuo = Color(hex: 0x0B0E14)      // background
    static let casco = Color(hex: 0x151A24)      // surfaces
    static let orbita = Color(hex: 0x2A3142)     // lines, tracks
    static let poeira = Color(hex: 0x8A93A6)     // secondary text
    static let lua = Color(hex: 0xE6E8EE)        // text, mark
    static let ignicao = Color(hex: 0xFF6B2C)    // the one accent
    static let textSoft = Color(hex: 0xA9B0BF)   // tertiary text
    static let muted = Color(hex: 0x4A5266)      // disabled fill (muted tracks)

    // The brand typefaces are Geist / Geist Mono; until they are bundled we use the
    // system UI and system monospaced faces, which share the same neutral character.
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Small uppercase mono caption used for section titles (TELEMETRIA, MIXER...).
struct BrandLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(Brand.mono(11))
            .tracking(1.5)
            .foregroundStyle(Brand.poeira)
    }
}

struct BrandDivider: View {
    var body: some View {
        Rectangle().fill(Brand.orbita).frame(height: 1)
    }
}

/// Borderless text button with a 44pt hit target and a subtle hover fill.
struct BrandButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Brand.sans(13, .medium))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(Brand.lua)
            .padding(.horizontal, 14)
            .frame(minWidth: 44, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hovering || configuration.isPressed ? Brand.orbita : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
    }
}

/// Circular gauge: thin track, a moon-coloured arc and an accent dot at its tip.
struct TelemetryRing: View {
    let fraction: Double
    let value: String
    let label: String
    let detail: String

    private let radius: CGFloat = 34

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Brand.orbita, lineWidth: 5)
                    .frame(width: radius * 2, height: radius * 2)

                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(Brand.lua, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(Brand.ignicao)
                    .frame(width: 10, height: 10)
                    .offset(
                        x: radius * CGFloat(cos(-Double.pi / 2 + clamped * 2 * .pi)),
                        y: radius * CGFloat(sin(-Double.pi / 2 + clamped * 2 * .pi))
                    )

                Text(value)
                    .font(Brand.mono(17, .medium))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(width: 58)
            }
            .frame(width: 88, height: 88)

            VStack(spacing: 2) {
                Text(label).font(Brand.sans(13, .medium))
                Text(detail)
                    .font(Brand.mono(11))
                    .foregroundStyle(Brand.poeira)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(Brand.lua)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value), \(detail)")
    }
}

/// 4pt track with an accent fill and a 14pt moon-coloured thumb.
struct BrandSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var fill: Color = Brand.ignicao
    var accessibilityName: String = ""

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let span = range.upperBound - range.lowerBound
            let fraction = min(max((value - range.lowerBound) / span, 0), 1)

            ZStack(alignment: .leading) {
                Capsule().fill(Brand.orbita).frame(height: 4)
                Capsule().fill(fill).frame(width: width * fraction, height: 4)
                Circle()
                    .fill(Brand.lua)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Brand.casco).frame(width: 20, height: 20))
                    .offset(x: width * fraction - 7)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    let ratio = min(max(drag.location.x / width, 0), 1)
                    value = range.lowerBound + ratio * span
                }
            )
        }
        .frame(height: 20)
        .accessibilityElement()
        .accessibilityLabel(accessibilityName)
        .accessibilityValue("\(Int(value * 100)) %")
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            switch direction {
            case .increment: value = min(value + step, range.upperBound)
            case .decrement: value = max(value - step, range.lowerBound)
            @unknown default: break
            }
        }
    }
}
