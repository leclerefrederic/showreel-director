import AppKit
import ShowreelKit
import SwiftUI

// The theme of the app: ShowreelKit's `DesignTokens` mapped to SwiftUI, and the shared control styles. It is the ONE place that holds a colour literal or a text size. A view reads the
// theme from the SwiftUI environment (`@EnvironmentObject var theme: Theme`, or through a modifier below), never a constant, so that a later phase can swap the tokens at run time.

final class Theme: ObservableObject {
    @Published var tokens: DesignTokens

    init(_ tokens: DesignTokens = .graphite) { self.tokens = tokens }

    func color(_ hex: String) -> Color {
        guard let c = DesignTokens.rgb(hex) else { return .clear }
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    // surfaces, borders, text
    var canvas: Color { color(tokens.surfaces.canvas) }
    var panel: Color { color(tokens.surfaces.panel) }
    var raised: Color { color(tokens.surfaces.raised) }
    var selected: Color { color(tokens.surfaces.selected) }
    var hairline: Color { color(tokens.borders.hairline) }
    var strong: Color { color(tokens.borders.strong) }
    var textPrimary: Color { color(tokens.text.primary) }
    var textSecondary: Color { color(tokens.text.secondary) }
    /// Decoration and disabled things only.
    var textFaint: Color { color(tokens.text.faint) }
    var accent: Color { color(tokens.accent) }
    var onAccent: Color { color(tokens.onAccent) }
    var warning: Color { color(tokens.roles.warning) }
    var danger: Color { color(tokens.roles.danger) }
    var success: Color { color(tokens.roles.success) }
    var review: Color { color(tokens.roles.review) }
    var outOfDate: Color { color(tokens.roles.outOfDate) }
    var laneScene: Color { color(tokens.lanes.scene) }
    var laneSceneBorder: Color { color(tokens.lanes.sceneBorder) }
    var laneMusic: Color { color(tokens.lanes.music) }

    /// The colour of a Status state (UI2): its meaning, from the roles of the tokens.
    func status(_ k: SceneStatusKind) -> Color { color(tokens.status(k)) }

    // radii, spacing, type
    var rSmall: CGFloat { tokens.radii.small }
    var rMedium: CGFloat { tokens.radii.medium }
    var rLarge: CGFloat { tokens.radii.large }
    var gap: CGFloat { 6 }
    func space(_ n: Int) -> CGFloat { CGFloat(tokens.spacingScale[max(0, min(n, 4))]) }

    func font(_ role: TextRole, weight: Font.Weight = .regular, mono: Bool = false, digits: Bool = false) -> Font {
        let size: Double
        switch role { case .small: size = tokens.sizes.small; case .body: size = tokens.sizes.body; case .title: size = tokens.sizes.title; case .large: size = tokens.sizes.large }
        let f = Font.system(size: CGFloat(size), weight: weight, design: mono ? .monospaced : .default)
        return digits ? f.monospacedDigit() : f
    }
}

enum TextRole { case small, body, title, large }

// MARK: text, through the environment

private struct ThemedFont: ViewModifier {
    @EnvironmentObject var theme: Theme
    let role: TextRole, weight: Font.Weight, mono: Bool, digits: Bool
    func body(content: Content) -> some View { content.font(theme.font(role, weight: weight, mono: mono, digits: digits)) }
}

private struct ThemedForeground: ViewModifier {
    enum Kind { case primary, secondary, faint, accent, warning, danger, success, review }
    @EnvironmentObject var theme: Theme
    let kind: Kind
    func body(content: Content) -> some View {
        switch kind {
        case .primary: content.foregroundStyle(theme.textPrimary)
        case .secondary: content.foregroundStyle(theme.textSecondary)
        case .faint: content.foregroundStyle(theme.textFaint)
        case .accent: content.foregroundStyle(theme.accent)
        case .warning: content.foregroundStyle(theme.warning)
        case .danger: content.foregroundStyle(theme.danger)
        case .success: content.foregroundStyle(theme.success)
        case .review: content.foregroundStyle(theme.review)
        }
    }
}

extension View {
    /// The small text style (11 pt): what `.caption` and `.caption2` were, which are 10 pt on macOS.
    func fontSmall(weight: Font.Weight = .regular, mono: Bool = false, digits: Bool = false) -> some View { modifier(ThemedFont(role: .small, weight: weight, mono: mono, digits: digits)) }
    func fontBody(weight: Font.Weight = .regular, mono: Bool = false, digits: Bool = false) -> some View { modifier(ThemedFont(role: .body, weight: weight, mono: mono, digits: digits)) }
    func fontTitle(weight: Font.Weight = .medium) -> some View { modifier(ThemedFont(role: .title, weight: weight, mono: false, digits: false)) }
    func fontLarge(weight: Font.Weight = .medium) -> some View { modifier(ThemedFont(role: .large, weight: weight, mono: false, digits: false)) }
    func textPrimary() -> some View { modifier(ThemedForeground(kind: .primary)) }
    func textSecondary() -> some View { modifier(ThemedForeground(kind: .secondary)) }
    func textDecorative() -> some View { modifier(ThemedForeground(kind: .faint)) }
    func textAccent() -> some View { modifier(ThemedForeground(kind: .accent)) }
    func textWarning() -> some View { modifier(ThemedForeground(kind: .warning)) }
    func textDanger() -> some View { modifier(ThemedForeground(kind: .danger)) }
}

// MARK: surfaces

/// A panel: the panel surface, one large radius, a hairline border.
private struct PanelContainer: ViewModifier {
    @EnvironmentObject var theme: Theme
    func body(content: Content) -> some View {
        content
            .background(theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: theme.rLarge, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.rLarge, style: .continuous).stroke(theme.hairline, lineWidth: 1))
    }
}

