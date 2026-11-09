import Foundation

// MARK: what a project can put in a package

/// A resource of the project that can go into a package, with what the project knows about its rights.
public struct OfferedResource: Identifiable, Equatable, Sendable {
    public var id: String { row.id }
    public let row: AssetRow
    public let tags: [String]
    public let rights: RightsAnswer?
    public let rightsDetail: String
    public let openFont: Bool
}

/// The things the project holds that a package can take, as the "Save design as package" sheet lists them. A part the project does not have is not offered.
public struct PackageOffer: Equatable, Sendable {
    public let look: PackageDesign.Look?
    public let motion: PackageDesign.Motion?
    public let tone: String?
    public let defaults: PackageDesign.Defaults?
    public let resources: [OfferedResource]
    public init(look: PackageDesign.Look?, motion: PackageDesign.Motion?, tone: String?, defaults: PackageDesign.Defaults?, resources: [OfferedResource]) {
        self.look = look; self.motion = motion; self.tone = tone; self.defaults = defaults; self.resources = resources
    }
    public var isEmpty: Bool { look == nil && motion == nil && tone == nil && defaults == nil && resources.isEmpty }
}

/// What the user chose to put in.
public struct PackageSelection: Equatable, Sendable {
    public var look = true, motion = true, tone = true, defaults = true
    public var resources: Set<String>
    public init(look: Bool = true, motion: Bool = true, tone: Bool = true, defaults: Bool = true, resources: Set<String> = []) {
        self.look = look; self.motion = motion; self.tone = tone; self.defaults = defaults; self.resources = resources
    }
    /// Everything the offer holds.
    public init(all o: PackageOffer) { self.init(resources: Set(o.resources.map { $0.id })) }
}

public enum PackageSave {
    /// The rights answer a manifest note holds ("own work: the studio shot it"), as the rights flow wrote it.
    static func rights(of note: String) -> (RightsAnswer, String)? {
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        for a in RightsAnswer.allCases where n.lowercased() == a.rawValue || n.lowercased().hasPrefix(a.rawValue + ":") {
            return (a, n.count > a.rawValue.count ? String(n.dropFirst(a.rawValue.count + 1)).trimmingCharacters(in: .whitespaces) : "")
        }
        return nil
    }

