import Cocoa

/// Represents a keyboard shortcut (key code + modifier flags + optional character code).
struct KeyShortcut: Codable, Equatable {
    var keyCode: UInt16
    var charCode: UInt8?  // Character code for reliable Ctrl+key matching
    var controlKey: Bool = false
    var optionKey: Bool = false
    var shiftKey: Bool = false
    var commandKey: Bool = false

    var modifierFlags: NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if controlKey { flags.insert(.control) }
        if optionKey { flags.insert(.option) }
        if shiftKey { flags.insert(.shift) }
        if commandKey { flags.insert(.command) }
        return flags
    }

    /// Human-readable display string (e.g. "⌃U", "F7")
    var displayString: String {
        var parts: [String] = []
        if controlKey { parts.append("⌃") }
        if optionKey { parts.append("⌥") }
        if shiftKey { parts.append("⇧") }
        if commandKey { parts.append("⌘") }
        parts.append(KeyShortcut.keyCodeName(keyCode))
        return parts.joined()
    }

    /// Relevant modifier flags only (ignore function, numericPad, capsLock, etc.)
    private static let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    func matches(event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(KeyShortcut.relevantModifiers)
        let modsMatch = mods.contains(.control) == controlKey
            && mods.contains(.option) == optionKey
            && mods.contains(.shift) == shiftKey
            && mods.contains(.command) == commandKey
        guard modsMatch else { return false }

        // Match by keyCode first
        if event.keyCode == keyCode { return true }

        // Fallback: match by character code (reliable for Ctrl+key combos)
        if let cc = charCode, let chars = event.characters, let first = chars.utf8.first {
            return first == cc
        }
        return false
    }

    static func from(event: NSEvent) -> KeyShortcut {
        let mods = event.modifierFlags.intersection(relevantModifiers)
        let cc = event.characters?.utf8.first
        return KeyShortcut(
            keyCode: event.keyCode,
            charCode: cc,
            controlKey: mods.contains(.control),
            optionKey: mods.contains(.option),
            shiftKey: mods.contains(.shift),
            commandKey: mods.contains(.command)
        )
    }

    static func keyCodeName(_ code: UInt16) -> String {
        switch code {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 109: return "F10"
        case 111: return "F12"
        case 118: return "F4"
        case 120: return "F2"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key\(code)"
        }
    }
}

/// Persistent key binding configuration stored in UserDefaults.
class KeyBindings {
    static let shared = KeyBindings()

    private let defaultsKey = "GyaimKeyBindings"

    /// Modifier-key shortcuts for each action
    var hiragana: [KeyShortcut] = [
        KeyShortcut(keyCode: 97),                                                    // F6
        KeyShortcut(keyCode: 32, controlKey: true, shiftKey: true),                  // Ctrl+Shift+U
    ]
    var katakana: [KeyShortcut] = [
        KeyShortcut(keyCode: 98),                                                    // F7
        KeyShortcut(keyCode: 34, controlKey: true, shiftKey: true),                  // Ctrl+Shift+I
    ]

    /// Single-key confirm (ASCII value, 0 = disabled). Works in converting mode.
    var hiraganaChar: UInt8 = 0x3B   // ;
    var katakanaChar: UInt8 = 0x71   // q

    private init() {
        load()
    }

    func matchesHiragana(event: NSEvent) -> Bool {
        hiragana.contains { $0.matches(event: event) }
    }

    func matchesKatakana(event: NSEvent) -> Bool {
        katakana.contains { $0.matches(event: event) }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(StoredBindings.self, from: data) else {
            return
        }
        hiragana = decoded.hiragana
        katakana = decoded.katakana
        hiraganaChar = decoded.hiraganaChar ?? 0x3B
        katakanaChar = decoded.katakanaChar ?? 0x71
    }

    func save() {
        let stored = StoredBindings(hiragana: hiragana, katakana: katakana,
                                    hiraganaChar: hiraganaChar, katakanaChar: katakanaChar)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    func reset() {
        hiragana = [
            KeyShortcut(keyCode: 97),
            KeyShortcut(keyCode: 32, controlKey: true, shiftKey: true),
        ]
        katakana = [
            KeyShortcut(keyCode: 98),
            KeyShortcut(keyCode: 34, controlKey: true, shiftKey: true),
        ]
        hiraganaChar = 0x3B
        katakanaChar = 0x71
        save()
    }

    private struct StoredBindings: Codable {
        let hiragana: [KeyShortcut]
        let katakana: [KeyShortcut]
        var hiraganaChar: UInt8?
        var katakanaChar: UInt8?
    }
}
