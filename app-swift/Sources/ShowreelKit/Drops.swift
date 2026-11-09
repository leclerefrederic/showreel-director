import Foundation

/// What the user is dragging. The same value travels from any list of the app to any target, as a short text token.
public enum DragItem: Hashable, Sendable {
    case resource(String)                         // an asset ID
    case background(String)                       // a background ID of the engine
    case look(String)                             // a look package ID
    case palette(String)                          // a look package whose palette is taken
    case effect(String)                           // an effect of the library
    case pack(String)                             // an effects pack (a whole-project choice: it has no drop target)
    case transition(String)                       // a scene transition of the library
    case scene(String)                            // a scene of the library or of the reel
    case content(scene: String, item: String)     // one content item of a scene
    case files([URL])                             // files from the Finder (empty while the drag is only hovering: the URLs come at the drop)

    public var token: String {
        switch self {
        case .resource(let s): return "studio:resource:" + s
        case .background(let s): return "studio:background:" + s
        case .look(let s): return "studio:look:" + s
        case .palette(let s): return "studio:palette:" + s
        case .effect(let s): return "studio:effect:" + s
        case .pack(let s): return "studio:pack:" + s
        case .transition(let s): return "studio:transition:" + s
        case .scene(let s): return "studio:scene:" + s
        case .content(let s, let i): return "studio:content:" + s + "|" + i
        case .files: return "studio:files"
        }
    }

    public init?(token: String) {
        let p = token.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard p.count >= 2, p[0] == "studio" else { return nil }
        let v = p.count == 3 ? p[2] : ""
        switch p[1] {
        case "resource": self = .resource(v)
        case "background": self = .background(v)
        case "look": self = .look(v)
        case "palette": self = .palette(v)
        case "effect": self = .effect(v)
        case "pack": self = .pack(v)
        case "transition": self = .transition(v)
        case "scene": self = .scene(v)
        case "content":
            let q = v.split(separator: "|", maxSplits: 1).map(String.init)
            guard q.count == 2 else { return nil }
            self = .content(scene: q[0], item: q[1])
        case "files": self = .files([])
        default: return nil
        }
    }

    /// The item a row of the Look tab stands for (kind is the tab: looks, palettes, fonts, backgrounds, effects, transitions).
    public static func library(kind: String, id: String) -> DragItem? {
        switch kind {
        case "looks": return .look(id)
        case "palettes": return id == "project" ? nil : .palette(id)
        case "backgrounds": return .background(id)
        case "effects": return id.hasPrefix("pack:") ? .pack(String(id.dropFirst(5))) : .effect(id)
        case "transitions": return .transition(id)
        default: return nil          // a font goes to the project's look: it has no drop target on a scene yet
        }
    }
}

/// A place an item can be dropped. A slot is a position in a list: `before` is the row it lands in front of (nil: at the end).
public enum DropTarget: Hashable, Sendable {
    case scene(String)
    case sceneNode(scene: String, group: SceneGroup, node: String?)
    case contentItem(scene: String, item: String)
    case contentSlot(scene: String, before: String?)
    case reelSlot(before: String?)
    case librarySlot(before: String?)
    case assetSlot(before: String?)
    case marker(from: String)
    case resourceList
    /// The music lane under the reel: an audio resource, or a file, becomes the film's music.
    case musicLane

    /// A position in a list (the gap that opens while dragging), as opposed to a thing.
    public var isSlot: Bool {
        switch self { case .contentSlot, .reelSlot, .librarySlot, .assetSlot: return true; default: return false }
    }
}

public enum DropVerdict: Equatable, Sendable {
    case ok(String)
    case refused(String)
    public var isValid: Bool { if case .ok = self { return true }; return false }
    public var text: String { switch self { case .ok(let s), .refused(let s): return s } }
}

public struct DropResult: Equatable, Sendable {
    public let title: String
    /// Something the user should know even though the drop worked (a file that needs attention and was not linked).
    public let notice: String?
    /// What to select afterwards.
    public let scene: String?
    public let item: String?
}