    /// The path of a resource's file in the project, or nil when the project holds none.
    static func fileURL(_ r: AssetRow, store: ProjectStore) -> URL? {
        let assets = store.root.appendingPathComponent("assets")
        let u = !r.file.isEmpty ? assets.appendingPathComponent(r.file) : (r.original.isEmpty || r.origin == "not copied" ? nil : assets.appendingPathComponent("source").appendingPathComponent(r.original))
        guard let url = u, url.isInside(store.root), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    static func isOpenFont(_ r: AssetRow, url: URL) -> Bool {
        guard r.type == "font" else { return false }
        if let i = FontInfo.read(url) { return i.isOpenLicence && !i.forbidsEmbedding }
        return r.licenceNote.hasPrefix(FontFiles.licence)
    }

    /// The default transition of the master montage, when it has one: the passage most used, with its usual duration. A project has no setting of its own for it.
    public static func motion(of f: ShowreelFile) -> PackageDesign.Motion? {
        guard let m = f.storyboards.first else { return nil }
        let used = m.items.filter { $0.enabled && $0.transition.type != "cut" }
        guard !used.isEmpty else { return nil }
        let counts = Dictionary(grouping: used, by: { $0.transition.type }).mapValues { $0.count }
        guard let top = counts.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value })?.key else { return nil }
        let durations = used.filter { $0.transition.type == top }.compactMap { $0.transition.duration }
        let dc = Dictionary(grouping: durations, by: { $0 }).mapValues { $0.count }
        return PackageDesign.Motion(defaultTransition: top, duration: dc.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value })?.key)
    }

    public static func offer(_ store: ProjectStore) -> PackageOffer {
        guard let f = store.loadShowreel() else { return PackageOffer(look: nil, motion: nil, tone: nil, defaults: nil, resources: []) }
        let d = f.decisions
        var look = PackageDesign.Look(palette: d.palette, titleFont: d.fonts?.titles, textFont: d.fonts?.text, background: d.background?.id, backgroundMood: d.background?.mood,
                                      moods: d.moods, effectsPack: d.effectsPack)
        if (look.palette ?? []).isEmpty { look.palette = nil }
        if (look.moods ?? []).isEmpty { look.moods = nil }
        let hasLook = look.palette != nil || look.titleFont != nil || look.textFont != nil || look.background != nil || look.moods != nil || look.effectsPack != nil
        let tone = (f.parameters.tone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let defaults = PackageDesign.Defaults(formats: (d.formats ?? []).isEmpty ? nil : d.formats, duration: (d.duration ?? 0) > 0 ? d.duration : nil,
                                              reelLanguages: f.reelLanguages.isEmpty ? nil : f.reelLanguages, controlLevel: f.parameters.controlLevel)
        let rows = Assets.load(store).filter { $0.status == "approved" && fileURL($0, store: store) != nil }
        let res = rows.map { r -> OfferedResource in
            let a = rights(of: r.licenceNote)
            return OfferedResource(row: r, tags: Resources.tags(of: r, in: f).filter { $0 != "placeholder" }, rights: a?.0, rightsDetail: a?.1 ?? "", openFont: fileURL(r, store: store).map { isOpenFont(r, url: $0) } ?? false)
        }
        return PackageOffer(look: hasLook ? look : nil, motion: motion(of: f), tone: tone.isEmpty ? nil : tone, defaults: defaults.isEmpty ? nil : defaults, resources: res)
    }

    /// The version a save proposes, and whether it continues a package. A project that came from a package continues it (same id, the number goes up past anything kept).
    public static func continuation(of f: ShowreelFile, library: PackageLibrary) -> (id: String, version: String, name: String)? {
        guard let o = f.package, UUID(uuidString: o.id) != nil else { return nil }
        let newest = library.latest(o.id)
        let top = [o.version, newest?.manifest.version ?? "0"].max { PackageVersion.compare($0, $1) < 0 } ?? o.version
        return (o.id, PackageVersion.next(after: top), newest?.manifest.name ?? f.name)
    }

    /// Builds the package from what the user chose. `continuing` keeps the id and goes up one version; the note then says what changed and is mandatory.
    public static func build(store: ProjectStore, selection: PackageSelection, name: String, author rawAuthor: String, note: String, continuing: Bool, library: PackageLibrary,
                             limits: PackageLimits = .standard, now: Date = Date()) throws -> DesignPackage {
        let author = try PackageAuthor.validate(rawAuthor)
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 120 else { throw PackageError.invalid("Give the package a name (120 characters at most)") }
        let why = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let f = store.loadShowreel() else { throw PackageError.invalid("there is no readable showreel.json: create the project first") }
        let cont = continuing ? continuation(of: f, library: library) : nil
        if continuing, cont == nil { throw PackageError.invalid("this project did not start from a package: save a new package instead") }
        if cont != nil, why.isEmpty { throw PackageError.invalid("Say what changed in this version: a new version of a package needs a note") }
        let offer = offer(store)
        var design = PackageDesign()
        if selection.look { design.look = offer.look }
        if selection.motion { design.motion = offer.motion }
        if selection.tone { design.tone = offer.tone }
        if selection.defaults { design.defaults = offer.defaults }
        let chosen = offer.resources.filter { selection.resources.contains($0.id) }
        guard !design.isEmpty || !chosen.isEmpty else { throw PackageError.invalid("Nothing is chosen: pick a part of the design or a resource") }
        let stamp = PackageLibrary.timestamp(now)
        var files: [String: Data] = [:]
        var resources: [PackageResource] = []
        var total = 0
        for o in chosen {
            guard let url = fileURL(o.row, store: store), let data = try? Data(contentsOf: url) else { throw PackageError.invalid("the file of \(o.row.name) is not in the project any more") }
            guard data.count <= limits.maxFileSize else { throw PackageError.tooLarge("\(o.row.name) is larger than the \(limits.maxFileSize / 1_000_000) MB a package may hold for one file") }
            let fileName = safeName(url.lastPathComponent)
            guard PackageReader.allowedExtensions.contains((fileName as NSString).pathExtension.lowercased()) else { throw PackageError.unexpected("\(o.row.name) is not a kind of file a package may carry") }
            let path = PackageType.assetsFolder + o.row.id + "/" + fileName
            files[path] = data; total += data.count
            var r = PackageResource(id: o.row.id, type: o.row.type, tags: o.tags, originalName: o.row.name, file: path, fileHash: PackageHash.sha256(data),
                                    rights: o.rights?.rawValue, rightsDetail: o.rightsDetail, openFont: o.openFont, approvedBy: author, approvedAt: stamp)
            // an open font added through the card keeps its licence text next to it
            if o.row.type == "font", let lic = try? Data(contentsOf: url.deletingLastPathComponent().appendingPathComponent("OFL.txt")), !lic.isEmpty, lic.count <= limits.maxFileSize {
                let lp = PackageType.assetsFolder + o.row.id + "/OFL.txt"
                files[lp] = lic; total += lic.count
                r.licenceFile = lp; r.licenceFileHash = PackageHash.sha256(lic)
            }
            resources.append(r)
        }
        guard total <= limits.maxTotalSize else { throw PackageError.tooLarge("the chosen resources weigh more than the \(limits.maxTotalSize / 1_000_000) MB a package may hold") }
        guard files.count + 3 <= limits.maxEntries else { throw PackageError.tooLarge("a package holds \(limits.maxEntries) files at most") }
        let id = cont?.id ?? UUID().uuidString.lowercased()
        let created = (cont.flatMap { library.latest($0.id)?.manifest.created }) ?? stamp
        var pkg = DesignPackage(manifest: PackageManifest(id: id, name: title, version: cont?.version ?? "1.0", author: author, created: created, modified: stamp, note: why),
                                design: design, resources: resources, files: files)
        try pkg.seal()
        return pkg
    }

    static func safeName(_ n: String) -> String {
        let clean = n.unicodeScalars.map { CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._- ")).contains($0) ? Character($0) : "-" }
        let s = String(clean).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return s.isEmpty ? "file" : String(s.prefix(120))
    }
}

extension Availability {
    /// Whether "Save design as package" works: not while a film is being built, and only when the project holds something to save.
    public static func savePackage(in s: ProjectActivity.Snapshot, offer: PackageOffer) -> Availability {
        if s.isBuilding { return .unavailable(Reasons.building) }
        if offer.isEmpty { return .unavailable(Unavailable(.notReady, reason: "There is nothing to save yet", way: "Set the look or the defaults, or add resources, then save the design")) }
        return .available
    }
}

extension StatusLine {
    /// "Package \u{201C}Brand\u{201D} 1.0 saved in the library". Not a change to the project: nothing to undo.
    public static func packageSaved(name: String, version: String, exported: Bool) -> StatusLine {
        StatusLine(kind: .applied, text: "Package \u{201C}\(name)\u{201D} \(version) saved in the library" + (exported ? " and exported" : "") + ". The project itself did not change.", targets: [], undoable: false)
    }
}

// MARK: starting a project from a package

public struct PackageStartReport: Equatable, Sendable {
    public var approved = 0
    /// Resources on Needs attention because the rights are not confirmed.
    public var rightsHeld = 0
    /// Resources the automatic checks flagged, whatever the package says.
    public var flagged = 0
    public var applied: [String] = []
}

public enum PackageStart {
    /// The reason a resource enters a project on Needs attention when the user has not confirmed the rights.
    public static let notConfirmed = "Rights not confirmed by you"

    /// The package a library entry holds, applied to a new project. The project stays standalone: a copy of the design and of the files, no link.
    @discardableResult
    public static func start(_ entry: LibraryPackage, library: PackageLibrary, into store: ProjectStore, now: Date = Date()) throws -> PackageStartReport {
        let r = try library.load(entry)
        guard !r.needsNewerApp else { throw PackageError.newerFormat("this package needs a newer version of the app") }
        return try apply(r.package, rightsConfirmed: entry.isConfirmed, confirmation: entry.confirmation, into: store, now: now)
    }

    static func keep(_ list: [String]?) -> [String]? { let l = (list ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && $0.count <= 80 }; return l.isEmpty ? nil : l }

    @discardableResult
    public static func apply(_ pkg: DesignPackage, rightsConfirmed: Bool, confirmation: PackageConfirmation?, into store: ProjectStore, now: Date = Date()) throws -> PackageStartReport {
        guard store.loadShowreel() != nil else { throw PackageError.invalid("there is no readable showreel.json: create the project first") }
        var report = PackageStartReport()
        let m = pkg.manifest

        // the resources first: the automatic checks of the Resources block apply to every file, whatever the package says
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("showreel-package-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        var idMap: [String: String] = [:]
        for res in pkg.resources {
            guard let data = pkg.files[res.file] else { continue }
            let dir = scratch.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let tmp = dir.appendingPathComponent(PackageSave.safeName(res.originalName))
            try data.write(to: tmp)
            let stated = res.rightsAnswer.map { " (the package says: \($0.rawValue))" } ?? ""
            let hold: String? = rightsConfirmed ? nil : notConfirmed + stated
            guard let row = try Assets.add([tmp], to: store, holdReason: hold).first else { continue }
            idMap[res.id] = row.id
            if row.status == "hold" { if row.notes.hasPrefix(notConfirmed) { report.rightsHeld += 1 } else { report.flagged += 1 } } else { report.approved += 1 }
            if let lic = res.licenceFile, let ld = pkg.files[lic] {
                let ldir = scratch.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: ldir, withIntermediateDirectories: true)
                let lt = ldir.appendingPathComponent(PackageSave.safeName((lic as NSString).lastPathComponent))
                try ld.write(to: lt)
                _ = try Assets.add([lt], to: store)
            }
        }
        // the rights the package states, recorded on the rows that are approved; the unconfirmed ones keep the question
        var rows = Assets.load(store)
        for res in pkg.resources {
            guard let nid = idMap[res.id], let i = rows.firstIndex(where: { $0.id == nid }) else { continue }
            if rows[i].status == "approved" {
                if rows[i].licenceNote.isEmpty {
                    rows[i].licenceNote = res.rightsAnswer.map { $0.note(detail: res.rightsDetail) } ?? "confirmed by you with the package \u{201C}\(m.name)\u{201D} \(m.version)"
                }
                if rows[i].notes.isEmpty || rows[i].notes == "not embedded" { rows[i].notes = "from the package \u{201C}\(m.name)\u{201D} \(m.version)" }
            }
        }
        try Assets.save(rows, store)

        // the design
        guard var f = store.loadShowreel() else { throw PackageError.invalid("showreel.json cannot be read") }
        let d = pkg.design
        if let l = d.look {
            if let p = l.palette, !p.isEmpty, p.allSatisfy({ EnginePalette.isHex($0) }) { f.decisions.palette = p; report.applied.append("palette") }
            var fonts = f.decisions.fonts ?? ShowreelFile.Fonts()
            if let t = keep([l.titleFont ?? ""])?.first { fonts.titles = t }
            if let t = keep([l.textFont ?? ""])?.first { fonts.text = t }
            if fonts != (f.decisions.fonts ?? ShowreelFile.Fonts()) { f.decisions.fonts = fonts; report.applied.append("fonts") }
            if let b = keep([l.background ?? ""])?.first { f.decisions.background = ShowreelFile.Background(id: b, mood: keep([l.backgroundMood ?? ""])?.first); report.applied.append("background") }
            if let mo = keep(l.moods) { f.decisions.moods = mo; report.applied.append("moods") }
            if let e = keep([l.effectsPack ?? ""])?.first { f.decisions.effectsPack = e; report.applied.append("effects") }
        }
        if let mo = d.motion, !mo.defaultTransition.isEmpty, mo.defaultTransition.count <= 40 {
            var o: [String: JSONValue] = ["type": .string(mo.defaultTransition)]
            if let s = mo.duration, s > 0, s < 60 { o["duration"] = .number(s) }
            f.decisions.unknown["defaultTransition"] = .object(o); report.applied.append("default transition")
        }
        if let t = d.tone?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, t.count <= 400 { f.parameters.tone = t; report.applied.append("tone") }
        if let df = d.defaults {
            if let fm = keep(df.formats) { f.decisions.formats = fm; report.applied.append("formats") }
            if let s = df.duration, s > 0, s < 3600 { f.decisions.duration = s; report.applied.append("duration") }
            if let l = keep(df.reelLanguages) { f.reelLanguages = l; report.applied.append("reel languages") }
            if let c = df.controlLevel, ["auto", "guided", "precise"].contains(c) { f.parameters.controlLevel = c; report.applied.append("control level") }
        }
        var tags = f.resourceTags ?? [:]
        for res in pkg.resources {
            guard let nid = idMap[res.id] else { continue }
            let t = res.tags.compactMap { try? ProjectStore.cleanTag($0) }.filter { $0 != "placeholder" }
            if !t.isEmpty { tags[nid] = t }
        }
        f.resourceTags = tags.isEmpty ? nil : tags
        f.package = ShowreelFile.PackageOrigin(id: m.id, version: m.version, hash: m.hash, appliedAt: PackageLibrary.timestamp(now))
        try store.save(f)

        var after = "version \(m.version), hash \(m.shortHash)"
        var note = rightsConfirmed ? "rights confirmed" + (confirmation?.by.map { " by \($0)" } ?? "") + (confirmation.map { " on \($0.date)" } ?? "") : "rights not confirmed: its resources need attention"
        if report.flagged > 0 { note += "; \(report.flagged) flagged by the automatic checks" }
        after += "; \(report.approved) resource\(report.approved == 1 ? "" : "s") available, \(report.rightsHeld + report.flagged) needing attention"
        store.noteEvent(author: "app", op: "package", target: "package \(m.name)", title: "Started from the package \u{201C}\(m.name)\u{201D}", after: after, note: note)
        return report
    }
}
