import AppKit
import ShowreelKit
import SwiftUI

// The theme of the app: ShowreelKit's `DesignTokens` mapped to SwiftUI, and the shared control styles. It is the ONE place that holds a colour literal or a text size. A view reads the
// theme from the SwiftUI environment (`@EnvironmentObject var theme: Theme`, or through a modifier below), never a constant, so that a later phase can swap the tokens at run time.

final class Theme: ObservableObject {
    @Published var tokens: DesignTokens
    /// The motion tokens in force (a skin may change them): `Motion` reads them.
    @Published var motion = MotionTokens.standard { didSet { Motion.tokens = motion } }

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

    /// The Film strip's colours (DS2): the values it had, one for one, now read from the tokens.
    var strip: StripPalette { StripPalette(theme: self) }
    /// The orange of a note that needs a look and the colour of a lock that is on (the Storyboard list).
    var mark: Color { color(tokens.mark) }
    var lockOn: Color { color(tokens.lockOn) }

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

/// The one text field: it fills the width of its pane, has the height and radius of `FormLayout`, a focus ring in the accent, an error state (`.fieldError`) and a dimmed disabled state.
struct ThemedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View { Styled(content: configuration) }
    private struct Styled<C: View>: View {
        let content: C
        @EnvironmentObject var theme: Theme
        @Environment(\.isEnabled) private var enabled
        @Environment(\.fieldError) private var error
        @Environment(\.fieldVerticalPadding) private var vertical
        @FocusState private var focused: Bool
        var body: some View {
            content.textFieldStyle(.plain).fontBody().focused($focused).padding(.horizontal, 8)
                .padding(.vertical, vertical)
                .frame(minHeight: FormLayout.fieldHeight).frame(maxWidth: .infinity)
                .background(theme.raised, in: RoundedRectangle(cornerRadius: FormLayout.fieldRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: FormLayout.fieldRadius, style: .continuous)
                    .stroke(error != nil ? theme.danger : focused ? theme.accent : theme.hairline, lineWidth: focused || error != nil ? 2 : 1))
                .opacity(enabled ? 1 : 0.55)
        }
    }
}

/// Inner vertical padding of a text field that can grow to several lines (PT1): the text does not sit against its top and bottom border. Zero for the single-line fields.
private struct FieldVerticalPaddingKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues { var fieldVerticalPadding: CGFloat { get { self[FieldVerticalPaddingKey.self] } set { self[FieldVerticalPaddingKey.self] = newValue } } }

private struct FieldErrorKey: EnvironmentKey { static let defaultValue: String? = nil }
extension EnvironmentValues { var fieldError: String? { get { self[FieldErrorKey.self] } set { self[FieldErrorKey.self] = newValue } } }

extension View {
    /// The error state of a field: a danger border and its message next to the field.
    func fieldError(_ message: String?) -> some View { modifier(FieldErrorModifier(message: message)) }
}

private struct FieldErrorModifier: ViewModifier {
    let message: String?
    @EnvironmentObject var theme: Theme
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            content.environment(\.fieldError, message)
            if let m = message { Text(m).fontSmall().foregroundStyle(theme.danger) }
        }
    }
}

/// A multi-line field that grows with its text between `FormLayout.minLines` and `maxLines`; its scroll bar shows only past the limit (no empty track on two lines).
struct GrowingTextEditor: View {
    @Binding var text: String
    var placeholder = ""
    @EnvironmentObject var theme: Theme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.fieldError) private var error
    @FocusState private var focused: Bool
    @State private var width: CGFloat = 320

    var body: some View {
        let g = FormLayout.areaLines(for: text, width: Double(width) - 16)
        TextEditor(text: $text).font(.body).focused($focused).scrollContentBackground(.hidden)
            .scrollIndicators(g.scrolls ? .automatic : .hidden)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .frame(height: CGFloat(g.lines) * 18 + 12)
            .background(theme.raised, in: RoundedRectangle(cornerRadius: FormLayout.fieldRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FormLayout.fieldRadius, style: .continuous).stroke(error != nil ? theme.danger : focused ? theme.accent : theme.hairline, lineWidth: focused || error != nil ? 2 : 1))
            .overlay(alignment: .topLeading) { if text.isEmpty && !placeholder.isEmpty { Text(placeholder).fontBody().foregroundStyle(theme.textFaint).padding(.horizontal, 9).padding(.vertical, 6).allowsHitTesting(false) } }
            .background(GeometryReader { p in Color.clear.onAppear { width = p.size.width }.onChange(of: p.size.width) { width = $0 } })
            .opacity(enabled ? 1 : 0.55)
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
        .onMoveCommand { d in                                         // the arrows move inside the group and wrap; Tab goes from one group to the other
            guard let f = focused else { focused = RailEntry.allCases.first; return }
            if d == .down { focused = f.neighbour(1) } else if d == .up { focused = f.neighbour(-1) }
        }
    }

    private var clap: ClapIndicator { ClapIndicator(working: chat.running || project.activity.clap != nil, proposals: project.activity.proposals.count) }

    @ViewBuilder private func entry(_ e: RailEntry, _ state: RailState) -> some View {
        let ind = clap
        let marked = state.inspectorMarked
        let why = e.unavailable(workspaceOpen: project.workspaceOpen, progressLine: project.showreel.map { ProjectSetup.progress($0).line } ?? "")
        RailButton(entry: e, selected: state.isSelected(e), marked: marked, clap: ind, ringed: focused == e, reduceMotion: reduceMotion) { project.openRail(e) }
            .focused($focused, equals: e)
            .help(e.tooltip(clap: ind, marked: marked, unavailable: why))
            .accessibilityLabel(e.label(clap: ind, marked: marked))
            .accessibilityHint(e.help)
            .accessibilityAddTraits(state.isSelected(e) ? [.isButton, .isSelected] : .isButton)
            .disabledWithReason(why?.reason, way: why?.way)
    }
}

