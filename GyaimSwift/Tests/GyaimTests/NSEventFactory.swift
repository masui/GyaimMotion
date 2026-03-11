import Cocoa

enum NSEventFactory {
    static func keyDown(
        _ char: String,
        keyCode: UInt16 = 0,
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: char,
            charactersIgnoringModifiers: char,
            isARepeat: false,
            keyCode: keyCode
        )
    }

    static func backspace() -> NSEvent? {
        keyDown("\u{7f}", keyCode: 51)
    }

    static func enter() -> NSEvent? {
        keyDown("\r", keyCode: 36)
    }

    static func space() -> NSEvent? {
        keyDown(" ", keyCode: 49)
    }

    static func escape() -> NSEvent? {
        keyDown("\u{1b}", keyCode: 53)
    }
}
