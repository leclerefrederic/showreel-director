import AppKit
import ShowreelKit
import SwiftUI

// The form system (DS3): the icon and label row, the tab bar, the numeric field with its stepper, the chip. The sizes are ShowreelKit's `FormLayout`; the colours and radii the theme's.

/// An icon in a fixed-width slot, then the label: every label of a column starts at the same x.
struct IconLabel: View {
    let symbol: String
    let title: String
    @EnvironmentObject var theme: Theme
    var body: some View {
        HStack(spacing: FormLayout.labelGap) {
            Image(systemName: symbol).frame(width: FormLayout.iconSlot, alignment: .center).foregroundStyle(theme.textSecondary)
            Text(title).fontBody()
        }
    }
}

/// A row that pairs an icon and a label on the left with a control in a fixed trailing slot: the switches of a column end at the same x.
struct IconRow<Trailing: View>: View {
    let symbol: String
    let title: String
    @ViewBuilder let trailing: () -> Trailing
    var body: some View {
        HStack(spacing: FormLayout.labelGap) {
            IconLabel(symbol: symbol, title: title)
            Spacer(minLength: FormLayout.labelGap)
            trailing().frame(width: FormLayout.trailingSlot, alignment: .trailing)
        }
    }
}

/// Real tabs: an underline style, the active label in primary text with an accent underline that moves with the base duration, a hairline under the bar, a hover state, the arrow keys.
struct TabBar<Tab: Hashable & Identifiable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: (Tab) -> String
    @EnvironmentObject var theme: Theme
    @Namespace private var underline
    @State private var hovered: Tab.ID?

    var body: some View {
        HStack(spacing: theme.space(2)) {
            ForEach(tabs) { t in
                let on = t == selection
                Button { selection = t } label: {
                    Text(title(t)).fontBody(weight: on ? .semibold : .regular)
                        .foregroundStyle(on ? theme.textPrimary : hovered == t.id ? theme.textPrimary.opacity(0.85) : theme.textSecondary)
                        .padding(.vertical, 6).padding(.horizontal, 2)
                        .overlay(alignment: .bottom) { if on { Rectangle().fill(theme.accent).frame(height: 2).matchedGeometryEffect(id: "underline", in: underline) } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? t.id : nil }
                .accessibilityLabel(title(t))
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, theme.space(2))
        .overlay(alignment: .bottom) { Rectangle().fill(theme.hairline).frame(height: 1) }
        .animation(Motion.select, value: selection)
        .accessibilityElement(children: .contain).tabBarTrait()
        .focusable().onMoveCommand { d in
            guard var m = TabBarModel(tabs: tabs.map { $0.id }, selected: selection.id) else { return }
            if d == .right { m.next() } else if d == .left { m.previous() } else { return }
            if let t = tabs.first(where: { $0.id == m.selected }) { selection = t }
        }
    }
}

/// A text field with a stepper at its right end for a number of seconds: chevrons (click, hold to repeat), the Up and Down arrow keys (Option: fine, Shift: coarse), typing validated inline,
/// an out-of-range value clamped with a message. The rule is ShowreelKit's `NumericField`.
struct StepperField: View {
    @Binding var text: String
    var rule = NumericField.duration
    var onStep: () -> Void = {}
    var onCommit: () -> Void = {}
    var width: CGFloat = 120
    @EnvironmentObject var theme: Theme
    @State private var message: String?
    @StateObject private var hold = HoldRepeat()
    @FocusState private var focused: Bool

    private var value: Double { rule.typed(text).result?.value ?? rule.minimum }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                TextField("3", text: $text).textFieldStyle(.plain).padding(.leading, 8).frame(height: FormLayout.fieldHeight)
                    .focused($focused).onSubmit { settle(); onCommit() }
                VStack(spacing: 0) { chevron("chevron.up", up: true); chevron("chevron.down", up: false) }.padding(.trailing, 4)
            }
            .frame(width: width).background(theme.raised, in: RoundedRectangle(cornerRadius: FormLayout.fieldRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FormLayout.fieldRadius, style: .continuous).stroke(message != nil ? theme.warning : focused ? theme.accent : theme.hairline, lineWidth: focused || message != nil ? 2 : 1))
            .onChange(of: focused) { f in if !f { settle() } }
            .background(StepperKeys(active: focused) { up, m in step(up: up, modifier: m) })
            .onDisappear { hold.stop() }
            if let m = message { Text(m).fontSmall().foregroundStyle(theme.warning) }
        }
    }

    private func chevron(_ symbol: String, up: Bool) -> some View {
        let can = rule.typed(text).result.map { rule.canStep($0.value, up: up) } ?? true
        return Image(systemName: symbol).font(.system(size: 11, weight: .bold)).frame(width: 18, height: FormLayout.fieldHeight / 2)
            .foregroundStyle(can ? theme.textSecondary : theme.textFaint).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in if !hold.isRunning { step(up: up); hold.start { step(up: up) } } }.onEnded { _ in hold.stop() })
            .help(up ? "Longer. Hold to repeat. Option: 0.1 s, Shift: 5 s." : "Shorter. Hold to repeat. Option: 0.1 s, Shift: 5 s.")
            .accessibilityLabel(up ? "Increase" : "Decrease")
    }

    private func step(up: Bool, modifier: NumericField.Modifier? = nil) {
        let flags = NSEvent.modifierFlags
        let r = rule.stepped(value, up: up, modifier ?? (flags.contains(.option) ? .fine : flags.contains(.shift) ? .coarse : .normal))
        text = rule.display(r.value); message = r.message; onStep()
    }

    /// A typed value is checked when the field is left or Return is pressed: clamped with its message, never silently.
    private func settle() {
        let t = rule.typed(text)
        if let r = t.result { if r.message != nil { text = rule.display(r.value); message = r.message } else { message = nil } } else if !text.isEmpty { message = t.error }
    }
}

