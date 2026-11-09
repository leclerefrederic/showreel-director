import Compression
import Foundation

/// What a package may hold, so that a damaged or hostile file cannot fill the disk or the memory. Sizes are in bytes.
public struct PackageLimits: Equatable, Sendable {
    public var maxEntries: Int
    public var maxFileSize: Int
    public var maxTotalSize: Int
    public static let standard = PackageLimits(maxEntries: 400, maxFileSize: 40_000_000, maxTotalSize: 150_000_000)
    public init(maxEntries: Int, maxFileSize: Int, maxTotalSize: Int) { self.maxEntries = maxEntries; self.maxFileSize = maxFileSize; self.maxTotalSize = maxTotalSize }
}

public enum PackageError: Error, LocalizedError, Equatable {
    case notAnArchive(String)
    case unsafe(String)
    case tooLarge(String)
    case unexpected(String)
    case invalid(String)
    case newerFormat(String)

    public var errorDescription: String? {
        switch self {
        case .notAnArchive(let m), .unsafe(let m), .tooLarge(let m), .unexpected(let m), .invalid(let m), .newerFormat(let m): return m
        }
    }
}

/// A zip file read and written by the app itself, with no other tool: the whole archive is checked (names, kinds, sizes, count) from its directory before one byte of an
/// entry is read, and nothing is ever extracted to disk or run. It reads stored and deflated entries and writes stored ones (the package's files are already compressed,
/// and the same content then gives the same bytes).
public enum PackageZip {
    public struct Entry: Equatable, Sendable {
        public let name: String
        public let data: Data
        /// False when the stored checksum does not match the content: the file is damaged.
        public let crcOK: Bool
    }

    // MARK: names