/// What dropping something somewhere does, and why it is refused when it is. The views only draw and relay: the rules are here, and the
/// result of a drop is always a typed operation (or a group of them, which undo takes back in one step).
public enum Drops {
    /// Why this kind of item never goes on this kind of target; nil when the pair makes sense (whether the drop is valid is `verdict`).
    public static func kindRefusal(_ item: DragItem, _ target: DropTarget) -> String? {
        let t = normalized(item, target)
        switch item {
        case .resource:
            switch t { case .scene, .contentItem, .contentSlot, .assetSlot, .musicLane: return nil; default: return "A resource goes on a scene, in a scene's content list or in the resources list" }
        case .background, .look, .palette:
            if case .scene = t { return nil }
            return "A background or a look goes on a scene"
        case .effect:
            if case .contentItem = t { return nil }
            return "An effect goes on a content item"
        case .pack: return "An effects pack applies to the whole project: drop one of its effects on a content item"
        case .transition:
            if case .marker = t { return nil }
            return "A transition goes on the marker between two scenes"
        case .scene:
            switch t { case .reelSlot, .librarySlot: return nil; default: return "A scene goes in the reel or in the library's list" }
        case .content:
            if case .contentSlot = t { return nil }
            return "An item moves inside its scene's content list"
        case .files:
            switch t { case .scene, .contentSlot, .resourceList, .assetSlot, .musicLane: return nil; default: return "Files go on a scene, in a scene's content list or in the resources list" }
        }
    }

    /// A node of a scene's tree stands for the scene, except the node of a content item, which takes an effect.
    static func normalized(_ item: DragItem, _ target: DropTarget) -> DropTarget {
        guard case .sceneNode(let s, _, let node) = target else { return target }
        if case .effect = item, let n = node, n.hasPrefix("item.") { return .contentItem(scene: s, item: String(n.dropFirst(5))) }
        return .scene(s)
    }

    public static func applies(_ item: DragItem, to target: DropTarget) -> Bool { kindRefusal(item, target) == nil }

    /// Whether the drop is allowed, with a short title for what it does or the reason it is refused. Nothing is changed.
    public static func verdict(_ item: DragItem, on target: DropTarget, store: ProjectStore) -> DropVerdict {
        do { return .ok(try run(item, target, store: store, execute: false).title) }
        catch { return .refused(error.localizedDescription) }
    }

    /// Does the drop, as typed operations. Throws the same refusal `verdict` gives.
    @discardableResult
    public static func drop(_ item: DragItem, on target: DropTarget, store: ProjectStore) throws -> DropResult {
        try run(item, target, store: store, execute: true)
    }

    // MARK: the rules

    private static func need(_ store: ProjectStore) throws -> ShowreelFile {
        guard let f = store.loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        return f
    }

    /// The row a new position follows: nil before the first, the one before `target`, or the last (target nil).
    private static func after(_ ids: [String], before target: String?) -> String? {
        if let t = target { guard let i = ids.firstIndex(of: t) else { return nil }; return i == 0 ? "start" : ids[i - 1] }
        return ids.last
    }

    /// A resource that can be used in a scene.
    private static func usable(_ r: AssetRow) throws {
        if r.status == "hold" { throw AgentError.msg("\(r.name) needs attention first: \(r.notes.isEmpty ? "fix it or accept the risk in the Resources tab" : r.notes)") }
        if r.status == "excluded" { throw AgentError.msg("\(r.name) is excluded: it cannot be used") }
    }

    private static let unusedTypes: Set<String> = ["doc", "data", "note", "misc"]

    private static func itemType(for asset: AssetRow) throws -> String {
        if let t = ContentRules.elementType(for: asset.type) { return t }
        throw AgentError.msg("a \(asset.type) cannot be a content item (an image, a logo or a sound can): link it to the scene instead")
    }

