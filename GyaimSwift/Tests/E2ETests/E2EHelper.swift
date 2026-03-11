import Cocoa
import Carbon

enum E2EHelper {
    /// Activate Gyaim as the current input source
    static func selectGyaimInputSource() -> Bool {
        guard let sources = TISCreateInputSourceList(
            [kTISPropertyBundleID: "com.pitecan.inputmethod.Gyaim"] as CFDictionary,
            false
        )?.takeRetainedValue() as? [TISInputSource],
              let gyaim = sources.first else {
            return false
        }
        return TISSelectInputSource(gyaim) == noErr
    }

    /// Send a keyDown + keyUp event pair via CGEvent
    static func typeKey(code: CGKeyCode, flags: CGEventFlags = []) {
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)!
        keyDown.flags = flags
        keyDown.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)!
        keyUp.flags = flags
        keyUp.post(tap: .cghidEventTap)

        Thread.sleep(forTimeInterval: 0.05)
    }

    /// Type a string character by character (ASCII only)
    static func typeString(_ s: String) {
        for ch in s {
            guard let ascii = ch.asciiValue else { continue }
            // Map ASCII to CGKeyCode (approximate — covers a-z, 0-9)
            let keyCode = asciiToKeyCode(ascii)
            typeKey(code: keyCode)
        }
    }

    /// Press Enter
    static func pressEnter() { typeKey(code: 0x24) }

    /// Press Space
    static func pressSpace() { typeKey(code: 0x31) }

    /// Press Backspace
    static func pressBackspace() { typeKey(code: 0x33) }

    /// Press Escape
    static func pressEscape() { typeKey(code: 0x35) }

    /// Select all + Copy, then return pasteboard content
    static func getTextViaCopy() -> String? {
        typeKey(code: 0x00, flags: .maskCommand)  // Cmd+A
        Thread.sleep(forTimeInterval: 0.1)
        typeKey(code: 0x08, flags: .maskCommand)  // Cmd+C
        Thread.sleep(forTimeInterval: 0.1)
        return NSPasteboard.general.string(forType: .string)
    }

    /// Open TextEdit with a new document
    static func openTextEdit() {
        NSWorkspace.shared.launchApplication("TextEdit")
        Thread.sleep(forTimeInterval: 1.0)
        // Cmd+N for new document
        typeKey(code: 0x2D, flags: .maskCommand)
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Close TextEdit window without saving
    static func closeTextEdit() {
        typeKey(code: 0x0D, flags: .maskCommand) // Cmd+W
        Thread.sleep(forTimeInterval: 0.3)
        // "Don't Save" button — Cmd+D or Cmd+Delete
        typeKey(code: 0x02, flags: .maskCommand) // Cmd+D (Don't Save)
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// Map ASCII values to approximate CGKeyCode
    private static func asciiToKeyCode(_ ascii: UInt8) -> CGKeyCode {
        // Standard US keyboard layout mapping
        switch ascii {
        case 0x61...0x7A: // a-z
            let map: [UInt8: CGKeyCode] = [
                0x61: 0x00, 0x62: 0x0B, 0x63: 0x08, 0x64: 0x02, 0x65: 0x0E,
                0x66: 0x03, 0x67: 0x05, 0x68: 0x04, 0x69: 0x22, 0x6A: 0x26,
                0x6B: 0x28, 0x6C: 0x25, 0x6D: 0x2E, 0x6E: 0x2D, 0x6F: 0x1F,
                0x70: 0x23, 0x71: 0x0C, 0x72: 0x0F, 0x73: 0x01, 0x74: 0x11,
                0x75: 0x20, 0x76: 0x09, 0x77: 0x0D, 0x78: 0x07, 0x79: 0x10,
                0x7A: 0x06
            ]
            return map[ascii] ?? 0
        case 0x30...0x39: // 0-9
            let map: [UInt8: CGKeyCode] = [
                0x30: 0x1D, 0x31: 0x12, 0x32: 0x13, 0x33: 0x14, 0x34: 0x15,
                0x35: 0x17, 0x36: 0x16, 0x37: 0x1A, 0x38: 0x1C, 0x39: 0x19
            ]
            return map[ascii] ?? 0
        case 0x20: return 0x31 // space
        default: return 0
        }
    }
}