    /// The refusal for an entry name, or nil when it is a plain relative path with no way out of its folder.
    public static func nameProblem(_ name: String) -> String? {
        if name.isEmpty { return "an entry has no name" }
        if name.utf8.count > 220 { return "an entry name is too long" }
        if name.contains("\0") || name.contains("\\") { return "the entry \u{201C}\(name)\u{201D} has a character that is not allowed in a path" }
        if name.hasPrefix("/") || name.hasPrefix("~") { return "the entry \u{201C}\(name)\u{201D} is an absolute path" }
        if name.range(of: #"^[A-Za-z]:"#, options: .regularExpression) != nil { return "the entry \u{201C}\(name)\u{201D} is an absolute path" }
        let parts = name.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        for (i, p) in parts.enumerated() {
            if p == ".." || p == "." { return "the entry \u{201C}\(name)\u{201D} goes out of its folder" }
            if p.isEmpty, i != parts.count - 1 { return "the entry \u{201C}\(name)\u{201D} has an empty folder name" }
        }
        return nil
    }

    // MARK: reading

    static func u16(_ d: Data, _ o: Int) -> Int { Int(d[d.startIndex + o]) | Int(d[d.startIndex + o + 1]) << 8 }
    static func u32(_ d: Data, _ o: Int) -> Int { u16(d, o) | u16(d, o + 2) << 16 }

    struct Header { var name: String; var flags: Int; var method: Int; var crc: UInt32; var csize: Int; var usize: Int; var offset: Int; var madeBy: Int; var attrs: Int }

    /// The entries of an archive, in the order they were written, after the whole directory passed the checks. Throws on the first thing that is not acceptable.
    public static func read(_ data: Data, limits: PackageLimits = .standard) throws -> [Entry] {
        guard data.count >= 22 else { throw PackageError.notAnArchive("this file is not a package (it is not a zip archive)") }
        // the end-of-directory record: the last 22 bytes, or before a comment
        var eocd = -1
        var i = data.count - 22
        let floor = max(0, data.count - 22 - 65535)
        while i >= floor {
            if u32(data, i) == 0x06054b50, i + 22 + u16(data, i + 20) == data.count { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw PackageError.notAnArchive("this file is not a package (it is not a zip archive)") }
        let disk = u16(data, eocd + 4), cdDisk = u16(data, eocd + 6), here = u16(data, eocd + 8), total = u16(data, eocd + 10)
        let cdSize = u32(data, eocd + 12), cdOffset = u32(data, eocd + 16)
        guard disk == 0, cdDisk == 0, here == total else { throw PackageError.unexpected("an archive in several parts is not accepted") }
        if total == 0xFFFF || cdSize == 0xFFFF_FFFF || cdOffset == 0xFFFF_FFFF { throw PackageError.tooLarge("the archive is too large for a package") }
        guard total <= limits.maxEntries else { throw PackageError.tooLarge("the package holds \(total) entries, more than the \(limits.maxEntries) allowed") }
        guard cdOffset >= 0, cdSize >= 0, cdOffset + cdSize <= eocd else { throw PackageError.notAnArchive("the archive's directory is damaged") }

        var headers: [Header] = []
        var p = cdOffset
        var seen = Set<String>()
        var declaredTotal = 0
        for _ in 0..<total {
            guard p + 46 <= eocd, u32(data, p) == 0x02014b50 else { throw PackageError.notAnArchive("the archive's directory is damaged") }
            let madeBy = u16(data, p + 4), flags = u16(data, p + 8), method = u16(data, p + 10)
            let crc = UInt32(truncatingIfNeeded: u32(data, p + 16)), csize = u32(data, p + 20), usize = u32(data, p + 24)
            let nlen = u16(data, p + 28), xlen = u16(data, p + 30), clen = u16(data, p + 32), attrs = u32(data, p + 38), off = u32(data, p + 42)
            guard p + 46 + nlen + xlen + clen <= eocd else { throw PackageError.notAnArchive("the archive's directory is damaged") }
            guard let name = String(data: data.subdata(in: (data.startIndex + p + 46)..<(data.startIndex + p + 46 + nlen)), encoding: .utf8) else {
                throw PackageError.unsafe("an entry name is not valid text")
            }
            p += 46 + nlen + xlen + clen
            if let why = nameProblem(name) { throw PackageError.unsafe(why) }
            guard seen.insert(name.lowercased()).inserted else { throw PackageError.unsafe("the entry \u{201C}\(name)\u{201D} appears twice") }
            if flags & 1 != 0 { throw PackageError.unexpected("the entry \u{201C}\(name)\u{201D} is encrypted") }
            if madeBy >> 8 == 3 {          // made on a Unix system: the permissions say what kind of entry it is
                let kind = (attrs >> 16) & 0xF000
                if kind == 0xA000 { throw PackageError.unsafe("the entry \u{201C}\(name)\u{201D} is a symbolic link") }
                if kind != 0, kind != 0x8000, kind != 0x4000 { throw PackageError.unsafe("the entry \u{201C}\(name)\u{201D} is not a plain file") }
            }
            if name.hasSuffix("/") { continue }            // a folder: nothing to read
            guard method == 0 || method == 8 else { throw PackageError.unexpected("the entry \u{201C}\(name)\u{201D} uses a compression the app does not read") }
            if usize == 0xFFFF_FFFF || csize == 0xFFFF_FFFF { throw PackageError.tooLarge("the entry \u{201C}\(name)\u{201D} is too large") }
            guard usize <= limits.maxFileSize else { throw PackageError.tooLarge("the entry \u{201C}\(name)\u{201D} is larger than the \(limits.maxFileSize / 1_000_000) MB allowed for one file") }
            declaredTotal += usize
            guard declaredTotal <= limits.maxTotalSize else { throw PackageError.tooLarge("the package is larger than the \(limits.maxTotalSize / 1_000_000) MB allowed") }
            headers.append(Header(name: name, flags: flags, method: method, crc: crc, csize: csize, usize: usize, offset: off, madeBy: madeBy, attrs: attrs))
        }
        // the first entry in the file is the one written first: it must be the manifest
        headers.sort { $0.offset < $1.offset }
        var out: [Entry] = []
        for h in headers {
            guard h.offset + 30 <= cdOffset, u32(data, h.offset) == 0x04034b50 else { throw PackageError.notAnArchive("the entry \u{201C}\(h.name)\u{201D} is damaged") }
            let start = h.offset + 30 + u16(data, h.offset + 26) + u16(data, h.offset + 28)
            guard start >= 0, start + h.csize <= cdOffset else { throw PackageError.notAnArchive("the entry \u{201C}\(h.name)\u{201D} is damaged") }
            let raw = data.subdata(in: (data.startIndex + start)..<(data.startIndex + start + h.csize))
            var content: Data
            if h.method == 0 {
                guard h.csize == h.usize else { throw PackageError.notAnArchive("the entry \u{201C}\(h.name)\u{201D} is damaged") }
                content = raw
            } else {
                guard let d = inflate(raw, size: h.usize) else { throw PackageError.notAnArchive("the entry \u{201C}\(h.name)\u{201D} cannot be read: it is damaged") }
                content = d
            }
            out.append(Entry(name: h.name, data: content, crcOK: crc32(content) == h.crc))
        }
        return out
    }

    /// Raw deflate to exactly `size` bytes (the size comes from the directory, which the limits already bounded): a bomb cannot grow past it.
    static func inflate(_ raw: Data, size: Int) -> Data? {
        if size == 0 { return raw.isEmpty ? Data() : nil }
        var out = Data(count: size)
        let n = out.withUnsafeMutableBytes { dst in
            raw.withUnsafeBytes { src in
                compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, size, src.bindMemory(to: UInt8.self).baseAddress!, raw.count, nil, COMPRESSION_ZLIB)
            }
        }
        return n == size ? out : nil
    }

    // MARK: writing

    /// A zip with the entries in the given order, stored, with a fixed date: the same entries give the same bytes.
    public static func write(_ entries: [(name: String, data: Data)], checkNames: Bool = true) throws -> Data {
        var out = Data()
        var central = Data()
        func le16(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
        func le32(_ v: Int) -> [UInt8] { le16(v & 0xFFFF) + le16((v >> 16) & 0xFFFF) }
        for e in entries {
            if checkNames, let why = nameProblem(e.name) { throw PackageError.unsafe(why) }
            guard e.data.count < 0xFFFF_FFFF, out.count < 0xFFFF_FFFF else { throw PackageError.tooLarge("the package is too large") }
            let name = Data(e.name.utf8), crc = Int(crc32(e.data)), offset = out.count
            var local = Data(le32(0x04034b50) + le16(20) + le16(0x0800) + le16(0) + le16(0) + le16(0x0021) + le32(crc) + le32(e.data.count) + le32(e.data.count) + le16(name.count) + le16(0))
            local.append(name)
            out.append(local); out.append(e.data)
            var c = Data(le32(0x02014b50) + le16(0x0314) + le16(20) + le16(0x0800) + le16(0) + le16(0) + le16(0x0021) + le32(crc) + le32(e.data.count) + le32(e.data.count)
                         + le16(name.count) + le16(0) + le16(0) + le16(0) + le16(0) + le32(0o100644 << 16) + le32(offset))
            c.append(name)
            central.append(c)
        }
        let cdOffset = out.count
        out.append(central)
        out.append(Data(le32(0x06054b50) + le16(0) + le16(0) + le16(entries.count) + le16(entries.count) + le32(central.count) + le32(cdOffset) + le16(0)))
        return out
    }

    // MARK: checksum

    static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    public static func crc32(_ d: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in d { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}
