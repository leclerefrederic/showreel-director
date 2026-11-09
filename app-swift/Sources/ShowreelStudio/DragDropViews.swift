import AppKit
import ShowreelKit
import SwiftUI
import UniformTypeIdentifiers

/// The one drag and drop system of the workspace. Every draggable thing declares what it is (`dragSource`), every place that takes something
/// declares where it is (`dropTarget`, `dropSlots`), and the workspace resolves the pointer to a target, lights the valid ones, opens a gap
/// in a list and relays the drop to ShowreelKit (`Drops`), which owns every rule. Nothing here decides what is allowed.

/// Motion that respects the system's "Reduce motion".
enum Motion {
    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    static var spring: Animation? { reduced ? nil : .spring(response: 0.32, dampingFraction: 0.82) }
    static var quick: Animation? { reduced ? nil : .easeOut(duration: 0.14) }
    static var appear: AnyTransition { reduced ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .top)) }
    static func go<R>(_ body: () -> R) -> R { withAnimation(spring, body) }
}

enum Workspace { static let space = "workspace" }

// MARK: state

/// What is being dragged and over what. Separate from the project model, so a drag redraws only what shows it.
final class DragState: ObservableObject {
    struct Key: Hashable { let item: DragItem; let target: DropTarget }
    @Published private(set) var item: DragItem?
    @Published private(set) var hover: DropTarget?
    var regs: [DropRegistration] = []
    var verdicts: [Key: DropVerdict] = [:]
    /// The reason the pointer's target refuses what is dragged, shown again if the drag ends there.
    var refusal: String? { didSet { refusalAt = Date() } }
    private var refusalAt = Date.distantPast
    var onRefused: ((String) -> Void)?
    private var timer: Timer?
    private var idle = 0
    /// The last item and target the pointer was valid on: the release uses it when the pointer cannot be resolved again at that instant.
    var lastValid: (item: DragItem, target: DropTarget)? { session.lastValid }
    /// Everything about the drag that is not drawn: it ends in one place, `end`, whatever the outcome.
    var session = DragRun()

    func begin(_ i: DragItem) {
        verdicts = [:]; refusal = nil
        session.begin(i)
        item = i; hover = nil
        idle = 0
        timer?.invalidate()
        // SwiftUI tells us when a drag starts, not when it is abandoned: watch the mouse button.
        let t = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if NSEvent.pressedMouseButtons & 1 == 0 { self.idle += 1; if self.idle >= 2 { self.end(self.hover == nil ? .cancelled : .outsideTarget) } } else { self.idle = 0 }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        // if no drop target reports this drag soon, the log says so: the next reading needs no screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if let s = self, s.session.isActive, !s.session.seenByATarget { DragLog.shared.note("drag", "no drop target has seen the drag 1.5 s after it began") }
        }
    }

    func setHover(_ t: DropTarget?) {
        session.reported()
        guard t != hover else { return }
        Motion.go { hover = t }
    }

    func end(_ outcome: DragRun.Outcome = .outsideTarget) {
        timer?.invalidate(); timer = nil
        if session.isActive { DragLog.shared.note(session.finish(outcome)) }
        session = DragRun()
        // released over a target that refuses: say why (the red reason was already on the target; this keeps it after the release)
        if let why = refusal, Date().timeIntervalSince(refusalAt) < 2 { onRefused?(why) }
        refusal = nil
        guard item != nil || hover != nil else { return }
        Motion.go { item = nil; hover = nil }
    }

    /// The target under the pointer that takes this kind of item; when none does, the innermost target, which says why not.
    func resolve(at p: CGPoint, item: DragItem) -> DropTarget? {
        let hits = regs.filter { $0.frame.contains(p) }.sorted { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        for r in hits {
            switch r.kind {
            case .target(let t): if Drops.applies(item, to: t) { return t }
            case .slots(let before, let after, let vertical):
                let first = vertical ? p.y < r.frame.midY : p.x < r.frame.midX
                let t = first ? before : after
                if Drops.applies(item, to: t) { return t }
            }
        }
        for r in hits { if case .target(let t) = r.kind { return t } }
        return nil
    }
}

struct DropRegistration: Equatable {
    enum Kind: Equatable {
        case target(DropTarget)
        /// A row of a list: its first half is the position before it, its second half the position after.
        case slots(before: DropTarget, after: DropTarget, vertical: Bool)
    }
    var frame: CGRect
    var kind: Kind
}

