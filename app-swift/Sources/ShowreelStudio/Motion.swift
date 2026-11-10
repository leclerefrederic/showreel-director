import AppKit
import ShowreelKit
import SwiftUI

// The motion of the interface. ShowreelKit's `MotionTokens` hold the numbers (durations, curves, the spring of the sliding panes, the speed scale, the rule of "Reduce motion"); this file
// is the one place that turns them into SwiftUI animations and modifiers, named by what they mean. A view never writes a duration or a curve: it asks for a pattern.

enum Motion {
    /// The tokens in force; a skin sets them through the theme (`Theme.motion`). The speed scale and the system's "Reduce motion" both apply through `animation(_:)`.
    nonisolated(unsafe) static var tokens = MotionTokens.standard
    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// The animation of a pattern, nil when nothing should move (a speed of 0, or Reduce motion: the information stays, the movement goes).
    static func animation(_ p: MotionTokens.Pattern) -> Animation? {
        let r = tokens.resolve(p, reduceMotion: reduced)
        guard r.moves, !r.isNone else { return nil }
        switch r.curve {
        case .decelerate: return .easeOut(duration: r.duration)
        case .accelerate: return .easeIn(duration: r.duration)
        case .overshoot: return .spring(response: tokens.confirm.response / tokens.speed, dampingFraction: tokens.confirm.damping)
        case .panelSpring: return .spring(response: tokens.panel.response / tokens.speed, dampingFraction: tokens.panel.damping)
        }
    }

    /// The slight bounce of the sliding panes (Look, Project, Clap), and of everything that moves a panel.
    static var spring: Animation? { animation(.panel) }
    /// A highlight, a hover: the fast one.
    static var quick: Animation? { reduced || tokens.speed <= 0 ? nil : .easeOut(duration: tokens.fast / tokens.speed) }
    /// A selection that slides, a thing that settles into its place.
    static var select: Animation? { animation(.select) }
    static var settle: Animation? { animation(.settle) }
    static var toggle: Animation? { animation(.toggle) }
    static var confirm: Animation? { animation(.pop) }

    /// What arrives and what leaves: a gap opens and the thing comes into it; under Reduce motion it only fades.
    static var arrive: AnyTransition { reduced || tokens.speed <= 0 ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .top)) }
    static var depart: AnyTransition { .opacity }
    static var appear: AnyTransition { arrive }

    static func go<R>(_ body: () -> R) -> R { withAnimation(spring, body) }
    static func with<R>(_ p: MotionTokens.Pattern, _ body: () -> R) -> R { withAnimation(animation(p), body) }
}

// MARK: patterns

/// A control that refused shakes a little (the reason is shown where the eye is, by the status line): `trigger` goes up each time it refuses.
struct NudgeEffect: GeometryEffect {
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 5 * sin(progress * .pi * 3), y: 0))
    }
}

private struct Nudge: ViewModifier {
    let trigger: Int
    @State private var n = 0
    func body(content: Content) -> some View {
        content.modifier(NudgeEffect(progress: CGFloat(n)))
            .onChange(of: trigger) { _ in withAnimation(Motion.animation(.nudge)) { n += 1 } }
    }
}

/// An icon that changes state pulses once: it grows a little and settles.
private struct StatePulse<V: Equatable>: ViewModifier {
    let value: V
    @State private var up = false
    func body(content: Content) -> some View {
        content.scaleEffect(up ? 1.28 : 1).animation(Motion.animation(.stateChange), value: up)
            .onChange(of: value) { _ in
                guard Motion.animation(.stateChange) != nil else { return }
                up = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { up = false }
            }
    }
}

/// A diamond or a target that lights up pops a little.
private struct Pop: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View { content.scaleEffect(on ? 1.18 : 1).animation(Motion.confirm, value: on) }
}

extension View {
    func nudge(trigger: Int) -> some View { modifier(Nudge(trigger: trigger)) }
    func stateChange<V: Equatable>(_ value: V) -> some View { modifier(StatePulse(value: value)) }
    func pop(_ on: Bool) -> some View { modifier(Pop(on: on)) }
    func arrives() -> some View { transition(Motion.arrive) }
    func departs() -> some View { transition(Motion.depart) }
    func settles<V: Equatable>(_ value: V) -> some View { animation(Motion.settle, value: value) }
}

/// An icon that is swapped for another cross-fades with a tiny scale (the eye, the lock).
struct ToggleIcon: View {
    let symbol: String
    var size: CGFloat = 12
    var body: some View {
        ZStack {
            Image(systemName: symbol).font(.system(size: size)).id(symbol).transition(.opacity.combined(with: .scale(scale: 0.85)))
        }
        .animation(Motion.toggle, value: symbol)
    }
}

/// The highlight of the selected row or frame: one shape that slides to the row or frame that is selected (a matched geometry in the namespace of the list), never a jump.
struct SelectionSlide<S: Shape>: ViewModifier {
    let selected: Bool
    let id: String
    let ns: Namespace.ID
    let shape: S
    let fill: Color
    var stroke: Color? = nil
    func body(content: Content) -> some View {
        content.background {
            if selected { shape.fill(fill).overlay { if let s = stroke { shape.stroke(s, lineWidth: 1) } }.matchedGeometryEffect(id: id, in: ns).transition(.opacity) }
        }
    }
}

/// The mark of a scene's run state in a Build: a still dot while it waits, a gentle pulse while it writes, a short sweep while it tests, an alternate mark while it repairs. Under Reduce
/// motion each one is still: the icon and the label say which it is.
struct RunMark: View {
    let state: SceneRun.State
    var size: CGFloat = 13
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var phase = false

    var body: some View {
        let look = RunAppearance.look(state)
        let still = reduce || Motion.tokens.speed <= 0 || look.motion == .still
        ZStack {
            Image(systemName: look.role.symbol).font(.system(size: look.role == .runWaiting ? size * 0.6 : size))
                .foregroundStyle(state == .failed ? theme.danger : state == .waiting ? theme.textSecondary : theme.accent)
                .opacity(look.motion == .pulse && !still ? (phase ? 1 : 0.4) : 1)
                .rotationEffect(.degrees(look.motion == .alternate && !still ? (phase ? 12 : -12) : 0))
            if look.motion == .sweep, !still {
                Capsule().fill(theme.accent.opacity(0.9)).frame(width: 3, height: size).offset(x: phase ? size / 2 : -size / 2).mask(Rectangle().frame(width: size + 4, height: size + 4))
            }
        }
        .frame(width: size + 4, height: size + 4)
        .onAppear { start(still) }
        .onChange(of: state) { _ in phase = false; start(still) }
        .help(look.label).accessibilityLabel("Build: " + look.label)
    }

    private func start(_ still: Bool) {
        guard !still else { return }
        withAnimation(.easeInOut(duration: Motion.tokens.slow * 3 / Motion.tokens.speed).repeatForever(autoreverses: true)) { phase = true }
    }
}

/// A slow pulse on an icon while Clap works.
struct ClapPulse: ViewModifier {
    let active: Bool
    @State private var up = false
    func body(content: Content) -> some View {
        content.opacity(active ? (up ? 1 : 0.35) : 1)
            .onChange(of: active) { on in if on { begin() } else { withAnimation(nil) { up = false } } }
            .onAppear { if active { begin() } }
    }
    private func begin() { withAnimation(.easeInOut(duration: Motion.tokens.slow * 3 / max(Motion.tokens.speed, 0.01)).repeatForever(autoreverses: true)) { up = true } }
}
