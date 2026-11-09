import AudioToolbox
import AVFoundation
import Foundation
import ImageIO

/// What a sound file says about itself, read with no AI and no key (the system's audio file API): tags, the cover image, the length.
public struct AudioMetadata: Equatable, Sendable {
    public var title: String?, artist: String?, album: String?, copyright: String?, year: String?, genre: String?
    public var duration: Double?
    public var artwork: Data?

    public static func read(_ url: URL) -> AudioMetadata? {
        var file: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &file) == noErr, let f = file else {
            guard let art = artwork(url) else { return nil }
            var m = AudioMetadata(); m.artwork = art; return m
        }
        defer { AudioFileClose(f) }
        var m = AudioMetadata()
        var size: UInt32 = UInt32(MemoryLayout<CFDictionary?>.size)
        var dict: Unmanaged<CFDictionary>?
        if AudioFileGetProperty(f, kAudioFilePropertyInfoDictionary, &size, &dict) == noErr, let d = dict?.takeRetainedValue() as? [String: Any] {
            m.title = d["title"] as? String; m.artist = d["artist"] as? String; m.album = d["album"] as? String; m.copyright = d["copyright"] as? String
            m.year = d["year"] as? String; m.genre = d["genre"] as? String
            if let s = d["approximate duration in seconds"] as? String, let n = Double(s) { m.duration = n } else if let n = d["approximate duration in seconds"] as? Double { m.duration = n }
        }
        // The system's audio file property (the old way) does not return the picture of most MP3 files, which hold it in an ID3v2 "APIC" frame:
        // the asset's metadata and then the frame itself are read first, and the old property stays as the last resort.
        m.artwork = artwork(url)
        if m.artwork == nil {
            var asize: UInt32 = 0
            if AudioFileGetPropertyInfo(f, kAudioFilePropertyAlbumArtwork, &asize, nil) == noErr, asize > 0 {
                var art: Unmanaged<CFData>?
                var sz = UInt32(MemoryLayout<CFData?>.size)
                if AudioFileGetProperty(f, kAudioFilePropertyAlbumArtwork, &sz, &art) == noErr, let data = art?.takeRetainedValue() as Data?, !data.isEmpty { m.artwork = data }
            }
        }
        return m
    }

    /// The embedded picture: the asset's metadata (AVFoundation), else the ID3v2 frame read straight from the file. Nil when there is none.
    public static func artwork(_ url: URL) -> Data? {
        if let d = avArtwork(url), isImage(d) { return d }
        if let h = try? FileHandle(forReadingFrom: url) {
            defer { try? h.close() }
            if let top = try? h.read(upToCount: 10), top.count == 10, top.starts(with: [0x49, 0x44, 0x33]), top[6..<10].allSatisfy({ $0 < 0x80 }) {
                let size = Int(top[6]) << 21 | Int(top[7]) << 14 | Int(top[8]) << 7 | Int(top[9])
                if size <= ID3Artwork.maxTag, let rest = try? h.read(upToCount: size) {
                    if let d = ID3Artwork.picture(in: top + rest), isImage(d) { return d }
                }
            }
        }
        return nil
    }

    static func isImage(_ d: Data) -> Bool { !d.isEmpty && CGImageSourceCreateWithData(d as CFData, nil).map { CGImageSourceGetCount($0) > 0 } == true }

    private final class Box: @unchecked Sendable { var data: Data? }

    /// AVFoundation's view of the file's metadata (ID3, iTunes atoms, ...), with a time limit so a damaged file cannot hold anything up.
    static func avArtwork(_ url: URL) -> Data? {
        let box = Box(), done = DispatchSemaphore(value: 0)
        let asset = AVURLAsset(url: url)
        Task.detached {
            if let items = try? await asset.load(.metadata) {
                for item in items {
                    let isArt = item.commonKey == .commonKeyArtwork || item.identifier == .id3MetadataAttachedPicture || item.identifier == .iTunesMetadataCoverArt
                    if isArt, let d = try? await item.load(.dataValue), !d.isEmpty { box.data = d; break }
                }
            }
            done.signal()
        }
        return done.wait(timeout: .now() + 5) == .success ? box.data : nil
    }
}

