import Foundation

/// Reads and writes the one and only scratchpad file. All disk access for the
/// note text goes through here.
final class ScratchpadStore {
    static let shared = ScratchpadStore()

    var fileURL: URL { LightlySettings.shared.scratchpadURL }

    /// Load the current scratchpad contents. A missing file is treated as an
    /// empty scratchpad — Lightly only ever has one, and it starts blank.
    func load() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    /// Write `text` to the scratchpad file atomically, creating the parent
    /// directory if needed. Atomic writes mean a crash mid-save can never leave
    /// a half-written, truncated note behind.
    func save(_ text: String) {
        let url = fileURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSLog("ScratchpadStore: failed to save to \(url.path): \(error)")
        }
    }

    /// Point the scratchpad at a new file location.
    ///
    /// - If a file already exists at `newPath` (e.g. an existing note in a
    ///   Dropbox folder), the app adopts its contents — that file wins.
    /// - Otherwise the current `currentText` is written to the new location so
    ///   nothing the user has typed is lost in the move.
    ///
    /// Returns the text that should now be shown in the editor.
    @discardableResult
    func relocate(to newPath: String, currentText: String) -> String {
        LightlySettings.shared.setScratchpadPath(newPath)
        if FileManager.default.fileExists(atPath: newPath) {
            return load()
        }
        save(currentText)
        return currentText
    }
}
