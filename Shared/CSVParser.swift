import Foundation

enum CSVParseError: LocalizedError {
    case empty
    case missingColumns([String])
    case noRows

    var errorDescription: String? {
        switch self {
        case .empty: return "The file is empty."
        case .missingColumns(let cols): return "Missing column(s): \(cols.joined(separator: ", "))."
        case .noRows: return "No valid rows were found."
        }
    }
}

/// Parses the ministry CSV:
///     date,dawn,sunrise,duhr,asr,sunset,isha
///     01/01/2026,06:09,07:30,12:40,15:25,17:50,19:10
/// Column order doesn't matter. Dates may be dd/MM/yyyy, dd-MM-yyyy or yyyy-MM-dd.
enum CSVParser {
    static func parse(_ text: String, timeZone: TimeZone) throws -> [PrayerEvent] {
        let lines = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let headerLine = lines.first else { throw CSVParseError.empty }

        let separator: Character = headerLine.contains(";") && !headerLine.contains(",") ? ";" : ","
        let header = split(headerLine, separator).map { $0.lowercased() }

        guard let dateIndex = header.firstIndex(where: { $0 == "date" || $0 == "day" || $0 == "التاريخ" }) else {
            throw CSVParseError.missingColumns(["date"])
        }
        var columnIndex: [Prayer: Int] = [:]
        var missing: [String] = []
        for prayer in Prayer.allCases {
            if let i = header.firstIndex(where: { prayer.csvKeys.contains($0) }) {
                columnIndex[prayer] = i
            } else {
                missing.append(prayer.csvKeys[0])
            }
        }
        guard missing.isEmpty else { throw CSVParseError.missingColumns(missing) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var events: [PrayerEvent] = []
        for line in lines.dropFirst() {
            let fields = split(line, separator)
            guard fields.count > dateIndex, let day = parseDate(fields[dateIndex]) else { continue }
            for prayer in Prayer.allCases {
                let i = columnIndex[prayer]!
                guard fields.count > i, let (h, m) = parseTime(fields[i]) else { continue }
                var comps = DateComponents()
                comps.year = day.y; comps.month = day.m; comps.day = day.d
                comps.hour = h; comps.minute = m
                if let date = calendar.date(from: comps) {
                    events.append(PrayerEvent(prayer: prayer, date: date))
                }
            }
        }
        guard !events.isEmpty else { throw CSVParseError.noRows }
        return events.sorted { $0.date < $1.date }
    }

    private static func split(_ line: String, _ sep: Character) -> [String] {
        line.split(separator: sep, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\""))) }
    }

    private static func parseDate(_ s: String) -> (y: Int, m: Int, d: Int)? {
        let parts = s.split(whereSeparator: { $0 == "/" || $0 == "-" || $0 == "." }).compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        if parts[0] > 31 { return (parts[0], parts[1], parts[2]) }   // yyyy-MM-dd
        return (parts[2], parts[1], parts[0])                          // dd/MM/yyyy
    }

    private static func parseTime(_ s: String) -> (Int, Int)? {
        let parts = s.split(separator: ":").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count >= 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return (parts[0], parts[1])
    }
}