/// A row of a list: the selected surface when selected, the raised one under the pointer.
private struct RowSurface: ViewModifier {
    @EnvironmentObject var theme: Theme
    let selected: Bool, hovering: Bool
    func body(content: Content) -> some View {
        content.background(selected ? theme.selected : hovering ? theme.raised : Color.clear, in: RoundedRectangle(cornerRadius: theme.rMedium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.rMedium, style: .continuous).stroke(selected ? theme.accent.opacity(0.55) : Color.clear, lineWidth: 1))
    }
}

private struct CanvasBackground: ViewModifier {
    @EnvironmentObject var theme: Theme
    func body(content: Content) -> some View { content.background(theme.canvas) }
}

private struct PanelBackground: ViewModifier {
    @EnvironmentObject var theme: Theme
    func body(content: Content) -> some View { content.background(theme.panel) }
}

private struct RaisedBackground: ViewModifier {
    @EnvironmentObject var theme: Theme
    func body(content: Content) -> some View { content.background(theme.raised, in: RoundedRectangle(cornerRadius: theme.rMedium, style: .continuous)) }
}

extension View {
    func panelContainer() -> some View { modifier(PanelContainer()) }
    func rowSurface(selected: Bool, hovering: Bool = false) -> some View { modifier(RowSurface(selected: selected, hovering: hovering)) }
    func canvasBackground() -> some View { modifier(CanvasBackground()) }
    func panelBackground() -> some View { modifier(PanelBackground()) }
    func raisedBackground() -> some View { modifier(RaisedBackground()) }
}

// MARK: controls

/// The one primary action of a view: the accent, with the text that reads on it.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration) }
    private struct Styled: View {
        let configuration: ButtonStyleConfiguration
        @EnvironmentObject var theme: Theme
        @Environment(\.isEnabled) private var enabled
        var body: some View {
            configuration.label.fontBody(weight: .medium).foregroundStyle(theme.onAccent)
                .padding(.horizontal, theme.space(2)).padding(.vertical, 5)
                .background(theme.accent.opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.35), in: RoundedRectangle(cornerRadius: theme.rMedium, style: .continuous))
                .contentShape(Rectangle())
        }
    }
}

/// Any other action: the raised surface and a strong border.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration) }
    private struct Styled: View {
        let configuration: ButtonStyleConfiguration
        @EnvironmentObject var theme: Theme
        @Environment(\.isEnabled) private var enabled
        var body: some View {
            configuration.label.fontBody().foregroundStyle(enabled ? theme.textPrimary : theme.textSecondary)
                .padding(.horizontal, theme.space(2)).padding(.vertical, 5)
                .background(configuration.isPressed ? theme.selected : theme.raised, in: RoundedRectangle(cornerRadius: theme.rMedium, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.rMedium, style: .continuous).stroke(theme.strong, lineWidth: 1))
                .opacity(enabled ? 1 : 0.6)
                .contentShape(Rectangle())
        }
    }
}

