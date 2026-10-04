import SwiftUI

/// Edits config.json. The bundled file can't be modified on device, so the edited
/// version is saved separately and used instead of it until reset.
struct ConfigEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = AppConfig.text()
    @State private var error: String?
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .frame(minHeight: 180)
            } header: {
                Text(AppConfig.isEdited ? "Edited config.json" : "Bundled config.json")
            } footer: {
                Text("""
                defaultURL: CSV used when the URL field in Settings is empty.
                timeZone: zone the CSV times are in (e.g. Asia/Amman).
                autoUpdateDaysBeforeEnd: how many days before the data runs out to download new timings.
                """)
            }

            if let error {
                Section { Text(error).foregroundColor(.red).font(.callout) }
            }

            Section {
                Button("Save") { save() }
                if AppConfig.isEdited {
                    Button("Reset to bundled config.json", role: .destructive) { confirmReset = true }
                }
            }
        }
        .navigationTitle("config.json")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Discard your edits and use the bundled config.json?",
                            isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                AppConfig.resetToBundled()
                model.configDidChange()
                text = AppConfig.text()
                error = nil
            }
        }
    }

    private func save() {
        // Undo iOS smart quotes, which break JSON.
        let cleaned = text
            .replacingOccurrences(of: "\u{201C}", with: "\"").replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'").replacingOccurrences(of: "\u{2019}", with: "'")
        do {
            try AppConfig.save(text: cleaned)
            text = cleaned
            error = nil
            model.configDidChange()
            dismiss()
        } catch let e as DecodingError {
            error = "Invalid JSON: \(Self.describe(e))"
        } catch {
            self.error = error.localizedDescription
        }
    }

    private static func describe(_ e: DecodingError) -> String {
        switch e {
        case .keyNotFound(let key, _): return "missing \"\(key.stringValue)\""
        case .typeMismatch(_, let c), .valueNotFound(_, let c): return "wrong type at \"\(c.codingPath.map(\.stringValue).joined(separator: "."))\""
        case .dataCorrupted(let c): return c.debugDescription
        @unknown default: return "\(e)"
        }
    }
}
