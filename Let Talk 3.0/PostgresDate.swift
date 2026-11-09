import Foundation

/// Parses the timestamps Supabase/PostgREST sends, e.g. "2026-11-07T19:39:04.174123+00:00".
///
/// `JSONDecoder.DateDecodingStrategy.iso8601` rejects fractional seconds, and the default
/// strategy expects a number, so every profile, chat, message, call and signaling row failed
/// to decode. Use `PostgresDate.decoder` (or `.strategy`) for anything read from Supabase.
enum PostgresDate {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ raw: String) -> Date? {
        var s = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "T")
        var fraction: Double = 0

        // Pull out ".123456" (any number of digits) and add it back after parsing.
        if let dot = s.firstIndex(of: ".") {
            let afterDot = s.index(after: dot)
            let end = s[afterDot...].firstIndex(where: { !$0.isNumber }) ?? s.endIndex
            fraction = Double("0." + s[afterDot..<end]) ?? 0
            s.removeSubrange(dot..<end)
        }

        // Postgres "timestamp" (no time zone) has no offset; treat it as UTC.
        let time = s.split(separator: "T").last.map(String.init) ?? ""
        if !(time.hasSuffix("Z") || time.contains("+") || time.contains("-")) {
            s += "Z"
        }
        // "+00" -> "+00:00"
        if let r = s.range(of: #"[+-]\d{2}$"#, options: .regularExpression) {
            let offset = String(s[r]) + ":00"
            s.replaceSubrange(r, with: offset)
        }

        return formatter.date(from: s).map { $0.addingTimeInterval(fraction) }
    }

    static let strategy: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        if let seconds = try? container.decode(Double.self) {
            return Date(timeIntervalSince1970: seconds)
        }
        let string = try container.decode(String.self)
        guard let date = parse(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(string)")
        }
        return date
    }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = strategy
        return d
    }
}