/// What deletes or discards: an outline in the danger colour, never filled.
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration) }
    private struct Styled: View {
        let configuration: ButtonStyleConfiguration
        @EnvironmentObject var theme: Theme
        @Environment(\.isEnabled) private var enabled
        var body: some View {
            configuration.label.fontBody().foregroundStyle(theme.danger)
                .padding(.horizontal, theme.space(2)).padding(.vertical, 5)
                .background(configuration.isPressed ? theme.danger.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: theme.rMedium, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.rMedium, style: .continuous).stroke(theme.danger.opacity(0.7), lineWidth: 1))
                .opacity(enabled ? 1 : 0.5)
                .contentShape(Rectangle())
        }
    }
}

/// A switch with the accent when on. It is still a `Toggle` underneath: the keyboard and VoiceOver work, and the label and the value are read.
struct ThemedToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration) }
    private struct Styled: View {
        let configuration: ToggleStyleConfiguration
        @EnvironmentObject var theme: Theme
        @Environment(\.isEnabled) private var enabled
        var body: some View {
            Button { configuration.isOn.toggle() } label: {
                HStack(spacing: theme.space(1)) {
                    configuration.label.fontBody().foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 6)
                    ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                        Capsule().fill(configuration.isOn ? theme.accent : theme.strong).frame(width: 34, height: 20)
                        Circle().fill(configuration.isOn ? theme.onAccent : theme.textSecondary).frame(width: 14, height: 14).padding(.horizontal, 3)
                    }
                    .animation(Motion.quick, value: configuration.isOn)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(enabled ? 1 : 0.5)
            .accessibilityElement(children: .combine)
            .accessibilityValue(configuration.isOn ? "on" : "off")
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// A text field on the raised surface with a hairline border.
struct ThemedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View { Styled(content: configuration) }
    private struct Styled<C: View>: View {
        let content: C
        @EnvironmentObject var theme: Theme
        var body: some View {
            content.textFieldStyle(.plain).fontBody().padding(.horizontal, 8).padding(.vertical, 5)
                .background(theme.raised, in: RoundedRectangle(cornerRadius: theme.rSmall, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.rSmall, style: .continuous).stroke(theme.hairline, lineWidth: 1))
        }
    }
}

/// Segmented tabs: buttons on a raised track, the selected one on the selected surface with the accent. Real buttons: Tab reaches them and VoiceOver reads each as selected or not.
struct ThemedTabs<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let label: (Item) -> AnyView
    let name: (Item) -> String
    @EnvironmentObject var theme: Theme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let on = item == selection
                Button { selection = item } label: {
                    label(item).fontBody(weight: on ? .medium : .regular).foregroundStyle(on ? theme.accent : theme.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 5)
                        .background(on ? theme.selected : Color.clear, in: RoundedRectangle(cornerRadius: theme.rSmall, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name(item))
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(2).background(theme.raised, in: RoundedRectangle(cornerRadius: theme.rMedium, style: .continuous))
        .animation(Motion.quick, value: selection)
    }
}

// MARK: the rail

/// The rail at the far left of the workspace, in two groups with a thin line between them: the centre views (Film, Build) and the right panels (Inspector, Look, Project, Clap).
/// The model is ShowreelKit's `RailEntry` and `RailState`; the click is `ProjectModel.openRail`. Clap's entry shows what Clap does: a pulse (a dot under Reduce motion) while it works
/// and a badge with the number of proposals that wait.
struct ViewRailView: View {
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var chat: ChatModel
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: RailEntry?

    var body: some View {
        let state = project.railState
        VStack(spacing: theme.space(0)) {
            ForEach(RailEntry.entries(in: .centre)) { e in entry(e, state) }
            Rectangle().fill(theme.hairline).frame(width: 36, height: 1).padding(.vertical, theme.space(0))
            ForEach(RailEntry.entries(in: .right)) { e in entry(e, state) }
            Spacer(minLength: 0)
        }
        .padding(.vertical, theme.space(1)).padding(.horizontal, 4)
        .frame(width: CGFloat(ShellLayout.rail)).frame(maxHeight: .infinity)
        .background(theme.canvas)
        .onMoveCommand { d in                                         // the arrows move between entries
            let all = RailEntry.allCases
            guard let i = focused.flatMap({ all.firstIndex(of: $0) }) else { focused = all.first; return }
            if d == .down { focused = all[min(i + 1, all.count - 1)] } else if d == .up { focused = all[max(i - 1, 0)] }
        }
    }

    private var clap: ClapIndicator { ClapIndicator(working: chat.running || project.activity.clap != nil, proposals: project.activity.proposals.count) }

    @ViewBuilder private func entry(_ e: RailEntry, _ state: RailState) -> some View {
        let on = state.isSelected(e)
        let ind = clap
        let label = e == .clap ? ind.label : e == .inspector && state.inspectorMark ? "Inspector, a new selection is waiting" : e.title
        Button { project.openRail(e) } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: e.role.symbol).font(.system(size: 17, weight: .regular)).frame(height: 22)
                        .modifier(ClapPulse(active: e == .clap && ind.motion(reduceMotion: reduceMotion) == .pulse))
                    if e == .clap, ind.motion(reduceMotion: reduceMotion) == .dot { Circle().fill(theme.accent).frame(width: 7, height: 7).offset(x: 3, y: -1) }
                    if e == .clap, let n = ind.badge {
                        Text("\(n)").fontSmall(weight: .medium).foregroundStyle(theme.onAccent).padding(.horizontal, 4).background(theme.warning, in: Capsule()).offset(x: 10, y: -5)
                    }
                    if e == .inspector, state.inspectorMark { Circle().fill(theme.accent).frame(width: 7, height: 7).offset(x: 4, y: -1) }
                }
                Text(e.title).fontSmall(weight: on ? .medium : .regular)
            }
            .foregroundStyle(on ? theme.accent : theme.textSecondary)
            .frame(width: 52).padding(.vertical, 7)
            .rowSurface(selected: on)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focused, equals: e)
        .help(e == .clap ? "\(ind.label). \(e.help) (\(AppShortcuts.clapDisplay))" : e.help)
        .accessibilityLabel(label)
        .accessibilityHint(e.help)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

