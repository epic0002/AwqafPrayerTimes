import SwiftUI
import UniformTypeIdentifiers

struct NotificationsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($model.notificationSettings) { $setting in
                        NavigationLink {
                            PrayerNotificationDetail(setting: $setting)
                        } label: {
                            HStack {
                                Image(systemName: setting.prayer.symbol).frame(width: 28)
                                Text(setting.prayer.name(arabic: model.arabicNames))
                                Spacer()
                                Text(summary(setting)).foregroundColor(.secondary).font(.callout)
                            }
                        }
                    }
                } footer: {
                    Text("iOS allows 64 scheduled notifications, which covers about 10 days. They're refreshed every time you open the app and periodically in the background.")
                }

                Section {
                    Button("Send test notification") { sendTest() }
                    Button("Open iOS notification settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .onChange(of: model.notificationSettings) { _ in model.saveNotificationSettings() }
        }
    }

    private func summary(_ s: PrayerNotificationSetting) -> String {
        guard s.enabled else { return "Off" }
        var parts: [String] = []
        if s.offsetMinutes != 0 { parts.append(s.offsetMinutes > 0 ? "+\(s.offsetMinutes)m" : "\(s.offsetMinutes)m") }
        parts.append(s.soundEnabled ? SoundLibrary.displayName(s.soundName) : "Silent")
        return parts.joined(separator: " · ")
    }

    private func sendTest() {
        let content = UNMutableNotificationContent()
        content.title = "Prayer Times"
        content.body = "Test notification"
        content.sound = .default
        let req = UNNotificationRequest(identifier: "test", content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false))
        UNUserNotificationCenter.current().add(req)
    }
}

struct PrayerNotificationDetail: View {
    @Binding var setting: PrayerNotificationSetting
    @EnvironmentObject private var model: AppModel
    @State private var showImporter = false
    @State private var importError: String?
    @State private var sounds = SoundLibrary.all

    var body: some View {
        Form {
            Section {
                Toggle("Notify", isOn: $setting.enabled)
            }
            if setting.enabled {
                Section {
                    Stepper(value: $setting.offsetMinutes, in: -120...120) {
                        HStack {
                            Text("Offset")
                            Spacer()
                            Text(offsetText).foregroundColor(.secondary).monospacedDigit()
                        }
                    }
                    HStack {
                        ForEach([-15, -10, -5, 0, 5, 10], id: \.self) { m in
                            Button(m == 0 ? "0" : (m > 0 ? "+\(m)" : "\(m)")) { setting.offsetMinutes = m }
                                .buttonStyle(.bordered)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Timing")
                } footer: {
                    Text("Negative = before the prayer time, positive = after.")
                }

                Section("Sound") {
                    Toggle("Play sound", isOn: $setting.soundEnabled)
                    if setting.soundEnabled {
                        ForEach(sounds, id: \.self) { name in
                            HStack {
                                Button {
                                    setting.soundName = name
                                    SoundLibrary.preview(name)
                                } label: {
                                    HStack {
                                        Text(SoundLibrary.displayName(name)).foregroundColor(.primary)
                                        Spacer()
                                        if setting.soundName == name {
                                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                                        }
                                    }
                                }
                            }
                            .swipeActions {
                                if SoundLibrary.imported.contains(name) {
                                    Button(role: .destructive) {
                                        SoundLibrary.delete(name)
                                        if setting.soundName == name { setting.soundName = "default" }
                                        sounds = SoundLibrary.all
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                            }
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label("Import sound…", systemImage: "square.and.arrow.down")
                        }
                        if let importError { Text(importError).foregroundColor(.red).font(.caption) }
                    }
                }
            }
        }
        .navigationTitle(setting.prayer.name(arabic: model.arabicNames))
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio]) { result in
            do {
                let name = try SoundLibrary.importSound(from: result.get())
                sounds = SoundLibrary.all
                setting.soundName = name
                importError = nil
            } catch {
                importError = "Couldn't import: \(error.localizedDescription)"
            }
        }
    }

    private var offsetText: String {
        let m = setting.offsetMinutes
        if m == 0 { return "At prayer time" }
        return m < 0 ? "\(-m) min before" : "\(m) min after"
    }
}