    private static func run(_ item: DragItem, _ dropTarget: DropTarget, store: ProjectStore, execute: Bool) throws -> DropResult {
        if let why = kindRefusal(item, dropTarget) { throw AgentError.msg(why) }
        let target = normalized(item, dropTarget)
        func op(_ o: ProjectOperation) throws { if execute { try store.apply(o) } else { _ = try store.plan(o) } }
        let f = try need(store)
        let rows = Assets.load(store)
        func sceneNamed(_ id: String) throws -> ShowreelFile.Scene {
            guard let s = f.scenes.first(where: { $0.id == id }) else { throw AgentError.msg("unknown scene \(id)") }
            guard !s.archived else { throw AgentError.msg("\(s.id) is archived: bring it back first") }
            return s
        }
        func asset(_ id: String) throws -> AssetRow {
            guard let r = rows.first(where: { $0.id == id }) else { throw AgentError.msg("unknown asset \(id)") }
            return r
        }

        switch (item, target) {
        case (.resource(let id), .scene(let sid)):
            let r = try asset(id), s = try sceneNamed(sid)
            try usable(r)
            if unusedTypes.contains(r.type) { throw AgentError.msg("a \(r.type) file is not used in a scene") }
            let linked = rows.filter { $0.sceneIDs.contains(sid) }.map { $0.id }
            if linked.contains(id) { throw AgentError.msg("\(r.name) is already linked to \(s.id)") }
            try op(.scene(id: sid, SceneEdit(assets: (linked + [id]).joined(separator: ", "))))
            return DropResult(title: "Link \(r.name) to \(s.id)", notice: nil, scene: sid, item: nil)

        case (.resource(let id), .contentSlot(let sid, let before)):
            let r = try asset(id), s = try sceneNamed(sid)
            try usable(r)
            let type = try itemType(for: r)
            try op(.content(scene: sid, .add(ContentEdit(type: type, resource: id), after: after(s.content.map { $0.id }, before: before))))
            return DropResult(title: "Add \(r.name) to \(s.id) as \(type == "image" ? "an image" : "a sound")", notice: nil, scene: sid, item: nil)

        case (.resource(let id), .contentItem(let sid, let iid)):
            let r = try asset(id), s = try sceneNamed(sid)
            try usable(r)
            guard let it = s.content.first(where: { $0.id == iid }) else { throw AgentError.msg("no item \(iid) in \(sid)") }
            guard it.type != "text" else { throw AgentError.msg("a text item has words: drop the resource between the items to add it") }
            try op(.content(scene: sid, .update(item: iid, ContentEdit(resource: id))))
            return DropResult(title: "Use \(r.name) for \(sid) \(iid)", notice: nil, scene: sid, item: iid)

        case (.resource(let id), .assetSlot(let before)):
            let r = try asset(id)
            guard before != id, let a = after(rows.map { $0.id }.filter { $0 != id }, before: before) else { throw AgentError.msg("no change: \(r.name) already is there") }
            try op(.moveAsset(id: id, after: a))
            return DropResult(title: "Move \(r.name)", notice: nil, scene: nil, item: nil)

        case (.resource(let id), .musicLane):
            let r = try asset(id)
            guard r.type == "audio" else { throw AgentError.msg("\(r.name) is a \(r.type), not music: the music is an audio file") }
            try op(.track(asset: id))
            return DropResult(title: "Use \(r.name) as the music", notice: nil, scene: nil, item: nil)

        case (.background(let id), .scene(let sid)):
            _ = try sceneNamed(sid)
            try op(Catalogue.operation(.background, choice: id, target: .scene(sid)))
            return DropResult(title: "Use the \(id) background in \(sid)", notice: nil, scene: sid, item: nil)

        case (.look(let pid), .scene(let sid)), (.palette(let pid), .scene(let sid)):
            _ = try sceneNamed(sid)
            guard let p = LookPackages.all().first(where: { $0.id == pid }) else { throw AgentError.msg("unknown look \(pid)") }
            var changes = p.decisions.filter { DecisionKey.sceneKeys.contains($0.key) && !$0.value.isEmpty }
            var what = "the \(p.name) look"
            if case .palette = item { changes = changes.filter { $0.key == .palette }; what = "the \(p.name) palette" }
            try op(.sceneLook(id: sid, changes))
            return DropResult(title: "Give \(sid) \(what)", notice: nil, scene: sid, item: nil)

        case (.effect(let name), .contentItem(let sid, let iid)):
            _ = try sceneNamed(sid)
            try op(Catalogue.operation(.effect, choice: name, target: .item(scene: sid, item: iid)))
            return DropResult(title: "Animate \(sid) \(iid) with \(name)", notice: nil, scene: sid, item: iid)

        case (.transition(let name), .marker(let from)):
            try op(Catalogue.operation(.transition, choice: name, target: .marker(from: from)))
            return DropResult(title: "Use \(name) after \(from)", notice: nil, scene: from, item: nil)

        case (.scene(let id), .librarySlot(let before)):
            let s = try sceneNamed(id)
            guard let a = f.position(of: id, before: before) else { throw AgentError.msg("no change: \(s.id) already is there") }
            try op(.moveScene(id: id, after: a, montage: nil))
            return DropResult(title: "Move \(s.id)", notice: nil, scene: id, item: nil)

        case (.scene(let id), .reelSlot(let before)):
            let s = try sceneNamed(id)
            let on = f.storyboards.first?.items.first { $0.scene == id }?.enabled ?? false
            if on {
                guard let a = f.position(of: id, before: before) else { throw AgentError.msg("no change: \(s.id) already is there") }
                try op(.moveScene(id: id, after: a, montage: nil))
                return DropResult(title: "Move \(s.id) in the film", notice: nil, scene: id, item: nil)
            }
            if !execute { _ = try store.plan(.sceneEnabled(id: id, enabled: true, montage: nil)); return DropResult(title: "Put \(s.id) in the film", notice: nil, scene: id, item: nil) }
            try store.transaction("Put \(s.id) in the film") {
                try store.apply(.sceneEnabled(id: id, enabled: true, montage: nil))
                if let g = store.loadShowreel(), let a = g.position(of: id, before: before) { try store.apply(.moveScene(id: id, after: a, montage: nil)) }
            }
            return DropResult(title: "Put \(s.id) in the film", notice: nil, scene: id, item: nil)

        case (.content(let from, let iid), .contentSlot(let sid, let before)):
            guard from == sid else { throw AgentError.msg("an item stays in its scene: duplicate it to put a copy elsewhere") }
            let s = try sceneNamed(sid)
            guard s.content.contains(where: { $0.id == iid }) else { throw AgentError.msg("no item \(iid) in \(sid)") }
            let others = s.content.map { $0.id }.filter { $0 != iid }
            guard before != iid, let a = after(others, before: before) else { throw AgentError.msg("no change: \(iid) already is there") }
            try op(.content(scene: sid, .move(item: iid, after: a)))
            return DropResult(title: "Change the priority of \(sid) \(iid)", notice: nil, scene: sid, item: iid)

        case (.files(let urls), _):
            return try dropFiles(urls, target, store: store, execute: execute, file: f)

        default:
            throw AgentError.msg("this does not go there")
        }
    }

