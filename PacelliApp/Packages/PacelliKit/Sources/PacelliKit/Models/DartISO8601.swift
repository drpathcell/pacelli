import Foundation

/// Date codec compatible with Dart's `DateTime.now().toIso8601String()` /
/// `DateTime.parse` as used across Pacelli's Firestore documents.
///
/// Dart writes **local** time with fractional seconds and **no timezone
/// suffix** (e.g. `2026-07-07T17:30:00.123456`). Existing documents contain
/// exactly that shape, so the Swift port must read it — and write the same
/// shape so Dart/TS readers keep working.
public enum DartISO8601 {
    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current  // Dart DateTime.now() is local time
        f.dateFormat = format
        return f
    }

    private static let writeFormatter = formatter("yyyy-MM-dd'T'HH:mm:ss.SSSSSS")

    /// Read candidates, most→least specific. Covers Dart local (6- or
    /// 3-digit fractions), UTC-suffixed, and second-precision strings.
    private static let readFormatters: [DateFormatter] = [
        formatter("yyyy-MM-dd'T'HH:mm:ss.SSSSSS"),
        formatter("yyyy-MM-dd'T'HH:mm:ss.SSS"),
        formatter("yyyy-MM-dd'T'HH:mm:ss"),
        {
            let f = formatter("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'")
            f.timeZone = TimeZone(identifier: "UTC")
            return f
        }(),
        {
            let f = formatter("yyyy-MM-dd'T'HH:mm:ss'Z'")
            f.timeZone = TimeZone(identifier: "UTC")
            return f
        }(),
    ]

    public static func string(from date: Date) -> String {
        writeFormatter.string(from: date)
    }

    public static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        for f in readFormatters {
            if let d = f.date(from: string) { return d }
        }
        return nil
    }
}

/// Date-only codec compatible with Dart's `_dateOnly` helper
/// (`yyyy-MM-dd`, zero-padded, local time — used for plan
/// `start_date`/`end_date`/`entry_date`). Dart parses these as local
/// midnight; so do we.
public enum DartDateOnly {
    private static let f: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static func string(from date: Date) -> String {
        f.string(from: date)
    }

    public static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return f.date(from: string)
    }
}
