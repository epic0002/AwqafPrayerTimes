import BackgroundTasks
import SwiftUI
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    static let refreshTaskID = "app.prayertimesjo.refresh"

    @Published var schedule: Schedule = ScheduleStore.load()
    @Published var notificationSettings = NotificationManager.settings
    @Published var isUpdating = false
    @Published var statusMessage: String?
    @Published var now = Date()
    @Published var config = AppConfig.current

    @Published var sourceMode = Settings.sourceMode { didSet { Settings.sourceMode = sourceMode } }
    @Published var customURL = Settings.customURL { didSet { Settings.customURL = customURL } }
    @Published var use24Hour = Settings.use24Hour { didSet { Settings.use24Hour = use24Hour; applyChanges() } }
    @Published var arabicNames = Settings.arabicNames { didSet { Settings.arabicNames = arabicNames; applyChanges() } }
    @Published var elapsedWindow = Settings.elapsedWindowMinutes {
        didSet { Settings.elapsedWindowMinutes = elapsedWindow; applyChanges() }
    }

    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
    }

    var dataRunsOutSoon: Bool {
        (schedule.lastDate ?? .distantPast) < Date().addingTimeInterval(7 * 86_400)
    }

    func onForeground() async {
        now = Date()
        await NotificationManager.requestAuthorization()
        if let updated = await ScheduleStore.autoUpdateIfNeeded() {
            schedule = updated
            statusMessage = "Downloaded new timings."
        }
        applyChanges()
        Self.scheduleBackgroundRefresh()
    }

    func updateNow() async {
        isUpdating = true
        defer { isUpdating = false }
        do {
            let fresh = try await ScheduleStore.fetch(from: Settings.effectiveURL)
            try ScheduleStore.save(fresh)
            schedule = fresh
            sourceMode = .url
            statusMessage = "Updated: \(fresh.events.count / 6) days loaded."
            applyChanges()
        } catch {
            statusMessage = "Update failed: \(error.localizedDescription)"
        }
    }

    func importCSV(_ url: URL) {
        do {
            let imported = try ScheduleStore.importFile(at: url)
            try ScheduleStore.save(imported)
            schedule = imported
            sourceMode = .file
            statusMessage = "Imported \(imported.events.count / 6) days."
            applyChanges()
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    /// Call after config.json was edited or reset in the app.
    func configDidChange() {
        let old = config
        AppConfig.reload()
        config = AppConfig.current
        if config.timeZone != old.timeZone {
            schedule = ScheduleStore.reparsed(schedule)
            try? ScheduleStore.save(schedule)
        }
        applyChanges()
    }

    func saveNotificationSettings() {
        NotificationManager.settings = notificationSettings
        applyChanges()
    }

    /// Push the current data/settings to notifications and the widget.
    func applyChanges() {
        let schedule = self.schedule
        Task { await NotificationManager.reschedule(schedule: schedule) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Background refresh

    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: nil) { task in
            let work = Task {
                let schedule = await ScheduleStore.autoUpdateIfNeeded() ?? ScheduleStore.load()
                await NotificationManager.reschedule(schedule: schedule)
                WidgetCenter.shared.reloadAllTimelines()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
            scheduleBackgroundRefresh()
        }
    }

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date().addingTimeInterval(12 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
