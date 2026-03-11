import Foundation
import os

// MARK: - Log (Entry Point)

enum Log {
    static let subsystem = "com.pitecan.inputmethod.Gyaim"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "loggingEnabled")
    }

    static func setEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "loggingEnabled")
    }

    // Raw os.Logger instances (internal, wrapped by GLogger)
    private static let _input      = Logger(subsystem: subsystem, category: "input")
    private static let _dict       = Logger(subsystem: subsystem, category: "dict")
    private static let _conversion = Logger(subsystem: subsystem, category: "conversion")
    private static let _ui         = Logger(subsystem: subsystem, category: "ui")
    private static let _config     = Logger(subsystem: subsystem, category: "config")

    // Public category loggers
    static let input      = GLogger(_input, fileCategory: "input")
    static let dict       = GLogger(_dict, fileCategory: "dict")
    static let conversion = GLogger(_conversion, fileCategory: "conversion")
    static let ui         = GLogger(_ui, fileCategory: "ui")
    static let config     = GLogger(_config, fileCategory: "config")
}

// MARK: - GLogger (Wrapper)

/// os.Logger wrapper that respects Log.isEnabled and writes to FileLogger.
struct GLogger {
    private let logger: Logger
    private let category: String

    init(_ logger: Logger, fileCategory: String) {
        self.logger = logger
        self.category = fileCategory
    }

    func debug(_ message: @autoclosure () -> String) {
        guard Log.isEnabled else { return }
        let msg = message()
        logger.debug("\(msg)")
    }

    func info(_ message: @autoclosure () -> String) {
        guard Log.isEnabled else { return }
        let msg = message()
        logger.info("\(msg)")
        FileLogger.shared.write(category: category, level: "info", message: msg)
    }

    func warning(_ message: @autoclosure () -> String) {
        guard Log.isEnabled else { return }
        let msg = message()
        logger.warning("\(msg)")
        FileLogger.shared.write(category: category, level: "warning", message: msg)
    }

    func error(_ message: @autoclosure () -> String) {
        guard Log.isEnabled else { return }
        let msg = message()
        logger.error("\(msg)")
        FileLogger.shared.write(category: category, level: "error", message: msg)
    }
}

// MARK: - FileLogger

/// Writes info+ log lines to ~/.gyaim/gyaim.log with size-based rotation.
final class FileLogger {
    static let shared = FileLogger()

    private let queue = DispatchQueue(label: "com.pitecan.inputmethod.Gyaim.filelogger")
    private let logPath: String
    private let rotatedPath: String
    private let maxSize: Int64 = 5 * 1024 * 1024  // 5 MB
    private var fileHandle: FileHandle?

    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {
        logPath = "\(Config.gyaimDir)/gyaim.log"
        rotatedPath = "\(Config.gyaimDir)/gyaim.log.1"
    }

    func write(category: String, level: String, message: String) {
        queue.async { [self] in
            let timestamp = dateFormatter.string(from: Date())
            let line = "[\(timestamp)] [\(category)] [\(level)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

            if fileHandle == nil {
                openFile()
            }
            fileHandle?.write(data)
            rotateIfNeeded()
        }
    }

    func flush() {
        queue.async { [self] in
            fileHandle?.synchronizeFile()
        }
    }

    /// Delete log files and reopen handle.
    func clearLog() {
        queue.async { [self] in
            fileHandle?.closeFile()
            fileHandle = nil
            let fm = FileManager.default
            try? fm.removeItem(atPath: logPath)
            try? fm.removeItem(atPath: rotatedPath)
        }
    }

    /// Returns the current log file size in bytes (synchronous, for UI).
    func logFileSize() -> Int64 {
        let fm = FileManager.default
        let mainSize = (try? fm.attributesOfItem(atPath: logPath)[.size] as? Int64) ?? 0
        let rotatedSize = (try? fm.attributesOfItem(atPath: rotatedPath)[.size] as? Int64) ?? 0
        return mainSize + rotatedSize
    }

    // MARK: - Private

    private func openFile() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: logPath) {
            fm.createFile(atPath: logPath, contents: nil)
        }
        fileHandle = FileHandle(forWritingAtPath: logPath)
        fileHandle?.seekToEndOfFile()
    }

    private func rotateIfNeeded() {
        guard let handle = fileHandle else { return }
        let size = handle.offsetInFile
        guard size > maxSize else { return }

        handle.closeFile()
        fileHandle = nil

        let fm = FileManager.default
        try? fm.removeItem(atPath: rotatedPath)
        try? fm.moveItem(atPath: logPath, toPath: rotatedPath)

        openFile()
    }
}

// MARK: - PerfLog

enum PerfLog {
    static func measure<T>(_ label: String, logger: GLogger, _ block: () -> T) -> T {
        guard Log.isEnabled else { return block() }
        let start = CFAbsoluteTimeGetCurrent()
        let result = block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.info("\(label): \(String(format: "%.1f", elapsed))ms")
        return result
    }
}
