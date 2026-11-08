import Foundation

/// Any JSON value. Used to keep the keys the app does not know, so a newer skill never loses data through a load and save.
public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// The value as Foundation objects, for JSONSerialization.
    public var any: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let b): return b
        case .number(let n): return n
        case .string(let s): return s
        case .array(let a): return a.map { $0.any }
        case .object(let o): return o.mapValues { $0.any }
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

/// A coding key made from any string, to read and write objects with keys we do not know.
struct DynamicKey: CodingKey, ExpressibleByStringLiteral {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
    init(stringLiteral value: String) { stringValue = value }
    init(_ s: String) { stringValue = s }
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

/// Reading and writing an object whose known keys are fields and whose other keys are kept as they were.
enum Keep {
    static func unknown(_ decoder: Decoder, known: Set<String>) throws -> [String: JSONValue] {
        let c = try decoder.container(keyedBy: DynamicKey.self)
        var out: [String: JSONValue] = [:]
        for k in c.allKeys where !known.contains(k.stringValue) { out[k.stringValue] = try c.decode(JSONValue.self, forKey: k) }
        return out
    }

    /// Known fields first (nil is left out), then the unknown keys. A known key never gets overwritten by an unknown one.
    static func encode(_ encoder: Encoder, fields: [(String, Encodable?)], unknown: [String: JSONValue]) throws {
        var c = encoder.container(keyedBy: DynamicKey.self)
        var written = Set<String>()
        for (k, v) in fields {
            guard let v = v else { continue }
            try c.encode(AnyEncodable(value: v), forKey: DynamicKey(k))
            written.insert(k)
        }
        for (k, v) in unknown where !written.contains(k) { try c.encode(v, forKey: DynamicKey(k)) }
    }
}
