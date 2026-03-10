import Cocoa

/// Keyboard emulation using CGEvent (replaces JXA/osascript approach).
/// Requires Accessibility permission.
enum Emulation {
    /// Send a key event.
    /// - Parameters:
    ///   - keyCode: Either a CGKeyCode (UInt16) or a character string
    ///   - modifier: Optional modifier (e.g., .maskCommand)
    static func key(_ keyCode: CGKeyCode, modifier: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        if !modifier.isEmpty {
            keyDown.flags = modifier
            keyUp.flags = modifier
        }
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Send a character key event by looking up the key code.
    static func key(_ char: String, modifier: CGEventFlags = []) {
        guard let keyCode = charToKeyCode(char) else { return }
        key(keyCode, modifier: modifier)
    }

    // Common key codes
    static let deleteKeyCode: CGKeyCode = 51
    static let spaceKeyCode: CGKeyCode = 49

    private static func charToKeyCode(_ char: String) -> CGKeyCode? {
        let map: [String: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5,
            "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
            "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18,
            "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25,
            "7": 26, "8": 28, "0": 29, "o": 31, "u": 32, "i": 34,
            "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        ]
        return map[char.lowercased()]
    }
}
