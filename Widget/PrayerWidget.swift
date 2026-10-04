import WidgetKit
import SwiftUI

struct PrayerEntry: TimelineEntry {
    let date: Date
    let previous: PrayerEvent?
    let next: PrayerEvent?
    let use24Hour: Bool
    let arabic: Bool
    let elapsedWindow: Int

    /// Elapsed (+) for the first `elapsedWindow` minutes after a timing, remaining (−) afterwards.
    var showsElapsed: Bool {
        guard let previous else { return false }
        return date.timeIntervalSince(previous.date) < Double(elapsedWindow * 60)
    }

    var counterMinutes: Int? {
        if showsElapsed, let previous {
            return Int(floor(date.timeIntervalSince(previous.date) / 60))
        }
        guard let next else { return nil }
        return Int(ceil(next.date.timeIntervalSince(date) / 60))
    }

    var counterText: String {
        counterMinutes.map(Formatters.duration(minutes:)) ?? "--"
    }

    static func make(at date: Date, schedule: Schedule) -> PrayerEntry {
        PrayerEntry(date: date,
                    previous: schedule.previous(at: date),
                    next: schedule.next(after: date),
                    use24Hour: Settings.use24Hour,
                    arabic: Settings.arabicNames,
                    elapsedWindow: Settings.elapsedWindowMinutes)
    }

    static let placeholder: PrayerEntry = {
        let now = Date()
        return PrayerEntry(date: now,
                           previous: PrayerEvent(prayer: .dhuhr, date: now.addingTimeInterval(-600)),
                           next: PrayerEvent(prayer: .asr, date: now.addingTimeInterval(9000)),
                           use24Hour: true, arabic: false, elapsedWindow: 30)
    }()
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(context.isPreview ? .placeholder : PrayerEntry.make(at: Date(), schedule: ScheduleStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        Task {
            AppConfig.reload()
            var schedule = ScheduleStore.load()
            if let updated = await ScheduleStore.autoUpdateIfNeeded() { schedule = updated }

            // One entry per minute for the next 3 hours, aligned to minute boundaries.
            let now = Date()
            let start = Date(timeIntervalSinceReferenceDate:
                                floor(now.timeIntervalSinceReferenceDate / 60) * 60)
            var entries = [PrayerEntry.make(at: now, schedule: schedule)]
            for minute in 1...180 {
                entries.append(.make(at: start.addingTimeInterval(Double(minute * 60)), schedule: schedule))
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }
}

// MARK: - Views

struct CounterLabel: View {
    let entry: PrayerEntry
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: entry.showsElapsed ? "plus" : "minus")
                .font(.system(size: 11, weight: .heavy))
            Text(entry.counterText)
                .monospacedDigit()
        }
    }
}

struct RectangularView: View {
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(entry.previous, highlighted: entry.showsElapsed)
            row(entry.next, highlighted: !entry.showsElapsed)
            CounterLabel(entry: entry)
                .font(.headline)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func row(_ event: PrayerEvent?, highlighted: Bool) -> some View {
        HStack {
            Text(event?.prayer.name(arabic: entry.arabic) ?? "—")
            Spacer(minLength: 4)
            Text(event.map { Formatters.time($0.date, use24Hour: entry.use24Hour) } ?? "--:--")
                .monospacedDigit()
        }
        .font(.system(.body, design: .rounded).weight(highlighted ? .semibold : .regular))
        .opacity(highlighted ? 1 : 0.7)
        .lineLimit(1)
    }
}

struct CircularView: View {
    let entry: PrayerEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text((entry.showsElapsed ? entry.previous : entry.next)?.prayer.name(arabic: entry.arabic) ?? "")
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                CounterLabel(entry: entry)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
            .padding(4)
        }
    }
}

struct InlineView: View {
    let entry: PrayerEntry
    var body: some View {
        let target = entry.showsElapsed ? entry.previous : entry.next
        let name = target?.prayer.name(arabic: entry.arabic) ?? ""
        let time = target.map { Formatters.time($0.date, use24Hour: entry.use24Hour) } ?? ""
        Text("\(name) \(time)  \(entry.showsElapsed ? "+" : "−")\(entry.counterText)")
    }
}

struct SmallView: View {
    let entry: PrayerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prayer Times").font(.caption).foregroundColor(.secondary)
            RectangularView(entry: entry)
            Spacer(minLength: 0)
        }
    }
}

struct PrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryCircular: CircularView(entry: entry)
        case .accessoryInline: InlineView(entry: entry)
        default: SmallView(entry: entry)
        }
    }
}

extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            self
        }
    }
}

struct PrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Shared.widgetKind, provider: Provider()) { entry in
            PrayerWidgetView(entry: entry).widgetBackground()
        }
        .configurationDisplayName("Prayer Times")
        .description("Previous and next prayer with elapsed / remaining time.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .systemSmall])
    }
}

@main
struct PrayerWidgetBundle: WidgetBundle {
    var body: some Widget { PrayerWidget() }
}
