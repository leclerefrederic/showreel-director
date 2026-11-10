import Foundation

// MARK: which version is read

extension Versions {
    /// The last version that works: the most recent one that was built and tested with success. A folder left by a build that was cancelled or failed has no page and
    /// is never chosen; a version whose last test was red is not chosen either. A version built before results were kept counts when its page exists.
    public static func working(_ store: ProjectStore) -> String? {
        list(store).last { hasDist(store, $0) && (SceneModules.result(version: $0, store: store)?.ok ?? true) }
    }

    /// The folders newer than the last working version that never got a page: what a build that was stopped or failed leaves behind.
    public static func incomplete(_ store: ProjectStore) -> [String] {
        let w = working(store).flatMap { Int($0.dropFirst()) } ?? 0
        return list(store).filter { !hasDist(store, $0) && (Int($0.dropFirst()) ?? 0) > w }
    }

    /// The version a film is assembled into: the newest folder (it completes an incomplete version, or brings the working one up to date).
    public static func target(_ store: ProjectStore) -> String? { list(store).last }
}

// MARK: the state of the film

/// The state of the film, computed from fingerprints and the files, never stored by hand.
public enum FilmBuild {
    public enum State: String, Equatable, Sendable { case legacy, neverAssembled, upToDate, stale }

    public struct Status: Equatable, Sendable {
        public let state: State
        /// The version that is assembled into (the newest folder), and the one that is read (the last that works).
        public let target: String?
        public let playable: String?
        public let ungenerated: [String]
        public let staleReasons: [String]
        public let incomplete: [String]
        public let scenes: [String: SceneModules.Status]

        /// The scenes whose file is missing or out of date: what "Generate" is about (the ones that are locked cannot be generated, but they are still counted).
        public var toGenerate: [String] { ungenerated + scenes.filter { $0.value.state == .stale }.keys.sorted() }
        public static var empty: Status { Status(state: .neverAssembled, target: nil, playable: nil, ungenerated: [], staleReasons: [], incomplete: [], scenes: [:]) }

        /// The counter of the reel's header.
        public var counter: String {
            if state == .legacy { return "Old format" }
            if !toGenerate.isEmpty { return "\(toGenerate.count) scene\(toGenerate.count == 1 ? "" : "s") to generate" }
            switch state {
            case .neverAssembled: return "Film not assembled"
            case .stale: return "Film stale"
            default: return "Film up to date"
            }
        }
        /// Assembled from the project as it is, with every scene generated.
        public var isOK: Bool { state == .upToDate && ungenerated.isEmpty }
        /// "Stale since": what changed since the film was assembled.
        public var staleLine: String? { state == .stale ? "Stale since the last assembly: " + staleReasons.joined(separator: "; ") : nil }
    }

    public static let legacySentence = "Old format: scenes cannot be regenerated one by one. A new Build switches to the new format."

    public static func status(_ store: ProjectStore) -> Status {
        let playable = Versions.working(store), incomplete = Versions.incomplete(store)
        guard let f = store.loadShowreel(), let target = Versions.target(store) else {
            return Status(state: .neverAssembled, target: nil, playable: playable, ungenerated: [], staleReasons: [], incomplete: incomplete, scenes: [:])
        }
        if !SceneModules.usesSceneFiles(version: target, store: store) {
            // a hand-written main.js is the older format; a folder with neither is a build that stopped before writing a scene
            let hasMain = FileManager.default.fileExists(atPath: store.root.appendingPathComponent("\(target)/main.js").path)
            return Status(state: hasMain ? .legacy : .neverAssembled, target: target, playable: playable, ungenerated: [], staleReasons: [], incomplete: incomplete, scenes: [:])
        }
        let scenes = SceneModules.statuses(version: target, store: store)
        let gone = f.film.map { $0.id }.filter { scenes[$0]?.state == .notGenerated }
        guard Versions.hasDist(store, target), let rec = SceneModules.filmRecord(version: target, store: store), SceneModules.result(version: target, store: store)?.ok != false else {
            let why = SceneModules.result(version: target, store: store)?.ok == false ? ["the last assembly of \(target) had problems"] : []
            return Status(state: Versions.hasDist(store, target) && !why.isEmpty ? .stale : .neverAssembled, target: target, playable: playable, ungenerated: gone, staleReasons: why, incomplete: incomplete, scenes: scenes)
        }
        let now = SceneModules.filmParts(f, version: target, store: store)
        var reasons: [String] = []
        if rec.parts["montage"] != now["montage"] { reasons.append("the order, a length or a transition changed") }
        if rec.parts["music"] != now["music"] { reasons.append("the music changed") }
        if rec.parts["fonts"] != now["fonts"] { reasons.append("the embedded fonts changed") }
        for s in f.film {
            let a = rec.parts[s.id], b = now[s.id]
            if a == b { continue }
            let (ai, am) = split(a), (bi, bm) = split(b)
            reasons.append(am != bm && ai == bi ? "the file of \(s.id) changed" : "\(s.id) changed (content, length or look)")
        }
        for id in rec.parts.keys where id != "montage" && id != "music" && id != "fonts" && !f.film.contains(where: { $0.id == id }) { reasons.append("\(id) left the film") }
        return Status(state: reasons.isEmpty ? .upToDate : .stale, target: target, playable: playable, ungenerated: gone, staleReasons: reasons.sorted(), incomplete: incomplete, scenes: scenes)
    }

