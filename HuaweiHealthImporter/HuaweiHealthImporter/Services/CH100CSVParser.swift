import Foundation

/// Parses the bodyfat_export.csv exported from the decrypted CH100 scale database.
///
/// Expected header (produced by the sqlcipher export):
/// time,weight,bmi,body_fat_pct,muscle,water_pct,bone,bmr,visceral_fat,protein,body_age,score,resistance
///
/// Times are stored as local datetime strings ("yyyy-MM-dd HH:mm:ss") with no timezone offset.
/// They are parsed using the device's current calendar, which matches the user's recording timezone.
enum CH100CSVParser {

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    static func parse(url: URL) throws -> [CH100Row] {
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ImportError.fileReadFailed(url: url, underlying: error)
        }

        var lines = content.components(separatedBy: "\n")
        guard !lines.isEmpty else { return [] }
        lines.removeFirst() // drop header

        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return makeRow(from: parseCSVLine(trimmed))
        }
    }

    // MARK: - Private

    private static func makeRow(from cols: [String]) -> CH100Row? {
        guard cols.count >= 11 else { return nil }
        guard let date = dateFormatter.date(from: cols[0]) else { return nil }
        return CH100Row(
            time:       date,
            weight:     Double(cols[1]),
            bmi:        Double(cols[2]),
            bodyFatPct: Double(cols[3]),
            muscle:     Double(cols[4]),
            waterPct:   Double(cols[5]),
            bone:       Double(cols[6]),
            bmr:        Double(cols[7]),
            visceralFat: Double(cols[8]),
            protein:    Double(cols[9]),
            bodyAge:    Double(cols[10])
        )
    }

    /// Splits a CSV line on commas, stripping surrounding double-quotes from each field.
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            switch char {
            case "\"":
                inQuotes.toggle()
            case "," where !inQuotes:
                fields.append(current)
                current = ""
            default:
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}
