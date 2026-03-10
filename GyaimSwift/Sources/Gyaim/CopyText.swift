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
        let curtext = (try? String(contentsOfFile: file, encoding: .utf8)) ?? ""
        if curtext != text {
            try? text.write(toFile: file, atomically: true, encoding: .utf8)
        }
        lastSetTime = Date()
    }

    static func get() -> String {
        (try? String(contentsOfFile: file, encoding: .utf8)) ?? ""
    }

    static var time: Date {
        lock.lock()
        defer { lock.unlock() }
        return lastSetTime
    }
}