    private static func split(_ s: String?) -> (String, String) {
        guard let s = s, let i = s.firstIndex(of: "|") else { return (s ?? "", "") }
        return (String(s[..<i]), String(s[s.index(after: i)...]))
    }
}

// MARK: what the interface may offer

extension Unavailable.Cause {}

public extension Reasons {
    static let notAssembled = Unavailable(.notAssembled, reason: "The film has not been assembled yet", way: "Assemble it (free, no AI)", link: .assemble)
    static let legacy = Unavailable(.legacy, reason: "Old format: scenes cannot be regenerated one by one", way: "A new Build switches to the new format")
    static let nothingToAssemble = Unavailable(.notReady, reason: "There is no version to assemble yet", way: "Build a version with Clap first")
}

public extension Availability {
    /// Play: the film that is assembled (the last that works). With none, the way is to assemble it; a stale film is assembled when Play is pressed.
    static func play(_ s: FilmBuild.Status) -> Availability {
        if s.playable != nil { return .available }
        return .unavailable(s.target == nil ? Reasons.nothingToAssemble : s.state == .legacy ? Reasons.nothingToAssemble : Reasons.notAssembled)
    }

    /// Assemble: free, no AI. Not in the old format, not while a build runs, and there must be a version.
    static func assemble(_ s: FilmBuild.Status, in snap: ProjectActivity.Snapshot) -> Availability {
        if snap.isBuilding { return .unavailable(Reasons.building) }
        if s.target == nil { return .unavailable(Reasons.nothingToAssemble) }
        if s.state == .legacy { return .unavailable(Reasons.legacy) }
        return .available
    }

    /// Whether one scene can be generated (again): a locked scene never, whatever changed; when its inherited look changed it is stale and says so.
    static func regenerate(_ id: String, _ s: FilmBuild.Status, file: ShowreelFile?) -> Availability {
        guard file?.scenes.first(where: { $0.id == id })?.isLocked == true else { return .available }
        let stale = s.scenes[id]?.state == .stale
        return .unavailable(Unavailable(.locked, reason: stale ? "\(id) is locked and its look changed" : "\(id) is locked", way: stale ? "Unlock it to generate it again" : "Unlock it first", link: .scene(id)))
    }

    /// Add the font files of a free font to the project: not while a build runs, only a font of the skill's list, and not when it is already embedded.
    static func addFontFiles(_ family: String, in snap: ProjectActivity.Snapshot, store: ProjectStore) -> Availability {
        if snap.isBuilding { return .unavailable(Reasons.building) }
        guard Look.freeFonts().contains(where: { $0.name.caseInsensitiveCompare(family) == .orderedSame }) else {
            return .unavailable(Unavailable(.notReady, reason: "\(family) is not in the skill's list of free fonts", way: "Download it from its own page and drop the files in the Resources tab"))
        }
        if case .embedded = FontUse.state(family, store: store) { return .unavailable(Unavailable(.notReady, reason: "\(family) already is embedded", way: "Nothing to add")) }
        return .available
    }

    /// Generate scenes with the AI: a key, no build running, not the old format, and no scene that is locked.
    static func generate(_ ids: [String], _ s: FilmBuild.Status, in snap: ProjectActivity.Snapshot, hasKey: Bool, file: ShowreelFile?) -> Availability {
        if snap.isBuilding { return .unavailable(Reasons.building) }
        if !hasKey { return .unavailable(Reasons.noKey) }
        if s.state == .legacy { return .unavailable(Reasons.legacy) }
        if s.target == nil { return .unavailable(Reasons.nothingToAssemble) }
        if ids.isEmpty { return .unavailable(Unavailable(.notReady, reason: "No scene to generate", way: "Every scene has its file")) }
        return .available
    }
}

// MARK: generating the scenes that have no file