struct DropRegistrationKey: PreferenceKey {
    static var defaultValue: [DropRegistration] = []
    static func reduce(value: inout [DropRegistration], nextValue: () -> [DropRegistration]) { value += nextValue() }
}

private func registration(_ kind: DropRegistration.Kind) -> some View {
    GeometryReader { g in
        Color.clear.preference(key: DropRegistrationKey.self, value: [DropRegistration(frame: g.frame(in: .named(Workspace.space)), kind: kind)])
    }
}

// MARK: modifiers

extension View {
    /// This view can be dragged: it carries `item`. `label` and `icon` draw the chip under the pointer.
    func dragSource(_ item: DragItem, label: String, icon: String, thumbnail: NSImage? = nil) -> some View { modifier(DragSource(item: item, label: label, icon: icon, thumbnail: thumbnail)) }
    /// This view takes drops on `target`: it lights up while a valid item is dragged, and says why when an invalid one is over it.
    func dropTarget(_ target: DropTarget) -> some View { modifier(DropTargetModifier(target: target)) }
    /// Registers a place as a target without drawing anything on it (an empty list's slot).
    func registers(_ target: DropTarget) -> some View { background(registration(.target(target))) }
    /// This row of a list takes drops before it (first half) or after it (second half). Pair it with a `SlotGap` before each row.
    func dropSlots(before: DropTarget, after: DropTarget, vertical: Bool = true) -> some View {
        background(registration(.slots(before: before, after: after, vertical: vertical)))
    }
}

private struct DragSource: ViewModifier {
    let item: DragItem
    let label: String
    let icon: String
    var thumbnail: NSImage?
    @EnvironmentObject var project: ProjectModel

    func body(content: Content) -> some View {
        content.onDrag {
            // the same provider as a scene's handle, which works: the plain-text token only, no other type
            let t0 = Date()
            project.dnd.begin(item)
            let provider = NSItemProvider(object: item.token as NSString)
            DragLog.shared.note("drag begin", "\(DragLog.name(of: item)) types=\(UTType.utf8PlainText.identifier) preview=\(thumbnail == nil ? "icon" : "thumbnail") setup=\(Int(Date().timeIntervalSince(t0) * 1000))ms")
            return provider
        } preview: { DragChip(label: label, icon: icon, thumbnail: thumbnail) }
    }
}

/// A row of a list that selects on a click and drags from any point of its surface. It is not a Button: a button takes the press for itself and a drag never starts from it.
/// A handle appears under the pointer and the cursor is an open hand. Every list that is a drag source (resources, the catalogue of transitions, the look's catalogues) is made of these.
struct DragRow<Content: View>: View {
    let selected: Bool
    let item: DragItem
    let label: String
    let icon: String
    var thumbnail: NSImage?
    var help = ""
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "line.3.horizontal").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary).frame(width: 12).opacity(hovering ? 1 : 0)
            content()
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.accentColor.opacity(0.2) : hovering ? Color.primary.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .onHover { h in hovering = h; if h { NSCursor.openHand.set() } else { NSCursor.arrow.set() } }          // set, never pushed: nothing to leave unbalanced
        .onTapGesture(perform: action)
        .dragSource(item, label: label, icon: icon, thumbnail: thumbnail)
        .animation(Motion.quick, value: hovering)
        .help(help)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Select", action)
    }
}

struct DragChip: View {
    let label: String
    let icon: String
    var thumbnail: NSImage?
    var body: some View {
        HStack(spacing: 6) {
            if let t = thumbnail { Image(nsImage: t).resizable().scaledToFill().frame(width: 34, height: 24).clipShape(RoundedRectangle(cornerRadius: 4)) } else { Image(systemName: icon) }
            Text(label).lineLimit(1)
        }
        .font(.callout.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.accentColor, lineWidth: 1.5))
        .frame(maxWidth: 220)
    }
}

private struct DropTargetModifier: ViewModifier {
    let target: DropTarget
    func body(content: Content) -> some View {
        content
            .background(registration(.target(target)))
            .overlay(DropGlow(target: target))
    }
}

/// The valid targets glow while something is dragged; the one under the pointer glows harder, or turns red with the reason.
struct DropGlow: View {
    let target: DropTarget
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var dnd: DragState

