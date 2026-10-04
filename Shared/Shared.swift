import Foundation

/// Values read from `config.json`, which lives in the app bundle as a plain
/// resource (not compiled into the binary) so it can be edited without rebuilding.
/// The bundle is read-only on device, so edits made in the app are saved as a copy
/// in the shared container, which takes precedence over the bundled file.
struct AppConfig: Codable, Equatable {
    var defaultURL: String
    var timeZone: String
    var autoUpdateDaysBeforeEnd: Int?

    static let fallback = AppConfig(defaultURL: "https://awqaf-prayer.netlify.app/times.csv",
                                    timeZone: "Asia/Amman",
                                    autoUpdateDaysBeforeEnd: 7)

    static var editedURL: URL { Shared.dataDirectory.appendingPathComponent("config.json") }
    static var bundledURL: URL? { Shared.appBundle.url(forResource: "config", withExtension: "json") }

    static var isEdited: Bool { FileManager.default.fileExists(atPath: editedURL.path) }

    private static var cached: AppConfig?

    static var current: AppConfig {
        if let cached { return cached }
        let config = [editedURL, bundledURL].lazy
            .compactMap { $0 }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(AppConfig.self, from: $0) }
            .first ?? .fallback
        cached = config
        return config
    }

    /// Re-read the file on next access (e.g. after the app edited it).
    static func reload() { cached = nil }

    /// Validates and saves an edited config, which then overrides the bundled file.
    static func save(_ config: AppConfig) throws {
        guard TimeZone(identifier: config.timeZone) != nil else { throw ConfigError.badTimeZone(config.timeZone) }
        guard let url = URL(string: config.defaultURL), url.scheme != nil else { throw ConfigError.badURL }
        try encoder.encode(config).write(to: editedURL, options: .atomic)
        reload()
    }

    /// The config from the app bundle, ignoring any edits.
    static var bundled: AppConfig {
        bundledURL.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(AppConfig.self, from: $0) } ?? .fallback
    }

    static func resetToBundled() {
        try? FileManager.default.removeItem(at: editedURL)
        reload()
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    var tz: TimeZone { TimeZone(identifier: timeZone) ?? .current }
}

enum ConfigError: LocalizedError {
    case badTimeZone(String), badURL
    var errorDescription: String? {
        switch self {
        case .badTimeZone(let tz): return "Unknown time zone \"\(tz)\". Use an identifier like Asia/Amman."
        case .badURL: return "defaultURL isn't a valid URL."
        }
    }
}

enum Shared {
    static let defaultAppGroup = "group.app.prayertimesjo"
    static let widgetKind = "PrayerWidget"

    /// The containing app's bundle, even when running inside the widget extension.
    static let appBundle: Bundle = {
        let main = Bundle.main
        if main.bundleURL.pathExtension == "appex" {
            let appURL = main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            return Bundle(url: appURL) ?? main
        }
        return main
    }()

    /// AltStore/SideStore rewrite app group IDs and publish the new one under ALTAppGroups.
    static let appGroup: String = {
        for bundle in [Bundle.main, appBundle] {
            if let groups = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String], let g = groups.first {
                return g
            }
        }
        return defaultAppGroup
    }()

    static let groupContainer: URL? =
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)

    static let defaults: UserDefaults = {
        if groupContainer != nil, let d = UserDefaults(suiteName: appGroup) { return d }
        return .standard
    }()

    static var dataDirectory: URL {
        let base = groupContainer
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = AppConfig.current.tz
        return c
    }
}

/// User preferences shared between the app and the widget.
enum Settings {
    enum SourceMode: String { case url, file }

    private static var d: UserDefaults { Shared.defaults }

    static var sourceMode: SourceMode {
        get { SourceMode(rawValue: d.string(forKey: "sourceMode") ?? "") ?? .url }
        set { d.set(newValue.rawValue, forKey: "sourceMode") }
    }

    /// Empty means "use the default URL from config.json".
    static var customURL: String {
        get { d.string(forKey: "customURL") ?? "" }
        set { d.set(newValue, forKey: "customURL") }
    }

    static var effectiveURL: String {
        let custom = customURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? AppConfig.current.defaultURL : custom
    }

    static var use24Hour: Bool {
        get { d.object(forKey: "use24Hour") as? Bool ?? true }
        set { d.set(newValue, forKey: "use24Hour") }
    }

    static var arabicNames: Bool {
        get { d.bool(forKey: "arabicNames") }
        set { d.set(newValue, forKey: "arabicNames") }
    }

    /// Minutes after the previous timing during which the widget shows elapsed time.
    static var elapsedWindowMinutes: Int {
        get { d.object(forKey: "elapsedWindowMinutes") as? Int ?? 30 }
        set { d.set(newValue, forKey: "elapsedWindowMinutes") }
    }

    static var lastAutoUpdateAttempt: Date? {
        get { d.object(forKey: "lastAutoUpdateAttempt") as? Date }
        set { d.set(newValue, forKey: "lastAutoUpdateAttempt") }
    }
}

enum Formatters {
    static func time(_ date: Date, use24Hour: Bool = Settings.use24Hour) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = AppConfig.current.tz
        f.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        return f.string(from: date)
    }

    static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = AppConfig.current.tz
        f.dateStyle = .medium
        return f.string(from: date)
    }

    /// 75 minutes -> "1:15"
    static func duration(minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}
