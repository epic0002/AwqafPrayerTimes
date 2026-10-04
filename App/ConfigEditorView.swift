import SwiftUI

/// Edits config.json with simple controls. The bundled file can't be modified on
/// device, so the edited version is saved separately and used instead until reset.
struct ConfigEditorView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = AppConfig.current
    @State private var error: String?

    private static let timeZones = [
        "Asia/Amman", "Asia/Jerusalem", "Asia/Damascus", "Asia/Beirut", "Asia/Baghdad",
        "Asia/Riyadh", "Asia/Kuwait", "Asia/Qatar", "Asia/Dubai", "Africa/Cairo",
        "Europe/Istanbul", "Europe/London", "Europe/Berlin", "America/New_York", "America/Chicago",
        "America/Los_Angeles", "UTC",
    ]
    private static let dayOptions = [1, 3, 7, 14, 30]

    var body: some View {
        Form {
            Section {
                TextField(AppConfig.bundled.defaultURL, text: $draft.defaultURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.callout)
                    .onSubmit(save)
                if draft.defaultURL != AppConfig.bundled.defaultURL {
                    Button("Use original URL") { draft.defaultURL = AppConfig.bundled.defaultURL; save() }
                }
            } header: {
                Text("Default URL")
            } footer: {
                Text("Used when the URL field in Settings is empty.")
            }

            Section {
                Picker("Time zone", selection: $draft.timeZone) {
                    ForEach(timeZoneOptions, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) }
                }
                Picker("Auto-update", selection: autoUpdateDays) {
                    ForEach(Self.dayOptions, id: \.self) { d in
                        Text(d == 1 ? "1 day before end" : "\(d) days before end").tag(d)
                    }
                }
            } footer: {
                Text("Time zone: the zone the CSV times are in. Auto-update: how early to download new timings before the current file runs out.")
            }

            if let error {
                Section { Text(error).foregroundColor(.red).font(.callout) }
            }

            if AppConfig.isEdited {
                Section {
                    Button("Reset to defaults", role: .destructive) {
                        AppConfig.resetToBundled()
                        draft = AppConfig.current
                        error = nil
                        model.configDidChange()
                    }
                }
            }
        }
        .pickerStyle(.menu)
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: draft.timeZone) { _ in save() }
        .onChange(of: draft.autoUpdateDaysBeforeEnd) { _ in save() }
        .onDisappear(perform: save)
    }

    /// Common zones, plus the current one if it isn't in the list.
    private var timeZoneOptions: [String] {
        Self.timeZones.contains(draft.timeZone) ? Self.timeZones : [draft.timeZone] + Self.timeZones
    }

    private var autoUpdateDays: Binding<Int> {
        Binding(get: { draft.autoUpdateDaysBeforeEnd ?? 7 },
                set: { draft.autoUpdateDaysBeforeEnd = $0 })
    }

    private func save() {
        draft.defaultURL = draft.defaultURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft != AppConfig.current else { return }
        do {
            try AppConfig.save(draft)
            error = nil
            model.configDidChange()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
