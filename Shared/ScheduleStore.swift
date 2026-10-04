import Foundation

enum ScheduleStore {
    private static var fileURL: URL { Shared.dataDirectory.appendingPathComponent("schedule.json") }

    /// Saved schedule, or the CSV bundled with the app if nothing has been saved yet.
    static func load() -> Schedule {
        if let data = try? Data(contentsOf: fileURL),
           let schedule = try? JSONDecoder().decode(Schedule.self, from: data) {
            return schedule
        }
        return bundled() ?? Schedule(events: [], source: "none", updatedAt: .distantPast)
    }

    static func bundled() -> Schedule? {
        guard let url = Shared.appBundle.url(forResource: "times", withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let events = try? CSVParser.parse(text, timeZone: AppConfig.current.tz) else { return nil }
        return Schedule(events: events, source: "Bundled copy", updatedAt: .distantPast, csv: text)
    }

    /// Re-reads the stored CSV with the current time zone (after config.json changes).
    static func reparsed(_ schedule: Schedule) -> Schedule {
        guard let csv = schedule.csv,
              let events = try? CSVParser.parse(csv, timeZone: AppConfig.current.tz) else { return schedule }
        var s = schedule
        s.events = events
        return s
    }

    static func save(_ schedule: Schedule) throws {
        let data = try JSONEncoder().encode(schedule)
        try data.write(to: fileURL, options: .atomic)
    }

    static func fetch(from urlString: String) async throws -> Schedule {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme != nil else { throw URLError(.badURL) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("text/csv, text/plain, */*", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let events = try CSVParser.parse(text, timeZone: AppConfig.current.tz)
        return Schedule(events: events, source: urlString, updatedAt: Date(), csv: text)
    }

    static func importFile(at url: URL) throws -> Schedule {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let events = try CSVParser.parse(text, timeZone: AppConfig.current.tz)
        return Schedule(events: events, source: "File: \(url.lastPathComponent)", updatedAt: Date(), csv: text)
    }

    /// True when the data runs out soon (i.e. around the end of the year) and we're in URL mode.
    static func needsAutoUpdate(_ schedule: Schedule, now: Date = Date()) -> Bool {
        guard Settings.sourceMode == .url else { return false }
        let days = Double(AppConfig.current.autoUpdateDaysBeforeEnd ?? 7)
        let runsOutSoon = (schedule.lastDate ?? .distantPast) < now.addingTimeInterval(days * 86_400)
        let staleYear = Shared.calendar.component(.year, from: schedule.firstDate ?? .distantPast)
            < Shared.calendar.component(.year, from: now)
            && (schedule.lastDate ?? .distantPast) < now.addingTimeInterval(180 * 86_400)
        guard runsOutSoon || staleYear else { return false }
        // Don't hammer the server: at most one automatic attempt every 6 hours.
        if let last = Settings.lastAutoUpdateAttempt, now.timeIntervalSince(last) < 6 * 3600 { return false }
        return true
    }

    /// Fetches new data if the current data is about to run out. Returns the new schedule if updated.
    @discardableResult
    static func autoUpdateIfNeeded() async -> Schedule? {
        let current = load()
        guard needsAutoUpdate(current) else { return nil }
        Settings.lastAutoUpdateAttempt = Date()
        guard let fresh = try? await fetch(from: Settings.effectiveURL),
              (fresh.lastDate ?? .distantPast) > (current.lastDate ?? .distantPast) else { return nil }
        try? save(fresh)
        return fresh
    }
}