/// The picture of an ID3v2 tag (versions 2.2, 2.3 and 2.4), read from the bytes of the tag. A damaged or truncated tag gives nil, never a crash.
public enum ID3Artwork {
    public static let maxTag = 16_000_000

    public static func picture(in d: Data) -> Data? {
        let b = [UInt8](d)
        guard b.count >= 10, b[0] == 0x49, b[1] == 0x44, b[2] == 0x33 else { return nil }
        let version = Int(b[3]), flags = b[5]
        guard version >= 2, version <= 4, b[6..<10].allSatisfy({ $0 < 0x80 }) else { return nil }
        let size = Int(b[6]) << 21 | Int(b[7]) << 14 | Int(b[8]) << 7 | Int(b[9])
        var end = min(10 + size, b.count)
        var p = 10
        if flags & 0x40 != 0, version >= 3, p + 4 <= end {          // an extended header: skip it
            let n = version == 4 ? (Int(b[p]) << 21 | Int(b[p + 1]) << 14 | Int(b[p + 2]) << 7 | Int(b[p + 3])) : (Int(b[p]) << 24 | Int(b[p + 1]) << 16 | Int(b[p + 2]) << 8 | Int(b[p + 3]) + 4)
            p += max(n, 0)
        }
        let header = version == 2 ? 6 : 10
        end = max(end, p)
        while p + header <= end {
            if b[p] == 0 { break }                                    // padding
            let id = String(decoding: b[p..<(p + (version == 2 ? 3 : 4))], as: UTF8.self)
            let fsize: Int
            if version == 2 { fsize = Int(b[p + 3]) << 16 | Int(b[p + 4]) << 8 | Int(b[p + 5]) }
            else if version == 3 { fsize = Int(b[p + 4]) << 24 | Int(b[p + 5]) << 16 | Int(b[p + 6]) << 8 | Int(b[p + 7]) }
            else { fsize = Int(b[p + 4]) << 21 | Int(b[p + 5]) << 14 | Int(b[p + 6]) << 7 | Int(b[p + 7]) }
            let fflags = version == 2 ? 0 : Int(b[p + 8]) << 8 | Int(b[p + 9])
            let start = p + header, stop = start + fsize
            guard fsize > 0, stop <= b.count, stop <= end else { return nil }
            if id == "APIC" || id == "PIC" {
                var body = Array(b[start..<stop])
                let unsync = (version == 4 && fflags & 0x0002 != 0) || flags & 0x80 != 0
                if unsync { body = removeUnsynchronisation(body) }
                if version == 4, fflags & 0x0001 != 0, body.count > 4 { body = Array(body[4...]) }     // a data length indicator
                if let img = image(inFrame: body, short: version == 2) { return img }
            }
            p = stop
        }
        return nil
    }

    static func removeUnsynchronisation(_ a: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []; out.reserveCapacity(a.count)
        var i = 0
        while i < a.count { out.append(a[i]); if a[i] == 0xFF, i + 1 < a.count, a[i + 1] == 0 { i += 1 }; i += 1 }
        return out
    }

    /// Text encoding, MIME type (or three letters), picture type, description, then the picture.
    static func image(inFrame f: [UInt8], short: Bool) -> Data? {
        guard f.count > 4 else { return nil }
        let enc = f[0]
        var i = 1
        if short { i += 3 } else { while i < f.count, f[i] != 0 { i += 1 }; i += 1 }
        i += 1                                                       // the picture type
        guard i < f.count else { return nil }
        if enc == 1 || enc == 2 {                                    // UTF-16: the description ends with two zero bytes
            while i + 1 < f.count, !(f[i] == 0 && f[i + 1] == 0) { i += 2 }
            i += 2
        } else { while i < f.count, f[i] != 0 { i += 1 }; i += 1 }
        guard i < f.count else { return nil }
        return Data(f[i...])
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
