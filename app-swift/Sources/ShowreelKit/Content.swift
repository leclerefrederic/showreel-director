import Foundation

public enum ControlLevel: String, CaseIterable, Sendable {
    case auto, guided, precise
    public var title: String { rawValue.capitalized }
    public var help: String {
        switch self {
        case .auto: return "Only the words are yours: the AI decides colours and animations."
        case .guided: return "You fix what matters (colour); the AI decides the rest."
        case .precise: return "Everything is fixed, item by item."
        }
    }
}

/// The colours of a palette by role, in the order the palette is stored.
public enum PaletteRole: String, CaseIterable, Sendable {
    case background, text, accent, accent2
    public var index: Int { PaletteRole.allCases.firstIndex(of: self)! }
    public var title: String { self == .accent2 ? "Accent 2" : rawValue.capitalized }
    public static func parse(_ s: String) -> PaletteRole? {
        PaletteRole(rawValue: s.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: ""))
    }
}

extension ShowreelFile {
    /// How an item is coloured: `auto` (the AI decides), a palette `role`, or a `custom` hex. Anything but auto is fixed.
    public struct ContentColor: Codable, Equatable {
        public var mode: String
        public var role: String?
        public var hex: String?
        public var unknown: [String: JSONValue] = [:]
        public init(mode: String = "auto", role: String? = nil, hex: String? = nil) { self.mode = mode; self.role = role; self.hex = hex }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            mode = try c.decodeIfPresent(String.self, forKey: "mode") ?? "auto"
            role = try c.decodeIfPresent(String.self, forKey: "role")
            hex = try c.decodeIfPresent(String.self, forKey: "hex")
            unknown = try Keep.unknown(decoder, known: ["mode", "role", "hex"])
        }
        public func encode(to encoder: Encoder) throws { try Keep.encode(encoder, fields: [("mode", mode), ("role", role), ("hex", hex)], unknown: unknown) }
        public var isFixed: Bool { mode != "auto" }
        public var text: String { mode == "role" ? (role.flatMap(PaletteRole.parse)?.title ?? role ?? "?") : mode == "custom" ? (hex ?? "?") : "auto" }
    }

    /// How an item moves: `auto` (the AI decides) or a named `effect` of the library with its parameters. An effect is fixed.
    public struct ContentAnimation: Codable, Equatable {
        public var mode: String
        public var effect: String?
        public var params: JSONValue?
        public var unknown: [String: JSONValue] = [:]
        public init(mode: String = "auto", effect: String? = nil, params: JSONValue? = nil) { self.mode = mode; self.effect = effect; self.params = params }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            mode = try c.decodeIfPresent(String.self, forKey: "mode") ?? "auto"
            effect = try c.decodeIfPresent(String.self, forKey: "effect")
            params = try c.decodeIfPresent(JSONValue.self, forKey: "params")
            unknown = try Keep.unknown(decoder, known: ["mode", "effect", "params"])
        }
        public func encode(to encoder: Encoder) throws { try Keep.encode(encoder, fields: [("mode", mode), ("effect", effect), ("params", params)], unknown: unknown) }
        public var isFixed: Bool { mode != "auto" }
        public var paramsText: String {
            guard case .object(let o)? = params else { return "" }
            return o.sorted { $0.key < $1.key }.map { k, v in
                switch v { case .string(let s): return "\(k)=\(s)"; case .number(let n): return "\(k)=\(ProjectDocs.seconds(n))"; case .bool(let b): return "\(k)=\(b)"; default: return k }
            }.joined(separator: ", ")
        }
        public var text: String { mode == "effect" ? (effect ?? "?") + (paramsText.isEmpty ? "" : " (\(paramsText))") : "auto" }
    }

    /// One thing a scene contains: words, an image or logo, a sound or voice. Its place in the list is its processing priority.
    public struct ContentItem: Codable, Equatable, Identifiable {
        public var id: String
        public var type: String              // text, image, audio (shape comes later)
        public var text: String?             // the words (text)
        public var resource: String?         // the asset id (image, audio)
        public var color: ContentColor
        public var animation: ContentAnimation
        public var instruction: String?
        public var unknown: [String: JSONValue] = [:]

        public init(id: String, type: String, text: String? = nil, resource: String? = nil, color: ContentColor = ContentColor(),
                    animation: ContentAnimation = ContentAnimation(), instruction: String? = nil) {
            self.id = id; self.type = type; self.text = text; self.resource = resource; self.color = color; self.animation = animation; self.instruction = instruction
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            id = try c.decode(String.self, forKey: "id")
            type = try c.decodeIfPresent(String.self, forKey: "type") ?? "text"
            text = try c.decodeIfPresent(String.self, forKey: "text")
            resource = try c.decodeIfPresent(String.self, forKey: "resource")
            color = try c.decodeIfPresent(ContentColor.self, forKey: "color") ?? ContentColor()
            animation = try c.decodeIfPresent(ContentAnimation.self, forKey: "animation") ?? ContentAnimation()
            instruction = try c.decodeIfPresent(String.self, forKey: "instruction")
            unknown = try Keep.unknown(decoder, known: ["id", "type", "text", "resource", "color", "animation", "instruction"])
        }
        public func encode(to encoder: Encoder) throws {
            try Keep.encode(encoder, fields: [("id", id), ("type", type), ("text", text), ("resource", resource), ("color", color),
                                              ("animation", animation), ("instruction", instruction)], unknown: unknown)
        }
        /// The item as an edit, to make the same one again (duplicating a scene).
        public var edit: ContentEdit {
            ContentEdit(type: type, text: text, resource: resource, color: type == "text" ? (color.mode == "role" ? color.role : color.mode == "custom" ? color.hex : "auto") : nil,
                        animation: type == "audio" ? nil : (animation.mode == "effect" ? animation.effect : "auto"), params: animation.mode == "effect" && !animation.paramsText.isEmpty ? animation.paramsText : nil, instruction: instruction)
        }
        public var hasInstruction: Bool { !(instruction ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
        public var allAuto: Bool { !color.isFixed && !animation.isFixed && !hasInstruction }
    }
}

public enum ContentRules {
    public static let types = ["text", "image", "audio"]
    static let imageAssets: Set<String> = ["logo", "icon", "illus", "img", "shot", "photo", "video", "frames"]
    static let audioAssets: Set<String> = ["audio", "voice", "sfx"]

    public static func title(_ type: String) -> String { type == "text" ? "Text" : type == "image" ? "Image or logo" : type == "audio" ? "Sound or voice" : type.capitalized }

    /// Resource types an item type accepts.
    public static func accepts(_ type: String, asset: String) -> Bool { type == "image" ? imageAssets.contains(asset) : type == "audio" ? audioAssets.contains(asset) : false }

    /// The defaults of a new item from the control level: auto fixes nothing, guided fixes the colour of words, precise fixes everything.
    public static func defaults(type: String, level: ControlLevel, in f: ShowreelFile) -> (color: ShowreelFile.ContentColor, animation: ShowreelFile.ContentAnimation) {
        var color = ShowreelFile.ContentColor(), anim = ShowreelFile.ContentAnimation()
        if level != .auto, type == "text" { color = .init(mode: "role", role: "text") }
        if level == .precise, type != "audio" {
            let pack = f.decisions.effectsPack ?? f.decisions.moods?.first ?? ""
            let name = Look.packs().first { $0.name == pack }?.effects.first { Look.effects().contains($0) } ?? "Fade"
            anim = .init(mode: "effect", effect: name)
        }
        return (color, anim)
    }

    public static func nextID(_ items: [ShowreelFile.ContentItem]) -> String {
        "c\((items.compactMap { Int($0.id.dropFirst()) }.max() ?? 0) + 1)"
    }
}

extension ShowreelFile {
    /// The control level a scene works at: its own, or the project's, or auto.
    public func controlLevel(for scene: Scene) -> ControlLevel {
        ControlLevel(rawValue: scene.controlLevel ?? "") ?? ControlLevel(rawValue: parameters.controlLevel ?? "") ?? .auto
    }

    /// The hex of a palette role for a scene (its own palette, or the project's), nil when the palette does not define it.
    public func paletteHex(_ role: String?, for scene: Scene) -> String? {
        guard let r = role.flatMap(PaletteRole.parse) else { return nil }
        let p = effective(.palette, for: scene).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return r.index < p.count ? p[r.index] : nil
    }

    /// The `after` that moves an item by `delta` places in its scene (nil when it would not move).
    public func contentPosition(scene id: String, item: String, by delta: Int) -> String? {
        guard let s = scenes.first(where: { $0.id == id }), let i = s.content.firstIndex(where: { $0.id == item }) else { return nil }
        var ids = s.content.map { $0.id }
        ids.remove(at: i)
        let to = min(max(i + delta, 0), ids.count)
        guard to != i else { return nil }
        return to == 0 ? "start" : ids[to - 1]
    }
}

extension ShowreelFile.Scene {
    /// Keeps the rule "the first text item holds the scene's text" after the content changed.
    mutating func syncMasterText() { text = content.first { $0.type == "text" }?.text ?? "" }

    /// The scene's text was changed directly (the wizard, a re-import, update_scene): the first text item follows, or is made.
    mutating func setMasterText(_ new: String) {
        if let i = content.firstIndex(where: { $0.type == "text" }) {
            if new.isEmpty, content[i].allAuto { content.remove(at: i) } else { content[i].text = new }
        } else if !new.isEmpty {
            content.insert(ShowreelFile.ContentItem(id: ContentRules.nextID(content), type: "text", text: new), at: 0)
        }
        text = new
    }
}

/// What the user (or the copilot) says about one item. Every field is optional: nil leaves it as it is.
public struct ContentEdit: Equatable, Sendable {
    public var type: String?
    public var text: String?
    public var resource: String?
    /// "auto", a palette role (background, text, accent, accent2) or a #RRGGBB hex.
    public var color: String?
    /// "auto" or the name of an effect of the library.
    public var animation: String?
    /// Parameters of the effect, "key=value, key=value".
    public var params: String?
    public var instruction: String?
    public init(type: String? = nil, text: String? = nil, resource: String? = nil, color: String? = nil, animation: String? = nil, params: String? = nil, instruction: String? = nil) {
        self.type = type; self.text = text; self.resource = resource; self.color = color; self.animation = animation; self.params = params; self.instruction = instruction
    }
}

public enum ContentOp: Equatable, Sendable {
    /// A new item at `after` (an item ID, "start", or the end when nil).
    case add(ContentEdit, after: String?)
    case update(item: String, ContentEdit)
    case remove(item: String)
    /// Priority: put the item after another one ("start" for first).
    case move(item: String, after: String)
}

extension ProjectStore {
    private static func parseColor(_ s: String) throws -> ShowreelFile.ContentColor {
        let v = s.trimmingCharacters(in: .whitespaces)
        if v.isEmpty || v.lowercased() == "auto" { return .init() }
        if let r = PaletteRole.parse(v) { return .init(mode: "role", role: r.rawValue) }
        if EnginePalette.isHex(v) { return .init(mode: "custom", hex: v.uppercased()) }
        throw AgentError.msg("\"\(v)\" is not a colour: use auto, a palette role (background, text, accent, accent2) or a #RRGGBB hex")
    }

    private static func parseAnimation(_ name: String, params: String?, keeping old: ShowreelFile.ContentAnimation) throws -> ShowreelFile.ContentAnimation {
        let v = name.trimmingCharacters(in: .whitespaces)
        if v.isEmpty || v.lowercased() == "auto" { return .init() }
        guard let canon = Look.effects().first(where: { $0.caseInsensitiveCompare(v) == .orderedSame }) else {
            throw AgentError.msg("unknown effect \"\(v)\": it is not in the library (references/effects-index.md)")
        }
        var a = ShowreelFile.ContentAnimation(mode: "effect", effect: canon, params: old.effect == canon ? old.params : nil)
        a.unknown = old.unknown
        if let p = params { a.params = try parseParams(p) }
        return a
    }

    static func parseParams(_ s: String) throws -> JSONValue? {
        let parts = ParameterKey.list(s, lowercase: false)
        if parts.isEmpty { return nil }
        var o: [String: JSONValue] = [:]
        for p in parts {
            let kv = p.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard kv.count == 2, !kv[0].isEmpty else { throw AgentError.msg("a parameter is written key=value (\"\(p)\")") }
            o[kv[0]] = Double(kv[1]).map { JSONValue.number($0) } ?? .string(kv[1])
        }
        return .object(o)
    }

    private func describe(_ i: ShowreelFile.ContentItem, _ rows: [AssetRow]) -> String {
        var s = i.type == "text" ? "\u{201C}\(i.text ?? "")\u{201D}" : (rows.first { $0.id == i.resource }?.name ?? i.resource ?? "(no resource)")
        s += " · colour \(i.color.text) · animation \(i.animation.text)"
        if i.hasInstruction { s += " · \u{201C}\(i.instruction!)\u{201D}" }
        return s
    }

    /// The plan for a content operation: the card, and the closure that writes it. A change to the content is a change to the film.
    func planContent(_ sceneID: String, _ op: ContentOp) throws -> (card: OperationCard, run: () throws -> Void) {
        guard let f = loadShowreel() else { throw AgentError.msg("there is no readable showreel.json: create the project first") }
        guard let si = f.scenes.firstIndex(where: { $0.id == sceneID }) else { throw AgentError.msg("unknown scene \(sceneID)") }
        var g = f
        var s = g.scenes[si]
        var rows = Assets.load(self)
        var changes: [Change] = []
        var linked: String?
        let tag = { (i: ShowreelFile.ContentItem) in "\(sceneID) \(i.id)" }

        func validate(_ item: inout ShowreelFile.ContentItem, _ e: ContentEdit, adding: Bool) throws {
            if let t = e.type, !adding, t != item.type { throw AgentError.msg("an item's type does not change: remove it and add another") }
            if let t = e.text {
                guard item.type == "text" else { throw AgentError.msg("only a text item has words") }
                item.text = t.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let r = e.resource {
                guard item.type != "text" else { throw AgentError.msg("a text item has words, not a resource") }
                guard let a = rows.first(where: { $0.id == r }) else { throw AgentError.msg("unknown asset \(r)") }
                guard ContentRules.accepts(item.type, asset: a.type) else { throw AgentError.msg("\(a.id) is a \(a.type): an \(item.type) item takes " + (item.type == "image" ? "a logo, icon, illustration, image, shot, photo, video or frames" : "an audio, voice or sfx file")) }
                guard a.status != "excluded" else { throw AgentError.msg("\(a.id) is excluded: it cannot be used") }
                item.resource = r
                if !a.sceneIDs.contains(sceneID) { linked = r }
            }
            if let c = e.color {
                guard item.type == "text" else { throw AgentError.msg("a colour applies to text only (an image or a sound keeps its own)") }
                item.color = try Self.parseColor(c)
            }
            if e.animation != nil || e.params != nil {
                guard item.type != "audio" else { throw AgentError.msg("a sound has no animation") }
                if let a = e.animation { item.animation = try Self.parseAnimation(a, params: e.params, keeping: item.animation) }
                else {
                    guard item.animation.mode == "effect" else { throw AgentError.msg("parameters need an effect: name one first") }
                    item.animation.params = try Self.parseParams(e.params ?? "")
                }
            }
            if let i = e.instruction { let v = i.trimmingCharacters(in: .whitespacesAndNewlines); item.instruction = v.isEmpty ? nil : v }
            if item.type == "text", (item.text ?? "").isEmpty, adding { throw AgentError.msg("a text item needs its words") }
            if item.type != "text", item.resource == nil, adding { throw AgentError.msg("an \(item.type) item needs a resource (an asset id from get_state)") }
        }

        var title = ""
        switch op {
        case .add(let e, let after):
            let type = e.type ?? "text"
            guard ContentRules.types.contains(type) else { throw AgentError.msg("an item is text, image or audio (shapes come later)") }
            let d = ContentRules.defaults(type: type, level: f.controlLevel(for: s), in: f)
            var item = ShowreelFile.ContentItem(id: ContentRules.nextID(s.content), type: type, color: d.color, animation: d.animation)
            var e2 = e; e2.type = nil
            try validate(&item, e2, adding: true)
            var at = s.content.count
            if let a = after, !a.isEmpty {
                if a == "start" { at = 0 } else if let i = s.content.firstIndex(where: { $0.id == a }) { at = i + 1 } else { throw AgentError.msg("no item \(a) in \(sceneID) to put it after") }
            }
            s.content.insert(item, at: at)
            changes.append(Change("\(tag(item)) (\(item.type), priority \(at + 1))", "(none)", describe(item, rows)))
            title = "Add \(item.type) item to \(sceneID)"
        case .update(let id, let e):
            guard let i = s.content.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("no item \(id) in \(sceneID)") }
            let before = s.content[i]
            var item = before
            try validate(&item, e, adding: false)
            guard item != before else { throw AgentError.msg("no change for \(sceneID) \(id)") }
            s.content[i] = item
            func line(_ label: String, _ a: String, _ b: String) { if a != b { changes.append(Change("\(tag(item)) \(label)", a, b)) } }
            line("words", before.text ?? "(none)", item.text ?? "(none)")
            line("resource", before.resource ?? "(none)", item.resource ?? "(none)")
            line("colour", before.color.text + (before.color.isFixed ? " (fixed)" : ""), item.color.text + (item.color.isFixed ? " (fixed)" : ""))
            line("animation", before.animation.text + (before.animation.isFixed ? " (fixed)" : ""), item.animation.text + (item.animation.isFixed ? " (fixed)" : ""))
            line("instruction", before.instruction ?? "(none)", item.instruction ?? "(none)")
            if changes.isEmpty { changes.append(Change(tag(item), describe(before, rows), describe(item, rows))) }
            title = "Edit \(item.type) item \(id) of \(sceneID)"
        case .remove(let id):
            guard let i = s.content.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("no item \(id) in \(sceneID)") }
            let gone = s.content.remove(at: i)
            changes.append(Change(tag(gone), describe(gone, rows), "(removed)"))
            title = "Remove \(gone.type) item \(id) from \(sceneID)"
        case .move(let id, let after):
            guard let i = s.content.firstIndex(where: { $0.id == id }) else { throw AgentError.msg("no item \(id) in \(sceneID)") }
            guard after == "start" || (after != id && s.content.contains { $0.id == after }) else { throw AgentError.msg("no item \(after) in \(sceneID) to move after") }
            let it = s.content.remove(at: i)
            let to = after == "start" ? 0 : s.content.firstIndex { $0.id == after }! + 1
            guard to != i else { throw AgentError.msg("no change: \(id) already is there") }
            s.content.insert(it, at: to)
            changes.append(Change("Priority of \(tag(it))", "\(i + 1)", "\(to + 1)"))
            title = "Change the priority of item \(id) in \(sceneID)"
        }
        let textBefore = s.text
        s.syncMasterText()
        if s.text != textBefore { changes.append(Change("\(sceneID) on-screen text", textBefore.isEmpty ? "(empty)" : textBefore, s.text.isEmpty ? "(empty)" : s.text)) }
        if s.status == "ok" { changes.append(Change("Status", "ok", "open")); s.status = "open" }   // a changed scene is reviewed again
        g.scenes[si] = s
        var assetsChanged = false
        if let r = linked, let k = rows.firstIndex(where: { $0.id == r }) {
            rows[k].scene = (rows[k].sceneIDs + [sceneID]).joined(separator: ", "); assetsChanged = true
            changes.append(Change("Linked assets", "(not linked to \(sceneID))", "\(r) linked to \(sceneID)"))
        }
        let saved = rows
        return finish(title: title, changes: changes, from: f, to: g, extraFilmChange: !s.archived && g.film.contains { $0.id == sceneID } && assetsChanged) {
            if assetsChanged { try Assets.save(saved, self) }
        }
    }
}
