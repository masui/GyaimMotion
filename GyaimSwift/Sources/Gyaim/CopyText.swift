import Foundation

/// Clipboard text cache stored at ~/.gyaim/copytext.
/// Ported from CopyText.rb
enum CopyText {
    private static let lock = NSLock()
    private static var lastSetTime: Date = .distantPast

    static var file: String { Config.copyTextFile }

    static func set(_ text: String?) {
        lock.lock()
        defer { lock.unlock() }
        guard let text else { return }
        let curtext: String
        do {
            curtext = try String(contentsOfFile: file, encoding: .utf8)
        } catch {
            Log.config.warning("Failed to read copytext: \(error.localizedDescription)")
            curtext = ""
        }
        if curtext != text {
            do {
                try text.write(toFile: file, atomically: true, encoding: .utf8)
            } catch {
                Log.config.warning("Failed to write copytext: \(error.localizedDescription)")
            }
            // Only update timestamp when clipboard content actually changed
            lastSetTime = Date()
            Log.config.info("Clipboard updated: \"\(text.prefix(50))\"")
        }
    }

    static func get() -> String {
        do {
            return try String(contentsOfFile: file, encoding: .utf8)
        } catch {
            Log.config.warning("Failed to read copytext: \(error.localizedDescription)")
            return ""
        }
    }

    static var time: Date {
        lock.lock()
        defer { lock.unlock() }
        return lastSetTime
    }
}
