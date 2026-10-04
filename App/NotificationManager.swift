import Foundation
import UserNotifications

struct PrayerNotificationSetting: Codable, Identifiable, Equatable {
    var prayer: Prayer
    var enabled: Bool
    var soundEnabled: Bool
    /// Negative = before the timing, positive = after.
    var offsetMinutes: Int
    /// "default" for the system sound, otherwise a file name in the bundle or Library/Sounds.
    var soundName: String

    var id: Int { prayer.rawValue }

    static var defaults: [PrayerNotificationSetting] {
        Prayer.allCases.map {
            PrayerNotificationSetting(prayer: $0, enabled: $0 != .sunrise, soundEnabled: true,
                                      offsetMinutes: 0, soundName: "default")
        }
    }
}

enum NotificationManager {
    private static let key = "notificationSettings"
    /// iOS keeps at most 64 pending local notifications per app.
    private static let maxPending = 64

    static var settings: [PrayerNotificationSetting] {
        get {
            guard let data = Shared.defaults.data(forKey: key),
                  let saved = try? JSONDecoder().decode([PrayerNotificationSetting].self, from: data)
            else { return PrayerNotificationSetting.defaults }
            // Make sure there's exactly one entry per prayer.
            return Prayer.allCases.map { p in
                saved.first { $0.prayer == p } ?? PrayerNotificationSetting.defaults[p.rawValue]
            }
        }
        set { Shared.defaults.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Replaces all pending notifications with the next ~10 days of timings.
    static func reschedule(schedule: Schedule) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        center.removeAllPendingNotificationRequests()

        let config = Dictionary(uniqueKeysWithValues: settings.map { ($0.prayer, $0) })
        let now = Date()
        let arabic = Settings.arabicNames

        // Look a bit into the past so negative offsets for upcoming timings aren't missed.
        let candidates = schedule.events
            .filter { $0.date > now.addingTimeInterval(-3 * 3600) }
            .compactMap { event -> (PrayerEvent, PrayerNotificationSetting, Date)? in
                guard let s = config[event.prayer], s.enabled else { return nil }
                let fire = event.date.addingTimeInterval(Double(s.offsetMinutes * 60))
                return fire > now ? (event, s, fire) : nil
            }
            .sorted { $0.2 < $1.2 }

        let toSchedule = Array(candidates.prefix(maxPending - 1))
        let cal = Shared.calendar

        for (event, s, fire) in toSchedule {
            let content = UNMutableNotificationContent()
            let name = event.prayer.name(arabic: arabic)
            let time = Formatters.time(event.date)
            content.title = name
            content.body = body(name: name, time: time, offset: s.offsetMinutes, arabic: arabic)
            content.sound = sound(for: s)
            if #available(iOS 15.0, *) { content.interruptionLevel = .active }

            var comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
            comps.timeZone = cal.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "prayer-\(event.prayer.rawValue)-\(Int(event.date.timeIntervalSince1970))"
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }

        // If the app isn't opened for a long time, remind the user so notifications don't silently stop.
        if candidates.count > toSchedule.count, let last = toSchedule.last {
            let content = UNMutableNotificationContent()
            content.title = "Prayer Times"
            content.body = "Open the app to keep prayer notifications scheduled."
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(60, last.2.timeIntervalSince(now) + 60), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "reminder", content: content, trigger: trigger))
        }
    }

    private static func body(name: String, time: String, offset: Int, arabic: Bool) -> String {
        if arabic {
            if offset == 0 { return "حان الآن موعد \(name) (\(time))" }
            if offset < 0 { return "\(name) بعد \(-offset) دقيقة (\(time))" }
            return "مضى \(offset) دقيقة على \(name) (\(time))"
        }
        if offset == 0 { return "It's time for \(name) (\(time))" }
        if offset < 0 { return "\(name) in \(-offset) min (\(time))" }
        return "\(name) was \(offset) min ago (\(time))"
    }

    private static func sound(for s: PrayerNotificationSetting) -> UNNotificationSound? {
        guard s.soundEnabled else { return nil }
        if s.soundName == "default" { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(s.soundName))
    }
}
