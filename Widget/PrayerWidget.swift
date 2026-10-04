import WidgetKit
import SwiftUI

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

extension View {
    /// Lock screen widgets get no background; home screen widgets get the time-of-day gradient.
    @ViewBuilder
    func widgetBackground(_ entry: PrayerEntry, home: Bool) -> some View {
        let gradient = PrayerTheme.gradient(for: entry.previous?.prayer)
        if #available(iOSApplicationExtension 17.0, *) {
            if home {
                containerBackground(for: .widget) { gradient }
            } else {
                containerBackground(for: .widget) { Color.clear }
            }
        } else if home {
            padding().background(gradient)
        } else {
            self
        }
    }
}

private func isHome(_ family: WidgetFamily) -> Bool {
    [.systemSmall, .systemMedium, .systemLarge].contains(family)
}

/// Picks the view for the current family and applies the right background.
struct StyledView<Content: View>: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry
    @ViewBuilder let content: (WidgetFamily) -> Content
    var body: some View {
        content(family).widgetBackground(entry, home: isHome(family))
    }
}

// MARK: - Widgets

struct PrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Shared.widgetKind, provider: Provider()) { entry in
            StyledView(entry: entry) { family in
                switch family {
                case .accessoryCircular: ClassicCircular(entry: entry)
                case .accessoryInline: ClassicInline(entry: entry)
                case .systemSmall: ClassicSmall(entry: entry)
                default: ClassicRectangular(entry: entry)
                }
            }
        }
        .configurationDisplayName("Classic")
        .description("Previous and next timing with elapsed / remaining time.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .systemSmall])
    }
}

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CountdownWidget", provider: Provider()) { entry in
            StyledView(entry: entry) { family in
                switch family {
                case .accessoryCircular: CountdownCircular(entry: entry)
                case .systemSmall: CountdownSmall(entry: entry)
                default: CountdownRectangular(entry: entry)
                }
            }
        }
        .configurationDisplayName("Countdown")
        .description("A big counter to the next timing.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall])
    }
}

struct ProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ProgressWidget", provider: Provider()) { entry in
            StyledView(entry: entry) { family in
                switch family {
                case .accessoryCircular: ProgressCircular(entry: entry)
                case .systemMedium: ProgressMedium(entry: entry)
                default: ProgressRectangular(entry: entry)
                }
            }
        }
        .configurationDisplayName("Progress")
        .description("A progress bar from the previous timing to the next.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemMedium])
    }
}

struct DayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayWidget", provider: Provider()) { entry in
            StyledView(entry: entry) { family in
                switch family {
                case .systemMedium: DayMedium(entry: entry)
                case .systemLarge: DayLarge(entry: entry)
                default: DayRectangular(entry: entry)
                }
            }
        }
        .configurationDisplayName("Day")
        .description("Upcoming timings at a glance.")
        .supportedFamilies([.accessoryRectangular, .systemMedium, .systemLarge])
    }
}

@main
struct PrayerWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerWidget()
        CountdownWidget()
        ProgressWidget()
        DayWidget()
    }
}