    private static func dropFiles(_ urls: [URL], _ target: DropTarget, store: ProjectStore, execute: Bool, file f: ShowreelFile) throws -> DropResult {
        if case .musicLane = target {
            let title = urls.count == 1 ? "Use \(urls[0].lastPathComponent) as the music" : "Use the file as the music"
            guard execute else { return DropResult(title: title, notice: nil, scene: nil, item: nil) }
            guard let first = urls.first else { throw AgentError.msg("nothing to add") }
            var used = ""
            try store.transaction(title) {
                let added = try Assets.add([first], to: store)
                guard let a = added.first else { throw AgentError.msg("nothing to add: folders and hidden files are skipped") }
                guard a.type == "audio" else { throw AgentError.msg("\(a.name) is a \(a.type), not music: the music is an audio file") }
                if a.status == "hold" { throw AgentError.msg("\(a.name) needs attention first (\(a.notes)): it was added to the resources, not used as the music") }
                try store.apply(.asset(id: a.id, status: .approved, note: nil, licence: nil, scenes: nil))     // dropped as the music: that is the user's choice
                try store.apply(.track(asset: a.id))
                used = a.name
            }
            return DropResult(title: "Use \(used) as the music", notice: nil, scene: nil, item: nil)
        }
        var sceneID: String?
        var slot: String??
        switch target {
        case .scene(let s): sceneID = s
        case .contentSlot(let s, let b): sceneID = s; slot = .some(b)
        default: break
        }
        if let s = sceneID {
            guard let sc = f.scenes.first(where: { $0.id == s }) else { throw AgentError.msg("unknown scene \(s)") }
            guard !sc.archived else { throw AgentError.msg("\(s) is archived: bring it back first") }
            guard !sc.isLocked else { throw AgentError.msg(SceneLock.reason(s)) }
        }
        let n = urls.count
        let title = (n == 1 ? "Add \(urls[0].lastPathComponent)" : n == 0 ? "Add the files" : "Add \(n) files") + (sceneID.map { " to \($0)" } ?? " to the resources")
        guard execute else { return DropResult(title: title, notice: nil, scene: sceneID, item: nil) }
        guard n > 0 else { throw AgentError.msg("nothing to add") }
        var notices: [String] = []
        var lastItem: String?
        try store.transaction(title) {
            let added = try Assets.add(urls, to: store)
            guard !added.isEmpty else { throw AgentError.msg("nothing to add: folders and hidden files are skipped") }
            guard let s = sceneID else {
                if case .assetSlot(let before) = target {
                    let ids = Set(added.map { $0.id })
                    let rows = Assets.load(store).map { $0.id }.filter { !ids.contains($0) }
                    var prev = after(rows, before: before) ?? "start"
                    for r in added { try store.apply(.moveAsset(id: r.id, after: prev)); prev = r.id }
                }
                return
            }
            var link: [String] = []
            var prevItem: String? = nil
            if case .some(let b) = slot {
                let ids = f.scenes.first { $0.id == s }?.content.map { $0.id } ?? []
                prevItem = after(ids, before: b)
            }
            for r in added {
                if r.status == "hold" { notices.append("\(r.name) needs attention (\(r.notes)): added to the resources, not used in \(s)"); continue }
                if unusedTypes.contains(r.type) { notices.append("\(r.name) is a \(r.type) file: added to the resources, not used in a scene"); continue }
                if slot != nil, let type = try? itemType(for: r) {
                    try store.apply(.content(scene: s, .add(ContentEdit(type: type, resource: r.id), after: prevItem)))
                    if let last = store.loadShowreel()?.scenes.first(where: { $0.id == s })?.content.last(where: { $0.resource == r.id }) { prevItem = last.id; lastItem = last.id }
                } else { link.append(r.id) }
            }
            if !link.isEmpty {
                let current = Assets.load(store).filter { $0.sceneIDs.contains(s) }.map { $0.id }
                try store.apply(.scene(id: s, SceneEdit(assets: (current + link).joined(separator: ", "))))
            }
        }
        return DropResult(title: title, notice: notices.isEmpty ? nil : notices.joined(separator: "\n"), scene: sceneID, item: lastItem)
    }
}

extension ProjectStore {
    /// A copy of a scene right after it in the montage: its fields, its name with " copy", its control level and the rest of its content.
    /// One undo step. Returns the new scene's ID.
    @discardableResult
    public func duplicateScene(_ id: String) throws -> String {
        guard let f = loadShowreel(), let s = f.scenes.first(where: { $0.id == id }) else { throw AgentError.msg("unknown scene \(id)") }
        let new = SceneRules.nextID(f.scenes)
        try transaction("Duplicate \(s.id)") {
            var e = SceneEdit(duration: s.duration.map { ProjectDocs.seconds($0) }, text: s.text, visual: s.visual, feeling: s.feeling, handoff: s.handoff,
                              inCuts: s.inCuts, after: s.id, controlLevel: s.controlLevel, name: s.name.map { String(($0 + " copy").prefix(SceneRules.nameLimit)) })
            e.status = nil
            try apply(.addScene(id: new, e))
            var skippedFirstText = false
            for it in s.content {
                if it.type == "text", !skippedFirstText { skippedFirstText = true; continue }
                try apply(.content(scene: new, .add(it.edit, after: nil)))
            }
        }
        return new
    }
}