public struct GenerationOffer: Equatable, Sendable {
    /// The scenes to generate: no file, or a file that is out of date. A locked one is never in it.
    public let ids: [String]
    public let excluded: [(id: String, reason: String)]
    /// Of `ids`, the ones whose file was edited by hand: generating them overwrites the edit, so they need their own confirmation.
    public let handEdited: [String]
    /// Of `ids` and `excluded`, the ones that have no file at all (the others are stale).
    public let missing: [String]
    public init(ids: [String], excluded: [(id: String, reason: String)], handEdited: [String] = [], missing: [String]? = nil) { self.ids = ids; self.excluded = excluded; self.handEdited = handEdited; self.missing = missing ?? ids }
    public static func == (a: GenerationOffer, b: GenerationOffer) -> Bool { a.ids == b.ids && a.excluded.map { $0.id } == b.excluded.map { $0.id } && a.handEdited == b.handEdited && a.missing == b.missing }
    /// "S03 and S05 are not generated: shown as empty frames".
    public var bannerLine: String? {
        let gone = missing.sorted()
        guard !gone.isEmpty else { return nil }
        return LockedLook.list(gone) + (gone.count == 1 ? " is" : " are") + " not generated: shown as empty frames"
    }
    /// "S02 is stale: its content, length or look changed since its file was generated".
    public var staleLine: String? {
        let stale = (ids + excluded.map { $0.id }).filter { !missing.contains($0) }.sorted()
        guard !stale.isEmpty else { return nil }
        return LockedLook.list(stale) + (stale.count == 1 ? " is" : " are") + " stale: " + (stale.count == 1 ? "its" : "their") + " content, length or look changed since the file was generated"
    }
    /// What the extra confirmation says.
    public var overwriteLine: String? {
        handEdited.isEmpty ? nil : "\(LockedLook.list(handEdited)) \(handEdited.count == 1 ? "was" : "were") edited by hand: generating again overwrites the edit."
    }
}

extension SceneGeneration {
    /// The scenes with no file that can be generated, and those that cannot (locked), with the reason.
    public static func offer(version: String, store: ProjectStore, file f: ShowreelFile) -> GenerationOffer {
        var ids: [String] = [], out: [(id: String, reason: String)] = [], edited: [String] = [], missing: [String] = []
        for s in f.film {
            let st = SceneModules.status(of: s, version: version, in: f, store: store)
            guard st.state != .upToDate else { continue }
            if st.state == .notGenerated { missing.append(s.id) }
            if let why = refusal(s.id, version: version, in: f, store: store) { out.append((s.id, why)); continue }
            ids.append(s.id)
            if st.moduleEdited { edited.append(s.id) }
        }
        return GenerationOffer(ids: ids, excluded: out, handEdited: edited, missing: missing)
    }

    /// A rough cost: one call per scene, about a quarter of a token per character in, and a scene file of up to 3000 tokens out. An estimate, said as one.
    public static func estimate(_ ids: [String], version: String, store: ProjectStore, skill: URL) -> (calls: Int, tokensIn: Int, tokensOut: Int) {
        let inTokens = ids.reduce(0) { $0 + prompt(scene: $1, version: version, store: store, skill: skill).count / 4 }
        return (ids.count, inTokens, ids.count * 3000)
    }

    static func kilo(_ n: Int) -> String { n >= 1000 ? "\(Int((Double(n) / 1000).rounded()))k" : "\(n)" }
}

// MARK: assembling, with no AI

public struct AssemblyOutcome: Equatable, Sendable {
    public let ok: Bool
    public let message: String
    public let scenes: Int
    public let transitions: Int
    public let ungenerated: [String]
}

