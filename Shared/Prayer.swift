import Foundation

/// The six daily timings published by the ministry.
enum Prayer: Int, CaseIterable, Codable, Identifiable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha

    var id: Int { rawValue }

    var englishName: String {
        switch self {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }

    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .sunrise: return "الشروق"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }

    func name(arabic: Bool) -> String { arabic ? arabicName : englishName }

    var symbol: String {
        switch self {
        case .fajr: return "sun.haze"
        case .sunrise: return "sunrise"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.min"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
        }
    }

    /// Accepted CSV header names (lowercased) for this column.
    var csvKeys: [String] {
        switch self {
        case .fajr: return ["dawn", "fajr", "fajer", "subh"]
        case .sunrise: return ["sunrise", "shurooq", "shuruq", "shrouq"]
        case .dhuhr: return ["duhr", "dhuhr", "zuhr", "thuhr", "dhuhur", "noon"]
        case .asr: return ["asr"]
        case .maghrib: return ["sunset", "maghrib", "magrib"]
        case .isha: return ["isha", "ishaa", "esha"]
        }
    }
}

struct PrayerEvent: Codable, Hashable, Identifiable {
    let prayer: Prayer
    let date: Date
    var id: Date { date }
}

struct Schedule: Codable {
    /// All timings, sorted ascending.
    var events: [PrayerEvent]
    /// Human-readable description of where the data came from.
    var source: String
    var updatedAt: Date
    /// Raw CSV, kept so timings can be re-read if the configured time zone changes.
    var csv: String? = nil

    var firstDate: Date? { events.first?.date }
    var lastDate: Date? { events.last?.date }

    func previous(at date: Date) -> PrayerEvent? {
        // Binary search for the last event <= date.
        var lo = 0, hi = events.count - 1, result: PrayerEvent?
        while lo <= hi {
            let mid = (lo + hi) / 2
            if events[mid].date <= date { result = events[mid]; lo = mid + 1 } else { hi = mid - 1 }
        }
        return result
    }

    func next(after date: Date) -> PrayerEvent? {
        var lo = 0, hi = events.count - 1, result: PrayerEvent?
        while lo <= hi {
            let mid = (lo + hi) / 2
            if events[mid].date > date { result = events[mid]; hi = mid - 1 } else { lo = mid + 1 }
        }
        return result
    }

    func upcoming(from date: Date, limit: Int = .max) -> [PrayerEvent] {
        guard let first = events.firstIndex(where: { $0.date > date }) else { return [] }
        return Array(events[first..<min(events.count, first + limit)])
    }

    /// Timings that fall on the same calendar day (in `calendar`'s time zone) as `day`.
    func events(onDayOf day: Date, calendar: Calendar) -> [PrayerEvent] {
        events.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }
}
