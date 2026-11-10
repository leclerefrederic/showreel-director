import AudioToolbox
import Foundation
import ImageIO

public struct DetailRow: Equatable, Sendable {
    public let label: String
    public let value: String
    /// A value to read at a glance: a warning (location data) or the reason a file was flagged.
    public let emphasis: Bool
    public init(_ label: String, _ value: String, emphasis: Bool = false) { self.label = label; self.value = value; self.emphasis = emphasis }
}

public struct DetailGroup: Equatable, Sendable {
    public let title: String
    public let rows: [DetailRow]
}

/// What a file says about itself, read with no AI and no key. Every value is data shown as text, never an instruction, and none of it goes into a prompt.
public struct ResourceDetails: Equatable, Sendable {
    public let groups: [DetailGroup]
    /// The compact line under the preview: "1920 x 1080 \u{00B7} PNG \u{00B7} 245 KB".
    public let summary: String
    public let warnings: [String]
    public func value(_ label: String) -> String? { groups.flatMap { $0.rows }.first { $0.label == label }?.value }
}

public enum DetailFormat {
    /// 245 KB, 8.4 MB, 1.2 GB (decimal, as the Finder shows them).
    public static func size(_ bytes: Int) -> String {
        let b = Double(bytes)
        if b < 1000 { return "\(bytes) bytes" }
        if b < 1_000_000 { return "\(Int((b / 1000).rounded())) KB" }
        if b < 1_000_000_000 { return String(format: "%.1f MB", b / 1_000_000) }
        return String(format: "%.1f GB", b / 1_000_000_000)
    }
    /// 3:42, 0:07, 1:02:05.
    public static func duration(_ s: Double) -> String {
        let t = Int(s.rounded()); let h = t / 3600, m = t % 3600 / 60, sec = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
    /// 320 kbps.
    public static func bitrate(_ bps: Double) -> String { "\(Int((bps / 1000).rounded())) kbps" }
    /// 44.1 kHz, 48 kHz.
    public static func sampleRate(_ hz: Double) -> String {
        let k = hz / 1000
        return (k == k.rounded() ? String(Int(k)) : String(format: "%.1f", k)) + " kHz"
    }
    public static func channels(_ n: Int) -> String { n == 1 ? "mono" : n == 2 ? "stereo" : "\(n) channels" }
    public static func date(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "d MMM yyyy, HH:mm"; return f.string(from: d)
    }
    public static func aspect(_ w: Int, _ h: Int) -> String {
        func g(_ a: Int, _ b: Int) -> Int { b == 0 ? a : g(b, a % b) }
        let d = max(g(w, h), 1)
        return d > 1 && w / d <= 32 && h / d <= 32 ? "\(w / d):\(h / d)" : String(format: "%.2f:1", Double(w) / Double(max(h, 1)))
    }
    static func fourCC(_ v: UInt32) -> String {
        let b = [UInt8((v >> 24) & 255), UInt8((v >> 16) & 255), UInt8((v >> 8) & 255), UInt8(v & 255)]
        return String(decoding: b, as: UTF8.self).trimmingCharacters(in: .whitespaces)
    }
}

public enum ResourceDetailsReader {
    /// A key that changes when the file does (its path, its size and its modification time) or when the row's state does: the cache and the identity of the preview.
    public static func identity(_ r: AssetRow, store: ProjectStore) -> String {
        guard let u = fileURL(r, store: store) else { return r.id + "|nofile" }
        let v = try? u.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return [r.id, u.path, "\(v?.fileSize ?? 0)", "\(v?.contentModificationDate?.timeIntervalSince1970 ?? 0)"].joined(separator: "|")
    }

    /// The file of a resource: its own, never another's (prepared when it has one, else its original in source).
    public static func fileURL(_ r: AssetRow, store: ProjectStore) -> URL? {
        let a = store.root.appendingPathComponent("assets")
        if !r.file.isEmpty { return a.appendingPathComponent(r.file) }
        if r.origin != "not copied", !r.original.isEmpty { return a.appendingPathComponent("source").appendingPathComponent(r.original) }
        return nil
    }