public enum FilmAssembly {
    /// Writes film.json from the montage, runs the assembler, build.py and the engine's checks on a copy of the version, and only when they are green puts the result in the
    /// version. A failure shows the engine's error in plain words and leaves the version, and so the film that works, as it was. Scenes with no file are empty frames: the
    /// assembly succeeds, the film is not `ok`. Needs no AI. While it runs the project is read-only, like a build.
    public static func run(version: String, store: ProjectStore, skill: URL, author: String = "user") async -> AssemblyOutcome {
        func fail(_ m: String) -> AssemblyOutcome { AssemblyOutcome(ok: false, message: m, scenes: 0, transitions: 0, ungenerated: []) }
        guard let f = store.loadShowreel() else { return fail("there is no readable showreel.json") }
        guard SceneModules.usesSceneFiles(version: version, store: store) else { return fail(FilmBuild.legacySentence) }
        let act = store.activity
        if act.snapshot.isBuilding { return fail(Reasons.building.message) }
        act.update { $0.build = .init(version: version, phase: .testing) }
        defer { act.update { $0.build = nil } }
        let fm = FileManager.default
        let src = store.root.appendingPathComponent(version), stagingName = version + ".assembling", stage = store.root.appendingPathComponent(stagingName)
        try? fm.removeItem(at: stage)
        defer { try? fm.removeItem(at: stage) }
        do {
            try fm.copyItem(at: src, to: stage)
            try? fm.removeItem(at: stage.appendingPathComponent("dist"))
            try Film.text(f).write(to: stage.appendingPathComponent(Film.fileName), atomically: true, encoding: .utf8)
        } catch { return fail("could not prepare the copy: \(error.localizedDescription)") }
        let report = await BuildRunner.run(version: stagingName, store: store, skill: skill)
        if Task.isCancelled { return fail("cancelled: nothing was changed") }
        guard report.built, report.harnessClean, report.smokeClean else {
            let bad = report.steps.filter { $0.level == .fail }
            let text = bad.isEmpty ? "the checks did not pass" : bad.map { "\($0.title): \($0.detail)" }.joined(separator: "\n")
            return fail("Assembly failed, \(version) is unchanged and still the film that works.\n" + text)
        }
        do {
            for name in ["film.json", "main.js", "assembly.json", "fonts.json", "dist"] {
                let from = stage.appendingPathComponent(name), to = src.appendingPathComponent(name)
                guard fm.fileExists(atPath: from.path) else { if name == "fonts.json" { try? fm.removeItem(at: to) }; continue }
                if fm.fileExists(atPath: to.path) { try fm.removeItem(at: to) }
                try fm.moveItem(at: from, to: to)
            }
        } catch { return fail("could not put the assembled film in \(version): \(error.localizedDescription)") }
        try? store.record(BuildReport(version: version, steps: report.steps))
        let gone = f.film.map { $0.id }.filter { SceneModules.moduleHash(version: version, scene: $0, store: store) == nil }
        let tr = f.timeline().dropLast().filter { !$0.item.transition.isCut }.count
        store.noteEvent(author: author, op: "assemble", target: version, title: "Assemble the film in \(version)", after: "\(f.film.count) scenes, \(tr) transitions" + (gone.isEmpty ? "" : ", \(gone.count) not generated"))
        let n = f.film.count
        return AssemblyOutcome(ok: true, message: "Film assembled: \(n) scene\(n == 1 ? "" : "s"), \(tr) transition\(tr == 1 ? "" : "s")" + (gone.isEmpty ? "" : "; \(gone.joined(separator: ", ")) not generated: shown as empty frames"), scenes: n, transitions: tr, ungenerated: gone)
    }
}

// MARK: what a transition says about itself

public struct TransitionNote: Equatable, Sendable {
    public enum Instruction: Equatable, Sendable { case pending(scenes: [String]), used, notApplied }
    /// A transition that does not run between two real scenes: it is drawn approximately at assembly.
    public let approximate: Bool
    public let instruction: Instruction?

    public static let approximateText = "approximate render at assembly"
    public var instructionText: String? {
        switch instruction {
        case .pending(let s)?: return "instruction pending: used at the next generation of \(LockedLook.list(s))"
        case .used?: return "instruction used at the last generation"
        case .notApplied?: return "instruction not applied yet"
        case nil: return nil
        }
    }
    public var lines: [String] { (approximate ? [Self.approximateText] : []) + (instructionText.map { [$0] } ?? []) }
}

public enum TransitionNotes {
    /// What to say about the transition after a scene. The assembly alone never applies a free instruction: a generation reads it (the prompt quotes it to both scenes).
    /// It is pending until both scenes were generated with it; in the old format nothing can use it.
    public static func note(after id: String, in f: ShowreelFile, store: ProjectStore) -> TransitionNote? {
        let tl = f.timeline()
        guard let i = tl.firstIndex(where: { $0.scene.id == id }), i + 1 < tl.count else { return nil }
        let t = tl[i].item.transition
        if t.isCut { return nil }
        let approx = Look.isPreviewOnly(t.type)
        var ins: TransitionNote.Instruction?
        if let x = t.instruction, !x.isEmpty {
            let a = tl[i].scene, b = tl[i + 1].scene
            if let v = Versions.target(store), !SceneModules.usesSceneFiles(version: v, store: store) { ins = .notApplied }
            else if let v = Versions.target(store) {
                let open = [a, b].filter { SceneModules.record(version: v, scene: $0.id, store: store)?.passage != SceneModules.passage(of: $0, in: f) }.map { $0.id }
                ins = open.isEmpty ? .used : .pending(scenes: [a.id, b.id])
            } else { ins = .pending(scenes: [a.id, b.id]) }
        }
        return approx || ins != nil ? TransitionNote(approximate: approx, instruction: ins) : nil
    }
}