/// One entry of the rail, with the same states for the six: rest, hover (the raised surface), pressed (the selected surface), selected (the selected surface, the accent and its
/// outline), keyboard focus (a ring in the accent), and the badges that apply (Clap's pulse, dot and count, the Inspector's mark). The change of state uses the quick motion token and
/// is static under Reduce motion (`Motion.quick` is nil then).
private struct RailButton: View {
    let entry: RailEntry, selected: Bool, marked: Bool, clap: ClapIndicator, ringed: Bool, reduceMotion: Bool
    let action: () -> Void
    @EnvironmentObject var theme: Theme
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: entry.role.symbol).font(.system(size: 17, weight: .regular)).frame(height: 22)
                        .modifier(ClapPulse(active: entry == .clap && clap.motion(reduceMotion: reduceMotion) == .pulse))
                    if entry == .clap, clap.motion(reduceMotion: reduceMotion) == .dot { Circle().fill(theme.accent).frame(width: 7, height: 7).offset(x: 3, y: -1) }
                    if entry == .clap, let n = clap.badge {
                        Text("\(n)").fontSmall(weight: .medium).foregroundStyle(theme.onAccent).padding(.horizontal, 4).background(theme.warning, in: Capsule()).offset(x: 10, y: -5)
                    }
                    if entry == .inspector, marked { Circle().fill(theme.accent).frame(width: 7, height: 7).offset(x: 4, y: -1) }
                }
                Text(entry.title).fontSmall(weight: selected ? .medium : .regular)
            }
            .foregroundStyle(selected ? theme.accent : theme.textSecondary)
            .frame(width: 52).padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(RailButtonStyle(selected: selected, hovering: hovering, ringed: ringed))
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: selected)
        .animation(Motion.quick, value: hovering)
    }
}

private struct RailButtonStyle: ButtonStyle {
    let selected: Bool, hovering: Bool, ringed: Bool
    @EnvironmentObject var theme: Theme

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.rMedium, style: .continuous)
        configuration.label
            .background(selected || configuration.isPressed ? theme.selected : hovering ? theme.raised : Color.clear, in: shape)
            .overlay(shape.stroke(selected ? theme.accent.opacity(0.55) : Color.clear, lineWidth: 1))
            .overlay(shape.inset(by: -1).stroke(ringed ? theme.accent : Color.clear, lineWidth: 2))
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


/// What the Film strip draws with: lanes, frames, lines and the white and black it lays over a picture (with the opacity each use had). Views ask for a name, never a literal.
struct StripPalette {
    let theme: Theme
    private var s: DesignTokens.Strip { theme.tokens.strip }
    var bg: Color { theme.color(s.bg) }
    var lane: Color { theme.color(s.lane) }
    var ruler: Color { theme.color(s.ruler) }
    var frame: Color { theme.color(s.frame) }
    var wave: Color { theme.color(s.wave) }
    var playhead: Color { theme.color(s.playhead) }
    var cutFill: Color { theme.color(s.cutFill) }
    var line: Color { white(s.line) }
    var text: Color { white(s.text) }
    var dim: Color { white(s.dim) }
    var gridBeat: Color { white(s.gridBeat) }
    var gridBar: Color { white(s.gridBar) }
    var gridSection: Color { section(s.gridSection) }
    var chip: Color { black(s.chip) }
    func sectionColor(_ i: Int) -> Color { let c = s.sectionColors; return c.isEmpty ? section(s.sectionTint) : theme.color(c[i % c.count]).opacity(s.sectionTint) }
    var thumbBackdrop: Color { black(s.thumbBackdrop) }
    var perforation: Color { white(s.perforation) }
    var cap: Color { white(s.cap) }
    var chipHeavy: Color { black(s.chipHeavy) }
    var gradient: [Color] { [black(s.gradientTop), .clear, black(s.gradientBottom)] }
    /// The text size of the strip: nothing under the smallest size of the type scale.
    var font: CGFloat { CGFloat(theme.tokens.sizes.small) }
    func white(_ a: Double = 1) -> Color { theme.color(s.white).opacity(a) }
    func black(_ a: Double = 1) -> Color { theme.color(s.black).opacity(a) }
    func section(_ a: Double = 1) -> Color { theme.color(s.section).opacity(a) }
}

// A colour from and to a hex value (the colour pickers store hex). Colours are made here and nowhere else.
extension Color {
    init(hex: String) {
        let c = EnginePalette.rgb(EnginePalette.isHex(hex) ? hex : "#808080")
        self.init(.sRGB, red: c[0] / 255, green: c[1] / 255, blue: c[2] / 255, opacity: 1)
    }
    var hexString: String {
        let n = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        return String(format: "#%02X%02X%02X", Int((n.redComponent * 255).rounded()), Int((n.greenComponent * 255).rounded()), Int((n.blueComponent * 255).rounded()))
    }
}