    public static func read(_ r: AssetRow, store: ProjectStore, file f: ShowreelFile?) -> ResourceDetails {
        let url = fileURL(r, store: store)
        var fileRows: [DetailRow] = [DetailRow("Name", r.name)]
        var media: [DetailRow] = [], tags: [DetailRow] = [], rights: [DetailRow] = [], warnings: [String] = []
        var summary: [String] = []
        let ext = (url?.pathExtension ?? (r.original as NSString).pathExtension).lowercased()
        fileRows.append(DetailRow("Type", r.type + (ext.isEmpty ? "" : " (\(ext.uppercased()))")))
        var bytes: Int?
        if let u = url {
            if FileManager.default.fileExists(atPath: u.path) {
                let v = try? u.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
                bytes = v?.fileSize
                if let b = bytes { fileRows.append(DetailRow("Size", DetailFormat.size(b))) }
                fileRows.append(DetailRow("Folder", folder(u, store: store)))
                if let c = v?.creationDate { fileRows.append(DetailRow("Added", DetailFormat.date(c))) }
                if let m = v?.contentModificationDate { fileRows.append(DetailRow("Modified", DetailFormat.date(m))) }
                switch r.group {
                case .images: image(u, ext: ext, bytes: bytes, media: &media, summary: &summary, warnings: &warnings)
                case .music, .sounds: audio(u, r: r, store: store, media: &media, tags: &tags, rights: &rights, summary: &summary)
                case .fonts: fontRows(u, media: &media, rights: &rights, summary: &summary)
                case .other: break
                }
            } else { fileRows.append(DetailRow("File", "unreadable: it is not where the project says")) }
        }
        let state = r.state(in: f)
        fileRows.append(DetailRow("State", state.title))
        if state == .needsAttention {
            for reason in ResourceAttention.of(r, store: store).reasons { rights.append(DetailRow("Needs attention", reason, emphasis: true)) }
        }
        if !r.licenceNote.isEmpty { rights.append(DetailRow("Rights", r.licenceNote, emphasis: false)) }
        if !r.notes.isEmpty, state != .needsAttention { rights.append(DetailRow("Note", r.notes)) }
        if let b = bytes, summary.last != DetailFormat.size(b) { summary.append(DetailFormat.size(b)) }
        let groups = [DetailGroup(title: "File", rows: fileRows), DetailGroup(title: "Media", rows: media), DetailGroup(title: "Tags", rows: tags), DetailGroup(title: "Rights", rows: rights)].filter { !$0.rows.isEmpty }
        return ResourceDetails(groups: groups, summary: summary.joined(separator: " \u{00B7} "), warnings: warnings)
    }

    static func folder(_ u: URL, store: ProjectStore) -> String {
        let rel = u.path.replacingOccurrences(of: store.root.appendingPathComponent("assets").path + "/", with: "")
        let parts = rel.split(separator: "/")
        return parts.count > 1 ? parts.dropLast().joined(separator: "/") : "assets"
    }

    // MARK: images

