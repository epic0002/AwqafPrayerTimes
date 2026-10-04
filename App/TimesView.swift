import SwiftUI

struct TimesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                if model.dataRunsOutSoon {
                    Section {
                        Label(model.sourceMode == .url
                              ? "Timings run out soon. The app will try to download next year's file automatically, or tap Update in Settings."
                              : "Timings run out soon. Import a new CSV file in Settings.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    }
                }

                Section { CountdownCard(schedule: model.schedule, now: model.now, arabic: model.arabicNames) }

                daySection(title: "Today", day: model.now)
                daySection(title: "Tomorrow", day: model.now.addingTimeInterval(86_400))
            }
            .navigationTitle("Prayer Times")
            .refreshable { await model.updateNow() }
        }
    }

    @ViewBuilder
    private func daySection(title: String, day: Date) -> some View {
        let events = model.schedule.events(onDayOf: day, calendar: Shared.calendar)
        let next = model.schedule.next(after: model.now)
        Section("\(title) — \(Formatters.day(day))") {
            if events.isEmpty {
                Text("No data for this day").foregroundColor(.secondary)
            }
            ForEach(events) { event in
                HStack {
                    Image(systemName: event.prayer.symbol).frame(width: 28)
                    Text(event.prayer.name(arabic: model.arabicNames))
                    Spacer()
                    Text(Formatters.time(event.date, use24Hour: model.use24Hour)).monospacedDigit()
                }
                .font(event == next ? .body.bold() : .body)
                .foregroundColor(event.date < model.now ? .secondary : (event == next ? .accentColor : .primary))
            }
        }
    }
}

struct CountdownCard: View {
    let schedule: Schedule
    let now: Date
    let arabic: Bool

    var body: some View {
        let prev = schedule.previous(at: now)
        let next = schedule.next(after: now)
        let elapsed = prev.map { now.timeIntervalSince($0.date) } ?? .infinity
        let showElapsed = elapsed < Double(Settings.elapsedWindowMinutes * 60)

        VStack(spacing: 8) {
            if showElapsed, let prev {
                Text(prev.prayer.name(arabic: arabic)).font(.title2.bold())
                Label(Formatters.duration(minutes: Int(elapsed / 60)), systemImage: "plus")
                    .font(.largeTitle.monospacedDigit())
                Text("since \(Formatters.time(prev.date))").foregroundColor(.secondary)
            } else if let next {
                Text(next.prayer.name(arabic: arabic)).font(.title2.bold())
                Label(Formatters.duration(minutes: Int(ceil(next.date.timeIntervalSince(now) / 60))),
                      systemImage: "minus")
                    .font(.largeTitle.monospacedDigit())
                Text("at \(Formatters.time(next.date))").foregroundColor(.secondary)
            } else {
                Text("No upcoming timings").foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
