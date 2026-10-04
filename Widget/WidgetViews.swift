import SwiftUI
import WidgetKit

// MARK: - Shared pieces

struct CounterLabel: View {
    let entry: PrayerEntry
    var iconSize: CGFloat = 11
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: entry.signSymbol).font(.system(size: iconSize, weight: .heavy))
            Text(entry.counterText).monospacedDigit()
        }
    }
}

struct ProgressBar: View {
    let progress: Double
    let height: CGFloat
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.3))
                Capsule().fill(Color.white).frame(width: max(height, geo.size.width * progress))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Classic (previous / next / counter)

struct ClassicRectangular: View {
    let entry: PrayerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(entry.previous, highlighted: entry.showsElapsed)
            row(entry.next, highlighted: !entry.showsElapsed)
            CounterLabel(entry: entry)
                .font(.system(.headline, design: .rounded))
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ event: PrayerEvent?, highlighted: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: event?.prayer.symbol ?? "clock").font(.system(size: 11)).frame(width: 14)
            Text(entry.name(event))
            Spacer(minLength: 4)
            Text(entry.time(event)).monospacedDigit()
        }
        .font(.system(.body, design: .rounded).weight(highlighted ? .semibold : .regular))
        .opacity(highlighted ? 1 : 0.65)
        .lineLimit(1)
    }
}

struct ClassicCircular: View {
    let entry: PrayerEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(entry.name(entry.target))
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.6)
                CounterLabel(entry: entry, iconSize: 8)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
            .padding(4)
        }
    }
}

struct ClassicInline: View {
    let entry: PrayerEntry
    var body: some View {
        Text("\(entry.name(entry.target)) \(entry.time(entry.target))  \(entry.sign)\(entry.counterText)")
    }
}

struct ClassicSmall: View {
    let entry: PrayerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.target?.prayer.symbol ?? "clock")
                Spacer()
                CounterLabel(entry: entry).font(.system(.subheadline, design: .rounded).weight(.bold))
            }
            .font(.title3)
            Spacer(minLength: 0)
            row(entry.previous, dim: !entry.showsElapsed)
            row(entry.next, dim: entry.showsElapsed)
        }
        .foregroundColor(.white)
    }

    private func row(_ e: PrayerEvent?, dim: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.name(e)).font(.caption.weight(.medium)).opacity(0.8)
            Text(entry.time(e)).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
        }
        .opacity(dim ? 0.6 : 1)
    }
}

// MARK: - Countdown (big counter)

