import SwiftUI

/// How a dock icon reacts while the pointer is over it. Picked in Preferences, where effects
/// can also be turned off altogether (`AppSettings.dockHoverEffectsEnabled`).
///
/// Magnify and lift hold while the pointer stays; bounce, wiggle and spin play once on entry.
enum DockHoverEffect: String, CaseIterable, Identifiable {
    case magnify, lift, bounce, wiggle, spin

    var id: String { rawValue }

    var displayName: String { L10n.hoverEffectName(self) }

    fileprivate static let magnifyScale: CGFloat = 1.3
    fileprivate static let liftFraction: CGFloat = 0.22
    fileprivate static let bounceFraction: CGFloat = 0.25

    /// How far above its slot an icon of `side` points stays while hovered. The name label
    /// moves up by this much so the icon never runs into it.
    func rise(for side: CGFloat) -> CGFloat {
        switch self {
        case .magnify: return side * (Self.magnifyScale - 1)
        case .lift: return side * Self.liftFraction
        case .bounce, .wiggle, .spin: return 0
        }
    }

    fileprivate var playsOnce: Bool {
        switch self {
        case .magnify, .lift: return false
        case .bounce, .wiggle, .spin: return true
        }
    }

    fileprivate var duration: Double {
        switch self {
        case .spin: return 0.6
        default: return 0.5
        }
    }
}

extension View {
    /// Applies `effect` to an icon `side` points wide while `active`; nil draws it still.
    func dockHoverEffect(_ effect: DockHoverEffect?, active: Bool, side: CGFloat) -> some View {
        modifier(HoverEffectModifier(effect: effect, active: active, side: side))
    }
}

private struct HoverEffectModifier: ViewModifier {
    let effect: DockHoverEffect?
    let active: Bool
    let side: CGFloat

    /// Counts the one-shot plays. A play is this value animating from n to n + 1, so a new
    /// one never has to reset the previous one first.
    @State private var plays: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(OneShotEffect(effect: effect, progress: plays, side: side))
            .scaleEffect(effect == .magnify && active ? DockHoverEffect.magnifyScale : 1, anchor: .bottom)
            .offset(y: effect == .lift && active ? -side * DockHoverEffect.liftFraction : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: active)
            .onChange(of: active) { isActive in
                guard isActive, let effect, effect.playsOnce else { return }
                withAnimation(.linear(duration: effect.duration)) { plays += 1 }
            }
    }
}

/// Draws the one-shot effects from the fractional part of `progress` (0 at rest).
private struct OneShotEffect: ViewModifier, Animatable {
    let effect: DockHoverEffect?
    var progress: CGFloat
    let side: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = progress - progress.rounded(.down)
        return content
            .offset(y: effect == .bounce ? -bounceHeight(t) : 0)
            .rotationEffect(.degrees(effect == .wiggle ? wiggleAngle(t) : 0))
            .rotation3DEffect(
                .degrees(effect == .spin ? 360 * smoothstep(t) : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.4
            )
    }

    /// A tall hop and a short one, each a parabola, like something landing on the dock.
    private func bounceHeight(_ t: CGFloat) -> CGFloat {
        let split: CGFloat = 0.62
        let peak = side * DockHoverEffect.bounceFraction
        if t < split {
            let u = t / split
            return 4 * peak * u * (1 - u)
        }
        let u = (t - split) / (1 - split)
        return 4 * peak * 0.3 * u * (1 - u)
    }

    /// Two swings that die out.
    private func wiggleAngle(_ t: CGFloat) -> Double {
        Double(9 * sin(2 * .pi * 2 * t) * (1 - t))
    }

    private func smoothstep(_ t: CGFloat) -> CGFloat {
        t * t * (3 - 2 * t)
    }
}
