import Foundation

/// Persists Lightly's only setting: where the scratchpad file lives on disk.
///
/// The setting is stored in `~/.config/lightly/settings.json` (mirroring
/// neetly's convention) so that moving the *scratchpad* into Dropbox never
/// drags the app's own config along with it.
final class LightlySettings {
    static let shared = LightlySettings()

    private let configDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/lightly")
    }()

    private var settingsFile: URL {
        configDir.appendingPathComponent("settings.json")
    }

    private struct Settings: Codable {
        /// Absolute path to the single scratchpad file.
        var scratchpadPath: String
        /// Editor font size in points. Optional so older config files (written
        /// before this setting existed) still decode and fall back to default.
        var fontSize: Double?
    }

    static let defaultFontSize: Double = 15
    static let minFontSize: Double = 9
    static let maxFontSize: Double = 48

    /// Default home for the scratchpad: `~/Documents/Lightly.txt`. The user is
    /// expected to repoint this at a Dropbox folder for backups.
    static var defaultScratchpadPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Lightly.txt").path
    }

    var scratchpadURL: URL {
        URL(fileURLWithPath: load().scratchpadPath)
    }

    func setScratchpadPath(_ path: String) {
        var s = load()
        s.scratchpadPath = path
        save(s)
    }

    /// Editor font size, clamped to a sane range.
    var fontSize: Double {
        let raw = load().fontSize ?? Self.defaultFontSize
        return min(max(raw, Self.minFontSize), Self.maxFontSize)
    }

    func setFontSize(_ size: Double) {
        var s = load()
        s.fontSize = min(max(size, Self.minFontSize), Self.maxFontSize)
        save(s)
    }

    private func load() -> Settings {
        guard let data = try? Data(contentsOf: settingsFile),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            return Settings(scratchpadPath: Self.defaultScratchpadPath)
        }
        return settings
    }

    private func save(_ settings: Settings) {
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsFile, options: .atomic)
        } catch {
            NSLog("LightlySettings: failed to save: \(error)")
        }
    }
}