struct CountdownRectangular: View {
    let entry: PrayerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            HStack(spacing: 4) {
                Image(systemName: entry.target?.prayer.symbol ?? "clock")
                Text("\(entry.name(entry.target)) · \(entry.time(entry.target))")
            }
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .opacity(0.8)
            .lineLimit(1)
            HStack(alignment: .center, spacing: 3) {
                Image(systemName: entry.signSymbol).font(.system(size: 18, weight: .heavy))
                Text(entry.counterText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
            .widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CountdownCircular: View {
    let entry: PrayerEntry
    var body: some View {
        Gauge(value: entry.progress) {
            Image(systemName: entry.next?.prayer.symbol ?? "clock")
        } currentValueLabel: {
            Text("\(entry.sign)\(entry.counterText)").monospacedDigit()
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }
}

struct CountdownSmall: View {
    let entry: PrayerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: entry.target?.prayer.symbol ?? "clock").font(.title2)
            Spacer(minLength: 0)
            Text(entry.showsElapsed ? "since \(entry.name(entry.target))" : "until \(entry.name(entry.target))")
                .font(.subheadline.weight(.medium)).opacity(0.85)
            HStack(alignment: .center, spacing: 2) {
                Image(systemName: entry.signSymbol).font(.system(size: 18, weight: .heavy))
                Text(entry.counterText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
            }
            Text("at \(entry.time(entry.target))").font(.caption.weight(.semibold)).opacity(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundColor(.white)
    }
}

// MARK: - Progress (bar between previous and next)

struct ProgressRectangular: View {
    let entry: PrayerEntry
    var body: some View {
        VStack(spacing: 3) {
            HStack {
                label(entry.previous, alignment: .leading)
                Spacer(minLength: 2)
                CounterLabel(entry: entry, iconSize: 9)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .widgetAccentable()
                Spacer(minLength: 2)
                label(entry.next, alignment: .trailing)
            }
            ProgressBar(progress: entry.progress, height: 6)
                .widgetAccentable()
        }
    }

    private func label(_ e: PrayerEvent?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: -1) {
            HStack(spacing: 2) {
                Image(systemName: e?.prayer.symbol ?? "clock").font(.system(size: 9))
                Text(entry.name(e)).lineLimit(1)
            }
            .font(.system(.caption2, design: .rounded).weight(.medium))
            .opacity(0.8)
            Text(entry.time(e)).font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
        }
    }
}

struct ProgressCircular: View {
    let entry: PrayerEntry
    var body: some View {
        Gauge(value: entry.progress) {
            EmptyView()
        } currentValueLabel: {
            VStack(spacing: -1) {
                Image(systemName: entry.target?.prayer.symbol ?? "clock").font(.system(size: 11))
                Text("\(entry.sign)\(entry.counterText)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.6)
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

struct ProgressMedium: View {
    let entry: PrayerEntry
    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                block(entry.previous, alignment: .leading)
                Spacer()
                VStack(spacing: 0) {
                    CounterLabel(entry: entry, iconSize: 16)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(entry.showsElapsed ? "elapsed" : "remaining").font(.caption).opacity(0.8)
                }
                Spacer()
                block(entry.next, alignment: .trailing)
            }
            ProgressBar(progress: entry.progress, height: 8)
        }
        .foregroundColor(.white)
    }

    private func block(_ e: PrayerEvent?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Image(systemName: e?.prayer.symbol ?? "clock").font(.title3)
            Text(entry.name(e)).font(.subheadline.weight(.medium)).opacity(0.85)
            Text(entry.time(e)).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
        }
    }
}

// MARK: - Day (list of timings)

struct DayRectangular: View {
    let entry: PrayerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entry.upcoming.prefix(3).enumerated()), id: \.offset) { i, e in
                HStack(spacing: 4) {
                    Image(systemName: e.prayer.symbol).font(.system(size: 11)).frame(width: 14)
                    Text(entry.name(e))
                    Spacer(minLength: 4)
                    Text(entry.time(e)).monospacedDigit()
                }
                .font(.system(.body, design: .rounded).weight(i == 0 ? .bold : .regular))
                .opacity(i == 0 ? 1 : 0.65)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DayMedium: View {
    let entry: PrayerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.next.map { Formatters.day($0.date) } ?? "")
                    .font(.subheadline.weight(.semibold)).opacity(0.85)
                Spacer()
                CounterLabel(entry: entry)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
            }
            HStack(spacing: 0) {
                ForEach(entry.day) { e in
                    let current = e == entry.next
                    VStack(spacing: 4) {
                        Image(systemName: e.prayer.symbol).font(.system(size: 15))
                        Text(entry.name(e)).font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                        Text(entry.time(e)).font(.system(size: 14, weight: .bold, design: .rounded)).monospacedDigit()
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(current ? 0.25 : 0)))
                    .opacity(e.date < entry.date ? 0.55 : 1)
                }
            }
        }
        .foregroundColor(.white)
    }
}

struct DayLarge: View {
    let entry: PrayerEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.next.map { Formatters.day($0.date) } ?? "").font(.subheadline.weight(.semibold)).opacity(0.85)
            HStack(alignment: .firstTextBaseline) {
                Text(entry.showsElapsed ? "since \(entry.name(entry.target))" : "until \(entry.name(entry.target))")
                    .font(.headline)
                Spacer()
                CounterLabel(entry: entry, iconSize: 16).font(.system(size: 34, weight: .bold, design: .rounded))
            }
            ProgressBar(progress: entry.progress, height: 6).padding(.bottom, 6)
            ForEach(entry.day) { e in
                let current = e == entry.next
                HStack {
                    Image(systemName: e.prayer.symbol).frame(width: 26)
                    Text(entry.name(e)).font(.body.weight(current ? .bold : .medium))
                    Spacer()
                    Text(entry.time(e)).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(current ? 0.25 : 0)))
                .opacity(e.date < entry.date ? 0.55 : 1)
            }
            Spacer(minLength: 0)
        }
        .foregroundColor(.white)
    }
}
