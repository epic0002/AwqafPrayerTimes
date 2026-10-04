import AVFoundation
import Foundation

/// Notification sounds: the system default, the tones bundled with the app, and any
/// sounds the user imports (converted to .caf and stored in Library/Sounds, where
/// iOS looks for custom notification sounds).
enum SoundLibrary {
    static let bundled = ["Chime.caf", "Bell.caf", "Soft.caf", "Beeps.caf"]

    static var soundsDirectory: URL {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var imported: [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: soundsDirectory.path)) ?? [])
            .filter { $0.hasSuffix(".caf") }
            .sorted()
    }

    static var all: [String] { ["default"] + bundled + imported }

    static func displayName(_ name: String) -> String {
        name == "default" ? "Default" : (name as NSString).deletingPathExtension
    }

    static func url(for name: String) -> URL? {
        if name == "default" { return nil }
        if let u = Bundle.main.url(forResource: name, withExtension: nil) { return u }
        let u = soundsDirectory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    /// Converts any audio file AVFoundation can read (mp3, m4a, wav…) into a 16-bit PCM
    /// .caf trimmed to 29 seconds (iOS falls back to the default sound beyond 30 s).
    static func importSound(from source: URL) throws -> String {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }

        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let maxFrames = AVAudioFrameCount(format.sampleRate * 29)
        let frames = min(AVAudioFrameCount(input.length), maxFrames)

        let base = source.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "/", with: "-")
        let name = "\(base).caf"
        let dest = soundsDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let output = try AVAudioFile(forWriting: dest, settings: settings,
                                     commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try input.read(into: buffer, frameCount: frames)
        try output.write(from: buffer)
        return name
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: soundsDirectory.appendingPathComponent(name))
    }

    private static var player: AVAudioPlayer?

    static func preview(_ name: String) {
        guard let url = url(for: name) else {
            AudioServicesPlaySystemSound(1007) // tri-tone, close to the default
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
