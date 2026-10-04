import WidgetKit
import SwiftUI

struct PrayerEntry: TimelineEntry {
    let date: Date
    let previous: PrayerEvent?
    let next: PrayerEvent?
    /// The next few timings after `date` (first == next).
    let upcoming: [PrayerEvent]
    /// The six timings of the day being shown (tomorrow's once Isha has passed).
    let day: [PrayerEvent]
    let use24Hour: Bool
    let arabic: Bool
    let elapsedWindow: Int

    /// Elapsed (+) for the first `elapsedWindow` minutes after a timing, remaining (−) afterwards.
    var showsElapsed: Bool {
        guard let previous else { return false }
        return date.timeIntervalSince(previous.date) < Double(elapsedWindow * 60)
    }

    /// The timing the counter refers to.
    var target: PrayerEvent? { showsElapsed ? previous : next }

    var counterMinutes: Int? {
        if showsElapsed, let previous {
            return Int(floor(date.timeIntervalSince(previous.date) / 60))
        }
        guard let next else { return nil }
        return Int(ceil(next.date.timeIntervalSince(date) / 60))
    }

    var counterText: String { counterMinutes.map(Formatters.duration(minutes:)) ?? "--" }
    var sign: String { showsElapsed ? "+" : "−" }
    var signSymbol: String { showsElapsed ? "plus" : "minus" }

    /// 0…1 progress from the previous timing to the next.
    var progress: Double {
        guard let previous, let next else { return 0 }
        let total = next.date.timeIntervalSince(previous.date)
        return total > 0 ? min(1, max(0, date.timeIntervalSince(previous.date) / total)) : 0
    }

    func name(_ e: PrayerEvent?) -> String { e?.prayer.name(arabic: arabic) ?? "—" }
    func time(_ e: PrayerEvent?) -> String { e.map { Formatters.time($0.date, use24Hour: use24Hour) } ?? "--:--" }

    static func make(at date: Date, schedule: Schedule) -> PrayerEntry {
        let next = schedule.next(after: date)
        let upcoming = schedule.upcoming(from: date, limit: 3)
        let dayRef = next?.date ?? date
        return PrayerEntry(date: date,
                           previous: schedule.previous(at: date),
                           next: next,
                           upcoming: upcoming,
                           day: schedule.events(onDayOf: dayRef, calendar: Shared.calendar),
                           use24Hour: Settings.use24Hour,
                           arabic: Settings.arabicNames,
                           elapsedWindow: Settings.elapsedWindowMinutes)
    }

    static func sample(minutesSincePrevious: Double = 10) -> PrayerEntry {
        let now = Date()
        let start = now.addingTimeInterval(-minutesSincePrevious * 60 - 12 * 3600)
        let gaps: [Double] = [0, 75, 360, 200, 155, 75, 600, 75]
        var t = start, events: [PrayerEvent] = []
        for (i, g) in gaps.enumerated() {
            t = t.addingTimeInterval(g * 60)
            events.append(PrayerEvent(prayer: Prayer(rawValue: i % 6)!, date: t))
        }
        // Shift so `now` is minutesSincePrevious after Dhuhr.
        let dhuhr = events[2].date
        let shift = now.addingTimeInterval(-minutesSincePrevious * 60).timeIntervalSince(dhuhr)
        let shifted = events.map { PrayerEvent(prayer: $0.prayer, date: $0.date.addingTimeInterval(shift)) }
        let s = Schedule(events: shifted, source: "sample", updatedAt: now)
        let e = make(at: now, schedule: s)
        return PrayerEntry(date: e.date, previous: e.previous, next: e.next, upcoming: e.upcoming,
                           day: Array(shifted[0..<6]), use24Hour: true, arabic: false, elapsedWindow: 30)
    }

    static let placeholder = sample()
}

/// Colours for home screen widgets, following the time of day.
enum PrayerTheme {
    static func gradient(for prayer: Prayer?) -> LinearGradient {
        let colors: [Color]
        switch prayer {
        case .fajr: colors = [Color(red: 0.16, green: 0.18, blue: 0.42), Color(red: 0.45, green: 0.33, blue: 0.62)]
        case .sunrise: colors = [Color(red: 0.98, green: 0.62, blue: 0.40), Color(red: 0.93, green: 0.42, blue: 0.48)]
        case .dhuhr: colors = [Color(red: 0.20, green: 0.56, blue: 0.90), Color(red: 0.45, green: 0.75, blue: 0.98)]
        case .asr: colors = [Color(red: 0.10, green: 0.50, blue: 0.60), Color(red: 0.85, green: 0.65, blue: 0.30)]
        case .maghrib: colors = [Color(red: 0.92, green: 0.40, blue: 0.25), Color(red: 0.55, green: 0.20, blue: 0.40)]
        case .isha, .none: colors = [Color(red: 0.05, green: 0.08, blue: 0.20), Color(red: 0.15, green: 0.20, blue: 0.40)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