    var body: some View {
        if let item = dnd.item, !target.isSlot {
            let hovered = dnd.hover == target
            if hovered || Drops.applies(item, to: target) {
                let v = project.verdict(item, target)
                if v.isValid {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(hovered ? 1 : 0.55), lineWidth: hovered ? 2.5 : 1.5)
                        .background(Color.accentColor.opacity(hovered ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .allowsHitTesting(false).transition(.opacity)
                } else if hovered {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.red.opacity(0.9), lineWidth: 2)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(alignment: .bottom) {
                            Text(v.text).font(.caption2.weight(.semibold)).foregroundStyle(.white).lineLimit(2).multilineTextAlignment(.center)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.red, in: RoundedRectangle(cornerRadius: 5)).padding(3)
                        }
                        .allowsHitTesting(false).transition(.opacity)
                }
            }
        }
    }
}

/// The place a dropped row will take: closed (nothing) until the pointer is on this position with a valid item, then it opens.
struct SlotGap: View {
    let target: DropTarget
    var vertical = true
    var size: CGFloat = 30
    @EnvironmentObject var project: ProjectModel
    @EnvironmentObject var dnd: DragState

    private var open: Bool {
        guard let i = dnd.item, dnd.hover == target else { return false }
        return project.verdict(i, target).isValid
    }

    var body: some View {
        Color.clear
            .frame(width: vertical ? nil : (open ? size : 0), height: vertical ? (open ? size : 0) : nil)
            .overlay {
                if open {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(2).transition(.opacity)
                }
            }
            .background(registration(.target(target)))
            .animation(Motion.spring, value: open)
    }
}

// MARK: the one drop destination of a screen

extension View {
    /// The root of a screen with drag and drop (the workspace, the wizard): it collects where the targets are, resolves the pointer to one
    /// and relays the drop. There is one per window at a time.
    func dragDropRoot(_ project: ProjectModel) -> some View {
        coordinateSpace(name: Workspace.space)
            .onPreferenceChange(DropRegistrationKey.self) { project.dnd.regs = $0 }
            .onDrop(of: [.plainText, .fileURL], delegate: WorkspaceDropDelegate(project: project))
            .environmentObject(project.dnd)
    }
}

struct WorkspaceDropDelegate: DropDelegate {
    let project: ProjectModel
    private var dnd: DragState { project.dnd }

    private func current(_ info: DropInfo) -> DragItem? {
        if let i = dnd.item { return i }
        if info.hasItemsConforming(to: [.fileURL]) { dnd.begin(.files([])); return .files([]) }   // from the Finder
        return nil
    }

    private func sync(_ info: DropInfo) -> (item: DragItem, target: DropTarget, verdict: DropVerdict)? {
        guard let item = current(info) else { return nil }
        let t = dnd.resolve(at: info.location, item: item)
        dnd.setHover(t)
        guard let target = t else { dnd.refusal = nil; return nil }
        let v = project.verdict(item, target)
        dnd.refusal = v.isValid ? nil : v.text
        if v.isValid { dnd.session.over(target, valid: true) }
        DragLog.shared.note("hover", "\(DragLog.name(of: item)) over \(DragLog.name(of: target)): \(v.isValid ? "ok" : "refused") - \(v.text)")
        return (item, target, v)
    }

    private func types(_ info: DropInfo) -> String {
        info.itemProviders(for: [.item]).flatMap { $0.registeredTypeIdentifiers }.joined(separator: ",")
    }

