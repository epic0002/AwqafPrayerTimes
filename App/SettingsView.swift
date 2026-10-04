import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Source", selection: $model.sourceMode) {
                        Text("URL").tag(Settings.SourceMode.url)
                        Text("File").tag(Settings.SourceMode.file)
                    }
                    .pickerStyle(.segmented)

                    if model.sourceMode == .url {
                        TextField(model.config.defaultURL, text: $model.customURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.callout)
                        if !model.customURL.isEmpty {
                            Button("Reset to default URL") { model.customURL = "" }
                        }
                        Button {
                            Task { await model.updateNow() }
                        } label: {
                            HStack {
                                Label("Update now", systemImage: "arrow.clockwise")
                                if model.isUpdating { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(model.isUpdating)
                    } else {
                        Button {
                            showImporter = true
                        } label: {
                            Label("Import CSV file…", systemImage: "doc.badge.plus")
                        }
                    }

                    if let msg = model.statusMessage {
                        Text(msg).font(.caption).foregroundColor(.secondary)
                    }
                } header: {
                    Text("Data source")
                } footer: {
                    Text(model.sourceMode == .url
                         ? "Leave the field empty to use the default URL from config.json. Timings are downloaded again automatically when the current file is about to run out (end of the year)."
                         : "CSV columns: date,dawn,sunrise,duhr,asr,sunset,isha (date as dd/MM/yyyy).")
                }

                Section("Loaded data") {
                    LabeledContent("Source", value: model.schedule.source)
                    if let first = model.schedule.firstDate, let last = model.schedule.lastDate {
                        LabeledContent("Covers", value: "\(Formatters.day(first)) – \(Formatters.day(last))")
                    }
                    if model.schedule.updatedAt > .distantPast {
                        LabeledContent("Updated", value: model.schedule.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                Section {
                    Toggle("24-hour time", isOn: $model.use24Hour)
                    Toggle("Arabic names", isOn: $model.arabicNames)
                    Stepper(value: $model.elapsedWindow, in: 5...120, step: 5) {
                        LabeledContent("Show elapsed for", value: "\(model.elapsedWindow) min")
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("The widget shows time since the previous prayer (+) for this long, then time left until the next one (−).")
                }

                Section("About") {
                    NavigationLink {
                        ConfigEditorView()
                    } label: {
                        LabeledContent("config.json", value: AppConfig.isEdited ? "Edited" : "Bundled")
                    }
                    LabeledContent("Time zone", value: model.config.timeZone)
                    Link("Data: awqaf-prayer.netlify.app", destination: URL(string: model.config.defaultURL)!)
                }
            }
            .navigationTitle("Settings")
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.commaSeparatedText, .plainText, .text, .data]) { result in
                if case .success(let url) = result { model.importCSV(url) }
            }
        }
    }
}
