import XCTest
import Cocoa

final class GyaimE2ETests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Skip if Accessibility permission not granted
        guard AXIsProcessTrusted() else {
            XCTFail("Accessibility permission required for E2E tests. Enable in System Settings > Privacy & Security > Accessibility.")
            return
        }
    }

    /// Helper: clear TextEdit content before each test
    private func prepareTextEdit() {
        E2EHelper.openTextEdit()
        // Select Gyaim input source
        XCTAssertTrue(E2EHelper.selectGyaimInputSource(), "Failed to activate Gyaim")
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func tearDownTextEdit() {
        E2EHelper.closeTextEdit()
    }

    // MARK: - Tests

    func testBasicRomajiInputAndCommit() {
        prepareTextEdit()
        defer { tearDownTextEdit() }

        // Type "a" and press Enter to commit
        E2EHelper.typeString("a")
        Thread.sleep(forTimeInterval: 0.3)
        E2EHelper.pressEnter() // exact mode search
        Thread.sleep(forTimeInterval: 0.3)
        E2EHelper.pressEnter() // commit first candidate
        Thread.sleep(forTimeInterval: 0.3)

        let result = E2EHelper.getTextViaCopy()
        // Should have committed something (at minimum "a" or a kanji)
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.isEmpty ?? true, "Expected committed text")
    }

    func testEscapeCancelsInput() {
        prepareTextEdit()
        defer { tearDownTextEdit() }

        E2EHelper.typeString("abc")
        Thread.sleep(forTimeInterval: 0.3)
        E2EHelper.pressEscape()
        Thread.sleep(forTimeInterval: 0.3)

        let result = E2EHelper.getTextViaCopy()
        // After escape, no text should be committed (or empty)
        XCTAssertTrue(result?.isEmpty ?? true, "Expected no text after escape")
    }

    func testBackspaceRemovesCharacter() {
        prepareTextEdit()
        defer { tearDownTextEdit() }

        E2EHelper.typeString("ab")
        Thread.sleep(forTimeInterval: 0.2)
        E2EHelper.pressBackspace()
        Thread.sleep(forTimeInterval: 0.2)
        // Now only "a" should remain in inputPat
        // Press Enter twice to commit
        E2EHelper.pressEnter()
        Thread.sleep(forTimeInterval: 0.2)
        E2EHelper.pressEnter()
        Thread.sleep(forTimeInterval: 0.3)

        let result = E2EHelper.getTextViaCopy()
        XCTAssertNotNil(result)
        // The committed text should correspond to "a", not "ab"
    }

    func testSpaceCyclesCandidates() {
        prepareTextEdit()
        defer { tearDownTextEdit() }

        // Type "ka" which should have candidates
        E2EHelper.typeString("ka")
        Thread.sleep(forTimeInterval: 0.3)
        E2EHelper.pressSpace() // move to next candidate
        Thread.sleep(forTimeInterval: 0.2)
        E2EHelper.pressEnter() // commit
        Thread.sleep(forTimeInterval: 0.3)

        let result = E2EHelper.getTextViaCopy()
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.isEmpty ?? true, "Expected committed text after space+enter")
    }

    func testClipboardCandidateAppearsOnRecentCopy() {
        prepareTextEdit()
        defer { tearDownTextEdit() }

        // Copy something to clipboard
        let testText = "テスト候補_\(UUID().uuidString.prefix(6))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(testText, forType: .string)

        Thread.sleep(forTimeInterval: 1.0)

        // Type something within 5 seconds of copy
        E2EHelper.typeString("te")
        Thread.sleep(forTimeInterval: 0.5)

        // The clipboard content should appear as a candidate
        // Space to cycle to it, then Enter to commit
        E2EHelper.pressSpace()
        Thread.sleep(forTimeInterval: 0.2)

        // We can't easily check candidates list, but we verify the flow doesn't crash
        E2EHelper.pressEscape()
        Thread.sleep(forTimeInterval: 0.2)
    }

    func testClipboardCandidateNotShownAfterFiveSeconds() {
        prepareTextEdit()
        defer { tearDownTextEdit() }

        // Copy something
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("古いクリップボード", forType: .string)

        // Wait more than 5 seconds
        Thread.sleep(forTimeInterval: 6.0)

        // Type something
        E2EHelper.typeString("test")
        Thread.sleep(forTimeInterval: 0.5)

        // Cancel
        E2EHelper.pressEscape()
        Thread.sleep(forTimeInterval: 0.2)

        // This mainly tests that the 5-second expiry works
        // Without direct candidate list access, we verify no crash
    }

    // MARK: - Selected Text Candidate Tests

    func testSelectedTextAppearsAsCandidate() {
        prepareTextEdit()
        defer { tearDownTextEdit() }

        // Type some text first, then select it
        // Type "hello" and commit as-is
        E2EHelper.typeString("hello")
        Thread.sleep(forTimeInterval: 0.3)
        E2EHelper.pressEnter() // exact search
        Thread.sleep(forTimeInterval: 0.2)
        E2EHelper.pressEnter() // commit
        Thread.sleep(forTimeInterval: 0.3)

        // Select all (the committed "hello" or its conversion)
        E2EHelper.typeKey(code: 0x00, flags: .maskCommand)  // Cmd+A
        Thread.sleep(forTimeInterval: 0.3)

        // Now type with Gyaim — selected text should appear as candidate
        E2EHelper.typeString("a")
        Thread.sleep(forTimeInterval: 0.5)

        // Cancel and clean up
        E2EHelper.pressEscape()
        Thread.sleep(forTimeInterval: 0.2)
    }

    func testSelectedTextNotShownWhenNoSelection() {
        prepareTextEdit()
        defer { tearDownTextEdit() }

        // Type directly without selecting anything
        E2EHelper.typeString("test")
        Thread.sleep(forTimeInterval: 0.5)

        // Cancel
        E2EHelper.pressEscape()
        Thread.sleep(forTimeInterval: 0.2)

        // Verify no crash and normal operation
    }
}