    static func image(_ u: URL, ext: String, bytes: Int?, media: inout [DetailRow], summary: inout [String], warnings: inout [String]) {
        if ext == "svg" {
            guard let t = try? String(contentsOf: u, encoding: .utf8) else { media.append(DetailRow("Image", "unreadable")); return }
            func attr(_ n: String) -> String? { t.range(of: n + #"\s*=\s*"([^"]+)""#, options: .regularExpression).map { String(t[$0]).replacingOccurrences(of: #"^.*="\s*"#, with: "", options: .regularExpression).replacingOccurrences(of: "\"", with: "") } }
            let w = attr("width"), h = attr("height"), vb = attr("viewBox")
            media.append(DetailRow("Format", "SVG (vector)"))
            if let w = w, let h = h { media.append(DetailRow("Dimensions", "\(w) \u{00D7} \(h)")); summary.append("\(w) \u{00D7} \(h)") }
            if let vb = vb { media.append(DetailRow("viewBox", vb)); if w == nil { summary.append("viewBox " + vb) } }
            summary.append("SVG")
            return
        }
        guard let s = CGImageSourceCreateWithURL(u as CFURL, nil), let p = CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as? [CFString: Any],
              let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int else { media.append(DetailRow("Image", "unreadable")); return }
        media.append(DetailRow("Dimensions", "\(w) \u{00D7} \(h) px")); media.append(DetailRow("Aspect ratio", DetailFormat.aspect(w, h)))
        if let dpi = p[kCGImagePropertyDPIWidth] as? Double, dpi > 0 { media.append(DetailRow("Resolution", "\(Int(dpi.rounded())) dpi")) }
        if let prof = p[kCGImagePropertyProfileName] as? String { media.append(DetailRow("Colour profile", prof)) } else if let m = p[kCGImagePropertyColorModel] as? String { media.append(DetailRow("Colour model", m)) }
        let alpha = (p[kCGImagePropertyHasAlpha] as? Bool) ?? false
        media.append(DetailRow("Transparency", alpha ? "yes (alpha channel)" : "no"))
        let type = (CGImageSourceGetType(s) as String?).flatMap { $0.split(separator: ".").last.map { String($0).uppercased() } } ?? ext.uppercased()
        media.append(DetailRow("Format", type))
        summary.append("\(w) \u{00D7} \(h)"); summary.append(type)
        if p[kCGImagePropertyGPSDictionary] != nil { warnings.append("Contains location data"); media.append(DetailRow("Location", "Contains location data", emphasis: true)) }
    }

    // MARK: sounds and music

    static func audio(_ u: URL, r: AssetRow, store: ProjectStore, media: inout [DetailRow], tags: inout [DetailRow], rights: inout [DetailRow], summary: inout [String]) {
        var file: AudioFileID?
        guard AudioFileOpenURL(u as CFURL, .readPermission, 0, &file) == noErr, let f = file else { media.append(DetailRow("Audio", "unreadable")); return }
        defer { AudioFileClose(f) }
        func prop<T>(_ id: AudioFilePropertyID, _ zero: T) -> T? { var v = zero; var sz = UInt32(MemoryLayout<T>.size); return withUnsafeMutablePointer(to: &v) { AudioFileGetProperty(f, id, &sz, $0) } == noErr ? v : nil }
        let fmt = prop(kAudioFilePropertyDataFormat, AudioStreamBasicDescription())
        let kind = prop(kAudioFilePropertyFileFormat, UInt32(0))
        let dur = prop(kAudioFilePropertyEstimatedDuration, Double(0)), rate = prop(kAudioFilePropertyBitRate, UInt32(0))
        if let d = dur, d > 0 { media.append(DetailRow("Duration", DetailFormat.duration(d))); summary.append(DetailFormat.duration(d)) }
        let container = kind.map { containerName($0) }
        if let c = container { media.append(DetailRow("Format", c)); summary.append(c) }
        if let k = fmt?.mFormatID { media.append(DetailRow("Codec", codecName(k))) }
        if let br = rate, br > 0 { media.append(DetailRow("Bit rate", DetailFormat.bitrate(Double(br)))); summary.append(DetailFormat.bitrate(Double(br))) }
        if let sr = fmt?.mSampleRate, sr > 0 { media.append(DetailRow("Sample rate", DetailFormat.sampleRate(sr))) }
        if let ch = fmt?.mChannelsPerFrame, ch > 0 { media.append(DetailRow("Channels", DetailFormat.channels(Int(ch)))); summary.append(DetailFormat.channels(Int(ch))) }
        if let m = AudioMetadata.read(u) {
            if let t = m.title, !t.isEmpty { tags.append(DetailRow("Title", t)) }
            if let a = m.artist, !a.isEmpty { tags.append(DetailRow("Artist", a)) }
            if let a = m.album, !a.isEmpty { tags.append(DetailRow("Album", a)) }
            if let y = m.year, !y.isEmpty { tags.append(DetailRow("Year", y)) }
            if let g = m.genre, !g.isEmpty { tags.append(DetailRow("Genre", g)) }
            if let c = m.copyright, !c.isEmpty { rights.append(DetailRow("Copyright", c, emphasis: true)) }
            if let art = m.artwork, let s = CGImageSourceCreateWithData(art as CFData, nil), let p = CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as? [CFString: Any],
               let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int { tags.append(DetailRow("Cover", "\(w) \u{00D7} \(h) px (\(DetailFormat.size(art.count)))")) }
            else if let art = m.artwork { tags.append(DetailRow("Cover", DetailFormat.size(art.count))) }
        }
        // the grid of the analysis that the app or the skill already made for this very file; nothing is analysed here
        if let tr = store.loadShowreel()?.decisions.track?.file, tr == "assets/" + r.file, let a = MusicAnalysis.load(root: store.root) {
            media.append(DetailRow("Tempo", "\(Int(a.bpm.rounded())) BPM")); media.append(DetailRow("First beat", String(format: "%.2f s", a.firstBeat)))
        } else if r.type == "audio" { media.append(DetailRow("Tempo", "not analysed")) }
    }

    static func containerName(_ k: UInt32) -> String {
        switch k { case kAudioFileMP3Type: return "MP3"; case kAudioFileWAVEType: return "WAV"; case kAudioFileAIFFType: return "AIFF"; case kAudioFileM4AType: return "M4A"; case kAudioFileCAFType: return "CAF"
        case kAudioFileMPEG4Type: return "MPEG-4"; case kAudioFileAAC_ADTSType: return "AAC"; case kAudioFileFLACType: return "FLAC"; default: return DetailFormat.fourCC(k) }
    }
    static func codecName(_ k: UInt32) -> String {
        switch k { case kAudioFormatLinearPCM: return "PCM"; case kAudioFormatMPEGLayer3: return "MP3"; case kAudioFormatMPEG4AAC: return "AAC"; case kAudioFormatAppleLossless: return "Apple Lossless"; case kAudioFormatFLAC: return "FLAC"
        default: return DetailFormat.fourCC(k) }
    }

    // MARK: fonts

    static func fontRows(_ u: URL, media: inout [DetailRow], rights: inout [DetailRow], summary: inout [String]) {
        guard let i = FontInfo.read(u) else {
            media.append(DetailRow("Font", u.pathExtension.lowercased() == "woff2" ? "a compressed web font: its details are not read here" : "unreadable"))
            return
        }
        media.append(DetailRow("Family", i.family)); if !i.style.isEmpty { media.append(DetailRow("Style", i.style)) }
        let w = i.weightRange.map { "\($0.lowerBound) to \($0.upperBound)" } ?? "\(i.weight)"
        media.append(DetailRow("Weight", w)); media.append(DetailRow("Italic", i.italic ? "yes" : "no"))
        if i.glyphCount > 0 { media.append(DetailRow("Glyphs", "\(i.glyphCount)")) }
        media.append(DetailRow("Format", i.format + (i.isVariable ? ", variable" : "")))
        media.append(DetailRow("Embedding", i.forbidsEmbedding ? "forbidden by the font's own flag" : "allowed by the font's own flag", emphasis: i.forbidsEmbedding))
        if let l = i.licence, !l.isEmpty { rights.append(DetailRow("Declared licence", l)) }
        summary.append(i.family); summary.append(w); summary.append(u.pathExtension.uppercased())
    }
}

/// The details of a resource, read once off the main thread and kept until the file changes.
public final class ResourceDetailsCache: @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: ResourceDetails] = [:]
    public init() {}
    public func cached(_ key: String) -> ResourceDetails? { lock.lock(); defer { lock.unlock() }; return store[key] }
    /// Reads (or returns what was read for the same file), calling `read` on the caller's thread: the views call it from a background task.
    public func details(_ key: String, read: () -> ResourceDetails) -> ResourceDetails {
        if let d = cached(key) { return d }
        let d = read()
        lock.lock(); store[key] = d; if store.count > 200 { store.removeAll() }; lock.unlock()
        return d
    }
}
