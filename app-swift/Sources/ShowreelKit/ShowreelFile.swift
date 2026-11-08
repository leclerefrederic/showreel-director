import Foundation

/// `showreel.json`, schema version 1 (docs/studio-spec.md, sections 3.1 and 5.1b).
/// Keys this version does not know are kept in `unknown` at every level, so a newer skill never loses data.
public struct ShowreelFile: Codable, Equatable {
    public static let fileName = "showreel.json"
    public static let currentSchema = 1
    public static let gateKeys = ["interview", "assets", "style", "storyboard", "review", "build", "verify", "publish"]

    public struct Fonts: Codable, Equatable, Sendable {
        public var titles: String?
        public var text: String?
        public var unknown: [String: JSONValue] = [:]
        public init(titles: String? = nil, text: String? = nil) { self.titles = titles; self.text = text }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            titles = try c.decodeIfPresent(String.self, forKey: "titles")
            text = try c.decodeIfPresent(String.self, forKey: "text")
            unknown = try Keep.unknown(decoder, known: ["titles", "text"])
        }
        public func encode(to encoder: Encoder) throws {
            try Keep.encode(encoder, fields: [("titles", titles), ("text", text)], unknown: unknown)
        }
    }

    public struct Background: Codable, Equatable {
        public var id: String?
        public var mood: String?
        public var unknown: [String: JSONValue] = [:]
        public init(id: String? = nil, mood: String? = nil) { self.id = id; self.mood = mood }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            id = try c.decodeIfPresent(String.self, forKey: "id")
            mood = try c.decodeIfPresent(String.self, forKey: "mood")
            unknown = try Keep.unknown(decoder, known: ["id", "mood"])
        }
        public func encode(to encoder: Encoder) throws {
            try Keep.encode(encoder, fields: [("id", id), ("mood", mood)], unknown: unknown)
        }
    }

    public struct Track: Codable, Equatable {
        public var file: String?
        public var bpm: Double?
        public var unknown: [String: JSONValue] = [:]
        public init(file: String? = nil, bpm: Double? = nil) { self.file = file; self.bpm = bpm }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            file = try c.decodeIfPresent(String.self, forKey: "file")
            bpm = try c.decodeIfPresent(Double.self, forKey: "bpm")
            unknown = try Keep.unknown(decoder, known: ["file", "bpm"])
        }
        public func encode(to encoder: Encoder) throws {
            try Keep.encode(encoder, fields: [("file", file), ("bpm", bpm)], unknown: unknown)
        }
    }

    /// What the Project block holds: free text answers to the interview's first round.
    public struct Parameters: Codable, Equatable {
        public var audience: String?
        public var message: String?
        public var tone: String?
        public var constraints: String?
        public var unknown: [String: JSONValue] = [:]
        public init() {}
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            audience = try c.decodeIfPresent(String.self, forKey: "audience")
            message = try c.decodeIfPresent(String.self, forKey: "message")
            tone = try c.decodeIfPresent(String.self, forKey: "tone")
            constraints = try c.decodeIfPresent(String.self, forKey: "constraints")
            unknown = try Keep.unknown(decoder, known: ["audience", "message", "tone", "constraints"])
        }
        public func encode(to encoder: Encoder) throws {
            try Keep.encode(encoder, fields: [("audience", audience), ("message", message), ("tone", tone), ("constraints", constraints)], unknown: unknown)
        }
    }

    public struct Decisions: Codable, Equatable {
        public var palette: [String]?
        public var fonts: Fonts?
        public var background: Background?
        public var moods: [String]?
        public var effectsPack: String?
        public var formats: [String]?
        public var duration: Double?
        public var track: Track?
        public var unknown: [String: JSONValue] = [:]
        public init() {}
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            palette = try c.decodeIfPresent([String].self, forKey: "palette")
            fonts = try c.decodeIfPresent(Fonts.self, forKey: "fonts")
            background = try c.decodeIfPresent(Background.self, forKey: "background")
            moods = try c.decodeIfPresent([String].self, forKey: "moods")
            effectsPack = try c.decodeIfPresent(String.self, forKey: "effectsPack")
            formats = try c.decodeIfPresent([String].self, forKey: "formats")
            duration = try c.decodeIfPresent(Double.self, forKey: "duration")
            track = try c.decodeIfPresent(Track.self, forKey: "track")
            unknown = try Keep.unknown(decoder, known: ["palette", "fonts", "background", "moods", "effectsPack", "formats", "duration", "track"])
        }
        public func encode(to encoder: Encoder) throws {
            try Keep.encode(encoder, fields: [("palette", palette), ("fonts", fonts), ("background", background), ("moods", moods),
                                              ("effectsPack", effectsPack), ("formats", formats), ("duration", duration), ("track", track)],
                            unknown: unknown)
        }
    }

    /// One scene of the library. The ID is stable: never reused, never renumbered. Where it plays, and when, belongs to a montage.
    /// `archived` is the tombstone: the scene leaves the lists, its ID stays reserved. DITCH archives it.
    public struct Scene: Codable, Equatable, Identifiable {
        public var id: String
        public var duration: Double?            // the scene's own length in seconds
        public var text: String
        public var texts: [String: String]      // one text per reel language column
        public var visual: String
        public var feeling: String
        public var handoff: String              // the note of the passage to the next scene
        public var inCuts: String
        public var extra: [String: String]      // any other storyboard column
        public var status: String               // open, ok, modify, ditched
        public var note: String
        public var archived: Bool
        public var unknown: [String: JSONValue] = [:]
        /// Phase T kept start and end inside the scene. Read once to build the montage, never written back.
        var legacyStart: Double?
        var legacyEnd: Double?

        public init(id: String, duration: Double? = nil, text: String = "", texts: [String: String] = [:], visual: String = "",
                    feeling: String = "", handoff: String = "", inCuts: String = "", extra: [String: String] = [:],
                    status: String = "open", note: String = "", archived: Bool = false) {
            self.id = id; self.duration = duration; self.text = text; self.texts = texts; self.visual = visual
            self.feeling = feeling; self.handoff = handoff; self.inCuts = inCuts; self.extra = extra; self.status = status; self.note = note
            self.archived = archived
        }
        public static let statuses = ["open", "ok", "modify", "ditched"]
        static let keys: Set<String> = ["id", "duration", "text", "texts", "visual", "feeling", "handoff", "inCuts", "extra", "status", "note", "archived", "start", "end"]
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            id = try c.decode(String.self, forKey: "id")
            duration = try c.decodeIfPresent(Double.self, forKey: "duration")
            legacyStart = try c.decodeIfPresent(Double.self, forKey: "start")
            legacyEnd = try c.decodeIfPresent(Double.self, forKey: "end")
            if duration == nil, let a = legacyStart, let b = legacyEnd, b > a { duration = b - a }
            text = try c.decodeIfPresent(String.self, forKey: "text") ?? ""
            texts = try c.decodeIfPresent([String: String].self, forKey: "texts") ?? [:]
            visual = try c.decodeIfPresent(String.self, forKey: "visual") ?? ""
            feeling = try c.decodeIfPresent(String.self, forKey: "feeling") ?? ""
            handoff = try c.decodeIfPresent(String.self, forKey: "handoff") ?? ""
            inCuts = try c.decodeIfPresent(String.self, forKey: "inCuts") ?? ""
            extra = try c.decodeIfPresent([String: String].self, forKey: "extra") ?? [:]
            status = try c.decodeIfPresent(String.self, forKey: "status") ?? "open"
            note = try c.decodeIfPresent(String.self, forKey: "note") ?? ""
            archived = try c.decodeIfPresent(Bool.self, forKey: "archived") ?? (status == "ditched")
            unknown = try Keep.unknown(decoder, known: Self.keys)
        }
        public func encode(to encoder: Encoder) throws {
            try Keep.encode(encoder, fields: [("id", id), ("duration", duration), ("text", text), ("texts", texts), ("visual", visual),
                                              ("feeling", feeling), ("handoff", handoff), ("inCuts", inCuts), ("extra", extra),
                                              ("status", status), ("note", note), ("archived", archived)], unknown: unknown)
        }
    }

    /// The passage from a scene to the next one, in a montage. The default is a cut.
    public struct Transition: Codable, Equatable {
        public var type: String
        public var duration: Double?
        public var params: JSONValue?
        public var unknown: [String: JSONValue] = [:]
        public init(type: String = "cut", duration: Double? = nil, params: JSONValue? = nil) { self.type = type; self.duration = duration; self.params = params }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            type = try c.decodeIfPresent(String.self, forKey: "type") ?? "cut"
            duration = try c.decodeIfPresent(Double.self, forKey: "duration")
            params = try c.decodeIfPresent(JSONValue.self, forKey: "params")
            unknown = try Keep.unknown(decoder, known: ["type", "duration", "params"])
        }
        public func encode(to encoder: Encoder) throws {
            try Keep.encode(encoder, fields: [("type", type), ("duration", duration), ("params", params)], unknown: unknown)
        }
    }

    /// One place of a scene in a montage. `start` and `end` are optional manual overrides: without them the times follow from the order.
    public struct MontageItem: Codable, Equatable {
        public var scene: String
        public var enabled: Bool
        public var start: Double?
        public var end: Double?
        public var transition: Transition
        public var unknown: [String: JSONValue] = [:]
        public init(scene: String, enabled: Bool = true, start: Double? = nil, end: Double? = nil, transition: Transition = Transition()) {
            self.scene = scene; self.enabled = enabled; self.start = start; self.end = end; self.transition = transition
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            scene = try c.decode(String.self, forKey: "scene")
            enabled = try c.decodeIfPresent(Bool.self, forKey: "enabled") ?? true
            start = try c.decodeIfPresent(Double.self, forKey: "start")
            end = try c.decodeIfPresent(Double.self, forKey: "end")
            transition = try c.decodeIfPresent(Transition.self, forKey: "transition") ?? Transition()
            unknown = try Keep.unknown(decoder, known: ["scene", "enabled", "start", "end", "transition"])
        }
        public func encode(to encoder: Encoder) throws {
            try Keep.encode(encoder, fields: [("scene", scene), ("enabled", enabled), ("start", start), ("end", end), ("transition", transition)], unknown: unknown)
        }
    }

    /// A film cut from the scene library: the order of the scenes, which ones are on, the passages between them.
    public struct Montage: Codable, Equatable, Identifiable {
        public var id: String
        public var name: String
        public var format: String?
        public var items: [MontageItem]
        public var unknown: [String: JSONValue] = [:]
        public init(id: String = "main", name: String = "Master", format: String? = nil, items: [MontageItem] = []) {
            self.id = id; self.name = name; self.format = format; self.items = items
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            id = try c.decodeIfPresent(String.self, forKey: "id") ?? "main"
            name = try c.decodeIfPresent(String.self, forKey: "name") ?? "Master"
            format = try c.decodeIfPresent(String.self, forKey: "format")
            items = try c.decodeIfPresent([MontageItem].self, forKey: "items") ?? []
            unknown = try Keep.unknown(decoder, known: ["id", "name", "format", "items"])
        }
        public func encode(to encoder: Encoder) throws {
            try Keep.encode(encoder, fields: [("id", id), ("name", name), ("format", format), ("items", items)], unknown: unknown)
        }
    }

    /// Who wrote the file. The skill's export writes `skill`; the app writes `studio` from its first save and then owns the file.
    public struct Origin: Codable, Equatable {
        public var tool: String?
        public var exportedAt: String?
        public var files: [String]?
        public var unknown: [String: JSONValue] = [:]
        public init(tool: String? = nil, exportedAt: String? = nil, files: [String]? = nil) { self.tool = tool; self.exportedAt = exportedAt; self.files = files }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)
            tool = try c.decodeIfPresent(String.self, forKey: "tool")
            exportedAt = try c.decodeIfPresent(String.self, forKey: "exportedAt")
            files = try c.decodeIfPresent([String].self, forKey: "files")
            unknown = try Keep.unknown(decoder, known: ["tool", "exportedAt", "files"])
        }
        public func encode(to encoder: Encoder) throws {
            try Keep.encode(encoder, fields: [("tool", tool), ("exportedAt", exportedAt), ("files", files)], unknown: unknown)
        }
    }

    public var schema: Int
    public var name: String
    public var created: String
    public var conversationLanguage: String?
    public var reelLanguages: [String]
    public var step: String
    public var parameters: Parameters
    public var decisions: Decisions
    public var gates: [String: String]       // interview ... publish: passed or open
    public var scenes: [Scene]               // the library, in creation order
    public var storyboards: [Montage]         // the films cut from it; the first one is the master
    public var origin: Origin?
    public var unknown: [String: JSONValue] = [:]

    public init(name: String, created: String = ShowreelFile.today(), conversationLanguage: String? = nil,
                reelLanguages: [String] = [], step: String = "start") {
        self.schema = Self.currentSchema
        self.name = name
        self.created = created
        self.conversationLanguage = conversationLanguage
        self.reelLanguages = reelLanguages
        self.step = step
        self.parameters = Parameters()
        self.decisions = Decisions()
        self.gates = [:]
        self.scenes = []
        self.storyboards = [Montage()]
    }

    static let keys: Set<String> = ["schema", "name", "created", "conversationLanguage", "reelLanguages", "step", "parameters", "decisions", "gates", "scenes", "storyboards", "origin"]

    // A hand-edited or exported file may lack keys: every key but the schema falls back to a default.
    // `scenes` is an ordered array; the phase A form, a dictionary of review states keyed by ID, is read too.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicKey.self)
        schema = try c.decodeIfPresent(Int.self, forKey: "schema") ?? Self.currentSchema
        name = try c.decodeIfPresent(String.self, forKey: "name") ?? ""
        created = try c.decodeIfPresent(String.self, forKey: "created") ?? Self.today()
        conversationLanguage = try c.decodeIfPresent(String.self, forKey: "conversationLanguage")
        reelLanguages = try c.decodeIfPresent([String].self, forKey: "reelLanguages") ?? []
        step = try c.decodeIfPresent(String.self, forKey: "step") ?? "start"
        parameters = try c.decodeIfPresent(Parameters.self, forKey: "parameters") ?? Parameters()
        decisions = try c.decodeIfPresent(Decisions.self, forKey: "decisions") ?? Decisions()
        gates = try c.decodeIfPresent([String: String].self, forKey: "gates") ?? [:]
        origin = try c.decodeIfPresent(Origin.self, forKey: "origin")
        if let list = try? c.decode([Scene].self, forKey: "scenes") {
            scenes = list
        } else if let legacy = try? c.decode([String: LegacyScene].self, forKey: "scenes") {
            scenes = legacy.keys.sorted().map { Scene(id: $0, status: legacy[$0]?.status ?? "open", note: legacy[$0]?.note ?? "") }
        } else {
            scenes = []
        }
        if let m = try? c.decode([Montage].self, forKey: "storyboards"), !m.isEmpty {
            storyboards = m
        } else {
            storyboards = [Self.migratedMontage(scenes, format: decisions.formats?.first)]   // phase T and phase A files: one montage from the scenes
        }
        for i in scenes.indices { scenes[i].legacyStart = nil; scenes[i].legacyEnd = nil }
        unknown = try Keep.unknown(decoder, known: Self.keys)
    }

    /// The montage of a file that has none: the scenes in their order. A scene that was ditched is archived and off. Where a scene's
    /// phase T start differs from where the order puts it, the start is kept as a manual override, so no timing is lost.
    static func migratedMontage(_ scenes: [Scene], format: String?) -> Montage {
        var m = Montage(format: format)
        var t = 0.0
        for s in scenes {
            let off = s.status == "ditched" || s.archived
            var item = MontageItem(scene: s.id, enabled: !off)
            if !off {
                if let a = s.legacyStart, abs(a - t) > 0.001 { item.start = a; t = a }
                t += s.duration ?? 0
            }
            m.items.append(item)
        }
        return m
    }

    private struct LegacyScene: Decodable { var status: String?; var note: String? }

    public func encode(to encoder: Encoder) throws {
        try Keep.encode(encoder, fields: [("schema", schema), ("name", name), ("created", created), ("conversationLanguage", conversationLanguage),
                                          ("reelLanguages", reelLanguages), ("step", step), ("parameters", parameters), ("decisions", decisions),
                                          ("gates", gates), ("scenes", scenes), ("storyboards", storyboards), ("origin", origin)], unknown: unknown)
    }

    public static func today() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Stable output (sorted keys, indented) so that diffs in the history stay small.
    public func encoded() throws -> String {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try e.encode(self), as: UTF8.self) + "\n"
    }

    public static func decode(_ text: String) throws -> ShowreelFile {
        try JSONDecoder().decode(ShowreelFile.self, from: Data(text.utf8))
    }

    public var isStudioOwned: Bool { origin?.tool == "studio" }
}