/// One choice chip (30 s to 90 s, the formats, the languages): selected, hover and disabled states from the tokens.
struct ChipStyle: ButtonStyle {
    let selected: Bool
    @EnvironmentObject var theme: Theme
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.fontBody(weight: selected ? .medium : .regular).foregroundStyle(selected ? theme.accent : theme.textPrimary)
            .padding(.horizontal, theme.space(2)).frame(height: FormLayout.chipHeight)
            .background(selected ? theme.selected : configuration.isPressed ? theme.strong : theme.raised, in: RoundedRectangle(cornerRadius: FormLayout.fieldRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: FormLayout.fieldRadius, style: .continuous).stroke(selected ? theme.accent : theme.hairline, lineWidth: 1))
            .opacity(enabled ? 1 : 0.5)
    }
}


extension View {
    /// The tab bar role for VoiceOver where the system has it (macOS 14); the selected trait of each tab carries the meaning elsewhere.
    @ViewBuilder func tabBarTrait() -> some View { if #available(macOS 14.0, *) { accessibilityAddTraits(.isTabBar) } else { self } }
}

/// The "Project" button of every inspector header: it opens the Project right panel exactly as the rail's Project entry does (one operation, `ProjectModel.openRail`).
struct ProjectButton: View {
    @EnvironmentObject var project: ProjectModel
    var body: some View {
        Button { project.openRail(.project) } label: { Label("Project", systemImage: IconRole.railProject.symbol) }
            .buttonStyle(.borderless).help("Project settings").accessibilityLabel("Project settings")
    }
}

/// Up and Down while the field has focus, on macOS 13 (a text field swallows the SwiftUI key commands): a local key monitor, live only while `active`, maps the key through
/// `NumericField.keyStep` (Option: fine, Shift: coarse) and consumes it.
struct StepperKeys: NSViewRepresentable {
    let active: Bool
    let onStep: (Bool, NumericField.Modifier) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ v: NSView, context: Context) {
        context.coordinator.onStep = onStep
        if active { context.coordinator.start() } else { context.coordinator.stop() }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    static func dismantleNSView(_ v: NSView, coordinator: Coordinator) { coordinator.stop() }

    final class Coordinator {
        var onStep: (Bool, NumericField.Modifier) -> Void = { _, _ in }
        private var monitor: Any?
        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
                guard let s = self, let k = NumericField.keyStep(keyCode: e.keyCode, option: e.modifierFlags.contains(.option), shift: e.modifierFlags.contains(.shift)) else { return e }
                s.onStep(k.up, k.modifier); return nil
            }
        }
        func stop() { if let m = monitor { NSEvent.removeMonitor(m); monitor = nil } }
        deinit { stop() }
    }
}
