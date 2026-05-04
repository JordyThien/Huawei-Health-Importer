import Foundation

/// Utilities for converting Huawei timestamp/timezone data to Swift `Date` and `TimeZone`.
enum TimeZoneParser {

    /// Parses a Huawei timezone offset string such as `"+0200"` or `"-0530"` into a `TimeZone`.
    /// Returns `TimeZone.current` if the string cannot be parsed.
    static func parseOffset(_ raw: String?) -> TimeZone {
        guard let raw = raw else { return .current }
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard s.count >= 5 else { return .current }

        let sign: Int
        var rest: String
        if s.hasPrefix("+") {
            sign = 1
            rest = String(s.dropFirst())
        } else if s.hasPrefix("-") {
            sign = -1
            rest = String(s.dropFirst())
        } else {
            // No explicit sign — treat as positive
            sign = 1
            rest = s
        }

        // Expect HHMM (4 digits) or HH:MM (5 chars)
        rest = rest.replacingOccurrences(of: ":", with: "")
        guard rest.count >= 4,
              let hours = Int(rest.prefix(2)),
              let minutes = Int(rest.dropFirst(2).prefix(2)) else {
            return .current
        }

        let totalSeconds = sign * (hours * 3600 + minutes * 60)
        return TimeZone(secondsFromGMT: totalSeconds) ?? .current
    }

    /// Converts a Unix millisecond timestamp to a `Date`.
    static func date(fromUnixMs ms: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
    }
}