    func validateDrop(info: DropInfo) -> Bool {
        dnd.session.reported()
        let ok = info.hasItemsConforming(to: [.plainText, .fileURL])
        DragLog.shared.note("validate", "\(ok ? "accepts" : "refuses") types=\(types(info))")
        return ok
    }
    func dropEntered(info: DropInfo) { DragLog.shared.note("enter", "item=\(dnd.item.map { DragLog.name(of: $0) } ?? "none")"); _ = sync(info) }
    func dropExited(info: DropInfo) { DragLog.shared.note("exit"); dnd.setHover(nil) }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let r = sync(info), r.verdict.isValid else { return DropProposal(operation: .forbidden) }
        if case .files = r.item { return DropProposal(operation: .copy) }
        return DropProposal(operation: .move)
    }

    /// The item of a drag from one of the app's own lists when the drag state was lost: its token travels as plain text.
    private func recovered(_ info: DropInfo, then use: @escaping (DragItem) -> Void) -> Bool {
        guard let p = info.itemProviders(for: [.plainText]).first else { return false }
        _ = p.loadObject(ofClass: NSString.self) { s, _ in
            let item = (s as? String).flatMap { DragItem(token: $0) }
            DispatchQueue.main.async { if let i = item { use(i) } else { project.showToast("This could not be dropped: the dragged item was not recognised.", error: true) } }
        }
        return true
    }

    func performDrop(info: DropInfo) -> Bool {
        DragLog.shared.note("release", "item=\(dnd.item.map { DragLog.name(of: $0) } ?? "none") types=\(types(info))")
        var landed = sync(info)
        // the pointer could not be resolved again at the release (or the drag state was lost): use where it last was valid, never fail silently
        if landed == nil, let last = dnd.lastValid {
            let v = project.verdict(last.item, last.target)
            if v.isValid { landed = (last.item, last.target, v); DragLog.shared.note("release", "target not resolved: using the last valid one, \(DragLog.name(of: last.target))") }
        }
        if landed == nil, dnd.item == nil { DragLog.shared.note("release", "drag state lost: reading the token"); return recovered(info) { item in
            if let t = project.dnd.regs.first(where: { $0.frame.contains(info.location) }).flatMap({ r -> DropTarget? in if case .target(let t) = r.kind { return t }; return nil }) { project.performDrop(item, on: t) }
            else { project.showToast("Nothing here takes this: drop it on a scene.", error: true) }
        } }
        guard let r = landed, r.verdict.isValid else {
            if landed == nil { DragLog.shared.note("release", "refused: no target under the pointer"); project.showToast("Nothing here takes this: drop it on a scene, a frame of the reel or in the scene's tree.", error: true) }
            else { DragLog.shared.note("release", "refused: \(landed?.verdict.text ?? "")") }
            dnd.end(landed == nil ? .outsideTarget : .refused); return false
        }
        let project = self.project
        if case .files = r.item {
            let providers = info.itemProviders(for: [.fileURL])
            var urls: [URL] = []
            let group = DispatchGroup(), lock = NSLock()
            for p in providers {
                group.enter()
                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let d = item as? Data, let u = URL(dataRepresentation: d, relativeTo: nil) { lock.lock(); urls.append(u); lock.unlock() }
                    group.leave()
                }
            }
            let target = r.target
            group.notify(queue: .main) { project.performDrop(.files(urls), on: target); project.dnd.end(.dropped) }
            return !providers.isEmpty
        }
        let ok = project.performDrop(r.item, on: r.target)
        dnd.end(ok ? .dropped : .refused)
        return ok
    }
}

// MARK: notices

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isError: Bool
    let undoable: Bool
}

/// A short notice at the bottom of the window: what a drop did (with Undo), or why it was refused.
struct ToastHost: View {
    @EnvironmentObject var project: ProjectModel

    var body: some View {
        ZStack {
            if let t = project.toast {
                HStack(spacing: 10) {
                    Image(systemName: t.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill").foregroundStyle(t.isError ? Color.orange : Color.green)
                    Text(t.text).font(.callout).lineLimit(4).fixedSize(horizontal: false, vertical: true)
                    if t.undoable && project.canUndo { Button("Undo") { project.undo() }.buttonStyle(.borderless).font(.callout.weight(.semibold)) }
                    Button { project.toast = nil } label: { Image(systemName: "xmark").font(.caption) }.buttonStyle(.borderless).help("Dismiss")
                }
                .padding(.horizontal, 14).padding(.vertical, 9).frame(maxWidth: 560)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.12)))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
                .transition(Motion.appear)
                .id(t.id)
            }
        }
        .animation(Motion.spring, value: project.toast)
    }
}

// MARK: editing in place

/// A text that becomes a field where it stands: Return or leaving the field keeps it, Escape drops it.
struct InlineEdit<Display: View>: View {
    let text: String
    var placeholder = ""
    @Binding var editing: Bool
    let commit: (String) -> Void
    @ViewBuilder let display: () -> Display
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        if editing {
            TextField(placeholder, text: $draft)
                .textFieldStyle(.roundedBorder).font(.callout)
                .focused($focused)
                .onSubmit { finish(save: true) }
                .onExitCommand { finish(save: false) }
                .onAppear { draft = text; focused = true }
                .onChange(of: focused) { f in if !f && editing { finish(save: true) } }
        } else {
            display()
        }
    }

    private func finish(save: Bool) {
        guard editing else { return }
        editing = false
        if save, draft.trimmingCharacters(in: .whitespacesAndNewlines) != text { commit(draft) }
    }
}

/// The three small things every row of a list has: a handle that says it can be dragged, a hover state, and a selection state.
struct Handle: View {
    var body: some View {
        Image(systemName: "line.3.horizontal").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary).frame(width: 12)
            .help("Drag to move")
    }
}