/// A slow pulse on an icon while Clap works.
private struct ClapPulse: ViewModifier {
    let active: Bool
    @State private var up = false
    func body(content: Content) -> some View {
        content.opacity(active ? (up ? 1 : 0.35) : 1)
            .onChange(of: active) { on in if on { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { up = true } } else { withAnimation(nil) { up = false } } }
            .onAppear { if active { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { up = true } } }
    }
}

// MARK: the view group of the top bar

/// The pictogram of a Film placement: a small window with its regions (the rail, the left panels, the preview, the right panel) and the Film strip lit in the accent. It is
/// drawn from the theme and animates from one layout to the other with the spring.
struct LayoutPictogram: View {
    let placement: FilmPlacement
    @EnvironmentObject var theme: Theme

    private func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, lit: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous).fill(lit ? theme.accent : theme.textSecondary.opacity(0.55)).frame(width: w, height: h).offset(x: x, y: y)
    }

    var body: some View {
        let under = placement == .underPreview
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(theme.textSecondary, lineWidth: 1).frame(width: 26, height: 19)
            block(2, 2, 2, 15)                                                       // the rail
            block(5, 2, 5, under ? 15 : 8)                                           // the left panels
            block(11, 2, 7, 8)                                                       // the preview
            block(19, 2, 5, under ? 15 : 8)                                          // the right panel
            block(under ? 11 : 5, 11, under ? 7 : 19, 6, lit: true)                  // the Film strip
        }
        .frame(width: 26, height: 19, alignment: .topLeading)
        .animation(Motion.spring, value: placement)
    }
}

/// The two buttons at the right end of the top bar, after the Checks badge and the Catalogue: where the Film strip lives, and the reset of the proportions.
struct ViewGroup: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        let p = project.filmPlacement
        HStack(spacing: 6) {
            Button { project.toggleFilmPlacement() } label: { LayoutPictogram(placement: p) }
                .help(p.tooltip)
                .accessibilityLabel("Film placement").accessibilityValue(p.name).accessibilityHint(p.tooltip)
            Button { Motion.go { project.resetLayout() } } label: { Image(systemName: IconRole.resetLayout.symbol) }
                .help("Restore the standard proportions")
                .accessibilityLabel("Restore the standard proportions")
                .disabledWithReason(project.layout.isStandard ? "The proportions are already standard" : nil, way: "Drag a divider to change them")
        }
    }
}
