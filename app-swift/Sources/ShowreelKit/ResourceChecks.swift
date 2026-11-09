import AudioToolbox
import Foundation
import ImageIO

/// What a sound file says about itself, read with no AI and no key (the system's audio file API): tags, the cover image, the length.
public struct AudioMetadata: Equatable, Sendable {
    public var title: String?, artist: String?, album: String?, copyright: String?
    public var duration: Double?
    public var artwork: Data?

    public static func read(_ url: URL) -> AudioMetadata? {
        var file: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &file) == noErr, let f = file else { return nil }
        defer { AudioFileClose(f) }
        var m = AudioMetadata()
        var size: UInt32 = UInt32(MemoryLayout<CFDictionary?>.size)
        var dict: Unmanaged<CFDictionary>?
        if AudioFileGetProperty(f, kAudioFilePropertyInfoDictionary, &size, &dict) == noErr, let d = dict?.takeRetainedValue() as? [String: Any] {
            m.title = d["title"] as? String; m.artist = d["artist"] as? String; m.album = d["album"] as? String; m.copyright = d["copyright"] as? String
            if let s = d["approximate duration in seconds"] as? String, let n = Double(s) { m.duration = n } else if let n = d["approximate duration in seconds"] as? Double { m.duration = n }
        }
        var asize: UInt32 = 0
        if AudioFileGetPropertyInfo(f, kAudioFilePropertyAlbumArtwork, &asize, nil) == noErr, asize > 0 {
            var art: Unmanaged<CFData>?
            var sz = UInt32(MemoryLayout<CFData?>.size)
            if AudioFileGetProperty(f, kAudioFilePropertyAlbumArtwork, &sz, &art) == noErr, let data = art?.takeRetainedValue() as Data?, !data.isEmpty { m.artwork = data }
        }
        return m
    }
}

/// The automatic checks of a file that is added: no AI, no key, at once. A flag says in plain words why the file needs attention; it belongs to one of three kinds,
/// which say how it is settled: the rights question, a risk accepted with a reason, or never (replace the file).
public enum ResourceChecks {
    public enum Kind: String, Sendable { case rights, quality, sensitive }
    public struct Flag: Equatable, Sendable {
        public let kind: Kind
        public let reason: String
    }

    /// The flags of the source file of a row (what was added), recomputed from the file.
    public static func flags(_ url: URL, rel: String, type: String) -> [Flag] {
        var out: [Flag] = []
        let ext = url.pathExtension.lowercased()
        if Assets.matches(Assets.sensitiveName, (rel as NSString).lastPathComponent) { out.append(Flag(kind: .sensitive, reason: "its name suggests real or confidential data")) }
        if ["env", "pem", "key", "p12", "pfx"].contains(ext) { out.append(Flag(kind: .sensitive, reason: "it looks like a credentials file")) }
        if ["png", "jpg", "jpeg", "webp"].contains(ext), let (w, h) = Assets.pixelSize(url) {
            if type == "logo" { if w < 200 { out.append(Flag(kind: .quality, reason: "this logo is small (\(w) px wide): a vector version would stay sharp")) } }
            else if ["shot", "photo", "img"].contains(type), w < 800 || h < 450 { out.append(Flag(kind: .quality, reason: "its resolution is low (\(w)x\(h), under 800x450)")) }
        }
        if let why = Assets.heavyReason(url, type: type) { out.append(Flag(kind: .quality, reason: why)) }
        if ["png", "jpg", "jpeg", "webp", "gif", "tif", "tiff", "heic"].contains(ext), let c = imageCopyright(url) { out.append(Flag(kind: .rights, reason: "its metadata holds a copyright notice (\"\(c)\"): say what you are allowed to do with it")) }
        if ["mp3", "wav", "m4a", "ogg", "flac"].contains(ext), let c = AudioMetadata.read(url)?.copyright, !c.trimmingCharacters(in: .whitespaces).isEmpty { out.append(Flag(kind: .rights, reason: "its tags hold a copyright notice (\"\(c)\"): say what you are allowed to do with it")) }
        if type == "font" {
            if let info = FontInfo.read(url) {
                if info.forbidsEmbedding { out.append(Flag(kind: .rights, reason: "the font's own flag forbids embedding it: a film embeds it, so say what the licence allows")) }
                else if !info.isOpenLicence { out.append(Flag(kind: .rights, reason: "its licence is not known: say what it allows (embedding in a film)")) }
            } else { out.append(Flag(kind: .rights, reason: "its licence is not known: say what it allows (embedding in a film)")) }
        }
        return out
    }

    static func imageCopyright(_ url: URL) -> String? {
        guard let s = CGImageSourceCreateWithURL(url as CFURL, nil), let p = CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as? [CFString: Any] else { return nil }
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any], iptc = p[kCGImagePropertyIPTCDictionary] as? [CFString: Any]
        let c = (tiff?[kCGImagePropertyTIFFCopyright] as? String) ?? (iptc?[kCGImagePropertyIPTCCopyrightNotice] as? String)
        return c.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }

    /// The notes line of a flagged row, as the skill's manifest keeps it (the reasons in plain words).
    public static func note(_ flags: [Flag]) -> String { flags.map { $0.reason }.joined(separator: "; ") }
}
