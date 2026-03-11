import Cocoa
import InputMethodKit

final class MockIMKTextInput: NSObject, IMKTextInput {
    var insertedTexts: [String] = []
    var markedTexts: [String] = []
    var mockSelectedRange: NSRange = NSRange(location: NSNotFound, length: 0)
    var mockSelectedText: String? = nil

    func insertText(_ string: Any!, replacementRange: NSRange) {
        if let s = string as? String {
            insertedTexts.append(s)
        } else if let a = string as? NSAttributedString {
            insertedTexts.append(a.string)
        }
    }

    func setMarkedText(_ string: Any!, selectionRange: NSRange, replacementRange: NSRange) {
        if let s = string as? String {
            markedTexts.append(s)
        } else if let a = string as? NSAttributedString {
            markedTexts.append(a.string)
        }
    }

    func selectedRange() -> NSRange { mockSelectedRange }

    func attributedSubstring(from range: NSRange) -> NSAttributedString? {
        mockSelectedText.map { NSAttributedString(string: $0) }
    }

    func markedRange() -> NSRange { NSRange(location: NSNotFound, length: 0) }

    func overrideKeyboard(withKeyboardNamed keyboardUniqueName: String!) {}
    func selectMode(_ modeIdentifier: String!) {}

    // Additional IMKTextInput required methods
    func length() -> Int { 0 }

    func characterIndex(for point: NSPoint, tracking: IMKLocationToOffsetMappingMode, inMarkedRange: UnsafeMutablePointer<ObjCBool>?) -> Int { 0 }

    func attributes(forCharacterIndex index: Int, lineHeightRectangle: UnsafeMutablePointer<NSRect>?) -> [AnyHashable: Any]? {
        [:]
    }

    func validAttributesForMarkedText() -> [Any]? { [] }

    func supportsUnicode() -> Bool { true }

    func bundleIdentifier() -> String? { "com.test.mock" }

    func windowLevel() -> CGWindowLevel { 0 }

    func supportsProperty(_ tag: TSMDocumentPropertyTag) -> Bool { false }

    func uniqueClientIdentifierString() -> String? { "mock-client" }

    func string(from range: NSRange, actualRange: NSRangePointer?) -> String? { nil }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect { .zero }
}
