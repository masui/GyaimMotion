import XCTest

final class HandleEventTests: XCTestCase {

    // MARK: - Helpers

    typealias Result = GyaimController.HandleResult
    typealias Action = Result.HandleAction

    /// Default parameters for routeEvent. Override individual fields as needed.
    private func route(
        character: UInt8 = 0,
        keyCode: UInt16 = 0,
        modifierFlags: NSEvent.ModifierFlags = [],
        converting: Bool = false,
        nthCand: Int = 0,
        candidateCount: Int = 0,
        searchMode: Int = 0,
        tmpImageDisplayed: Bool = false,
        bsThrough: Bool = false,
        hiraganaChar: UInt8 = 0x3B,
        katakanaChar: UInt8 = 0x71,
        matchesHiraganaShortcut: Bool = false,
        matchesKatakanaShortcut: Bool = false,
        matchesGoogleTransliterateShortcut: Bool = false,
        inputPatEmpty: Bool = true,
        hasEventString: Bool = true
    ) -> Result {
        GyaimController.routeEvent(
            character: character,
            keyCode: keyCode,
            modifierFlags: modifierFlags,
            converting: converting,
            nthCand: nthCand,
            candidateCount: candidateCount,
            searchMode: searchMode,
            tmpImageDisplayed: tmpImageDisplayed,
            bsThrough: bsThrough,
            hiraganaChar: hiraganaChar,
            katakanaChar: katakanaChar,
            matchesHiraganaShortcut: matchesHiraganaShortcut,
            matchesKatakanaShortcut: matchesKatakanaShortcut,
            matchesGoogleTransliterateShortcut: matchesGoogleTransliterateShortcut,
            inputPatEmpty: inputPatEmpty,
            hasEventString: hasEventString
        )
    }

    // MARK: - 1. JIS kana/roman mode keys

    func testJISKanaModeKey_returnsHandledJisModKey() {
        let result = route(keyCode: 104)
        XCTAssertEqual(result, Result(handled: true, action: .jisModKey))
    }

    func testJISRomanModeKey_returnsHandledJisModKey() {
        let result = route(keyCode: 102)
        XCTAssertEqual(result, Result(handled: true, action: .jisModKey))
    }

    // MARK: - 2. Hiragana/Katakana shortcut when converting

    func testHiraganaShortcutWhenConverting_returnsFixAsKanaHiragana() {
        let result = route(
            converting: true,
            matchesHiraganaShortcut: true
        )
        XCTAssertEqual(result, Result(handled: true, action: .fixAsKana(hiragana: true)))
    }

    func testKatakanaShortcutWhenConverting_returnsFixAsKanaKatakana() {
        let result = route(
            converting: true,
            matchesKatakanaShortcut: true
        )
        XCTAssertEqual(result, Result(handled: true, action: .fixAsKana(hiragana: false)))
    }

    func testHiraganaShortcutWhenNotConverting_ignored() {
        let result = route(
            converting: false,
            matchesHiraganaShortcut: true,
            hasEventString: false
        )
        // Not converting, so hiragana shortcut check is skipped; falls through to no-event-string guard
        XCTAssertEqual(result, Result(handled: true, action: .none))
    }

    // MARK: - 3. Single-key kana confirm (; / q)

    func testSemicolonWhenConverting_returnsFixAsKanaHiragana() {
        let result = route(
            character: 0x3B, // ;
            converting: true
        )
        XCTAssertEqual(result, Result(handled: true, action: .fixAsKana(hiragana: true)))
    }

    func testQWhenConverting_returnsFixAsKanaKatakana() {
        let result = route(
            character: 0x71, // q
            converting: true
        )
        XCTAssertEqual(result, Result(handled: true, action: .fixAsKana(hiragana: false)))
    }

    func testSemicolonWhenNotConverting_treatedAsPrintable() {
        let result = route(
            character: 0x3B,
            converting: false
        )
        // ; (0x3B) is >= 0x21 and <= 0x7e, so treated as printable
        XCTAssertEqual(result, Result(handled: true, action: .searchAndShow))
    }

    func testSemicolonWithModifier_notTreatedAsKanaConfirm() {
        // With Control modifier, single-key kana confirm is bypassed
        let result = route(
            character: 0x3B,
            modifierFlags: .control,
            converting: true
        )
        // Should NOT match hiraganaChar; falls through to other checks
        XCTAssertNotEqual(result.action, .fixAsKana(hiragana: true))
    }

    // MARK: - 4. Backspace when converting with nthCand > 0

    func testBackspaceWhenConvertingWithCandSelected_returnsDecrementNthCand() {
        let result = route(
            character: 0x7F, // backspace
            keyCode: 51,
            converting: true,
            nthCand: 2,
            candidateCount: 5
        )
        XCTAssertEqual(result, Result(handled: true, action: .decrementNthCand))
    }

    // MARK: - 5. Backspace when converting with nthCand == 0

    func testBackspaceWhenConvertingNthCandZero_returnsBackspaceInputPat() {
        let result = route(
            character: 0x7F,
            keyCode: 51,
            converting: true,
            nthCand: 0,
            candidateCount: 3
        )
        XCTAssertEqual(result, Result(handled: true, action: .backspaceInputPat))
    }

    // MARK: - 6. Backspace when not converting

    func testBackspaceWhenNotConverting_returnsNotHandled() {
        let result = route(
            character: 0x7F,
            keyCode: 51,
            converting: false
        )
        XCTAssertEqual(result.handled, false)
    }

    // MARK: - 7. Space when converting

    func testSpaceWhenConvertingNotAtEnd_returnsIncrementNthCand() {
        let result = route(
            character: 0x20,
            keyCode: 49,
            converting: true,
            nthCand: 1,
            candidateCount: 5
        )
        XCTAssertEqual(result, Result(handled: true, action: .incrementNthCand))
    }

    func testSpaceWhenConvertingAtEnd_returnsHandledNoAction() {
        let result = route(
            character: 0x20,
            keyCode: 49,
            converting: true,
            nthCand: 4,
            candidateCount: 5
        )
        XCTAssertEqual(result, Result(handled: true, action: .none))
    }

    // MARK: - 8. Space when not converting

    func testSpaceWhenNotConverting_returnsNotHandled() {
        let result = route(
            character: 0x20,
            keyCode: 49,
            converting: false
        )
        XCTAssertEqual(result.handled, false)
    }

    // MARK: - 9. Enter when converting, searchMode > 0

    func testEnterWhenConvertingSearchModePositive_returnsFix() {
        let result = route(
            character: 0x0D,
            keyCode: 36,
            converting: true,
            nthCand: 0,
            candidateCount: 3,
            searchMode: 1
        )
        XCTAssertEqual(result, Result(handled: true, action: .fix))
    }

    // MARK: - 10. Enter when converting, searchMode == 0, nthCand == 0

    func testEnterWhenConvertingSearchModeZeroNthCandZero_returnsSetSearchModeAndSearch() {
        let result = route(
            character: 0x0D,
            keyCode: 36,
            converting: true,
            nthCand: 0,
            candidateCount: 3,
            searchMode: 0
        )
        XCTAssertEqual(result, Result(handled: true, action: .setSearchModeAndSearch))
    }

    // MARK: - 11. Enter when converting, nthCand > 0

    func testEnterWhenConvertingNthCandPositive_returnsFix() {
        let result = route(
            character: 0x0D,
            keyCode: 36,
            converting: true,
            nthCand: 2,
            candidateCount: 5,
            searchMode: 0
        )
        XCTAssertEqual(result, Result(handled: true, action: .fix))
    }

    // MARK: - 12. Number key 1-9 when candidate list visible

    func testNumberKeyWhenCandidateListVisible_returnsNumberKeySelect() {
        // nthCand > 0 means list is visible; pressing '3' (0x33)
        let result = route(
            character: 0x33, // '3'
            keyCode: 20,
            converting: true,
            nthCand: 1,
            candidateCount: 10,
            searchMode: 0
        )
        // targetIndex = nthCand(1) + 3 = 4
        XCTAssertEqual(result, Result(handled: true, action: .numberKeySelect(4)))
    }

    func testNumberKeyWithSearchModePositive_returnsNumberKeySelect() {
        // searchMode > 0 also means list is visible
        let result = route(
            character: 0x31, // '1'
            keyCode: 18,
            converting: true,
            nthCand: 0,
            candidateCount: 5,
            searchMode: 1
        )
        // targetIndex = 0 + 1 = 1
        XCTAssertEqual(result, Result(handled: true, action: .numberKeySelect(1)))
    }

    func testNumberKeyOutOfRange_returnsHandledNone() {
        let result = route(
            character: 0x39, // '9'
            keyCode: 25,
            converting: true,
            nthCand: 1,
            candidateCount: 3, // targetIndex = 1 + 9 = 10, out of range
            searchMode: 0
        )
        XCTAssertEqual(result, Result(handled: true, action: .none))
    }

    func testNumberKeyWhenNotVisible_treatedAsPrintable() {
        // nthCand == 0 and searchMode == 0 → number keys are NOT intercepted
        let result = route(
            character: 0x33, // '3'
            keyCode: 20,
            converting: true,
            nthCand: 0,
            candidateCount: 5,
            searchMode: 0
        )
        // Falls through to printable character branch
        XCTAssertEqual(result, Result(handled: true, action: .searchAndShow))
    }

    // MARK: - 13. Printable character

    func testPrintableCharWhenNoCandSelected_returnsSearchAndShow() {
        let result = route(
            character: 0x61, // 'a'
            keyCode: 0,
            converting: false,
            nthCand: 0,
            candidateCount: 0,
            searchMode: 0
        )
        XCTAssertEqual(result, Result(handled: true, action: .searchAndShow))
    }

    func testPrintableCharWhenCandSelected_returnsFixThenSearchAndShow() {
        let result = route(
            character: 0x61, // 'a'
            keyCode: 0,
            converting: true,
            nthCand: 2,
            candidateCount: 5,
            searchMode: 0
        )
        XCTAssertEqual(result, Result(handled: true, action: .fixThenSearchAndShow))
    }

    func testPrintableCharWithSearchMode_returnsFixThenSearchAndShow() {
        let result = route(
            character: 0x62, // 'b'
            keyCode: 11,
            converting: true,
            nthCand: 0,
            candidateCount: 5,
            searchMode: 1
        )
        XCTAssertEqual(result, Result(handled: true, action: .fixThenSearchAndShow))
    }

    func testPrintableCharWithControlModifier_notHandled() {
        // Control+a should not be treated as printable
        let result = route(
            character: 0x01, // Ctrl+A produces 0x01
            keyCode: 0,
            modifierFlags: .control,
            converting: false
        )
        XCTAssertEqual(result.handled, false)
    }

    // MARK: - Escape key

    func testEscapeWhenConverting_returnsBackspaceInputPat() {
        let result = route(
            character: 0x1B, // escape
            keyCode: 53,
            converting: true,
            nthCand: 0,
            candidateCount: 3
        )
        XCTAssertEqual(result, Result(handled: true, action: .backspaceInputPat))
    }

    func testEscapeWhenNotConverting_returnsNotHandled() {
        let result = route(
            character: 0x1B,
            keyCode: 53,
            converting: false
        )
        XCTAssertEqual(result.handled, false)
    }

    // MARK: - Backspace with bsThrough

    func testBackspaceWithBsThrough_returnsNotHandled() {
        // bsThrough = true means backspace should pass through to the app
        let result = route(
            character: 0x7F,
            keyCode: 51,
            converting: true,
            nthCand: 0,
            candidateCount: 3,
            bsThrough: true
        )
        XCTAssertEqual(result.handled, false)
    }

    // MARK: - tmpImageDisplayed interactions

    func testBackspaceWithTmpImageDisplayed_returnsEmulateDelete() {
        let result = route(
            character: 0x7F,
            keyCode: 51,
            converting: true,
            nthCand: 0,
            candidateCount: 3,
            tmpImageDisplayed: true,
            bsThrough: false
        )
        XCTAssertEqual(result, Result(handled: true, action: .emulateDelete))
    }

    func testSpaceWithTmpImageDisplayed_returnsUndoAndSpace() {
        let result = route(
            character: 0x20,
            keyCode: 49,
            converting: true,
            nthCand: 0,
            candidateCount: 3,
            tmpImageDisplayed: true
        )
        XCTAssertEqual(result, Result(handled: true, action: .undoAndSpace))
    }

    func testEnterWithTmpImageDisplayed_returnsResetTmpImage() {
        let result = route(
            character: 0x0D,
            keyCode: 36,
            converting: true,
            nthCand: 0,
            candidateCount: 3,
            tmpImageDisplayed: true
        )
        XCTAssertEqual(result, Result(handled: true, action: .resetTmpImage))
    }

    // MARK: - No event string

    func testNoEventString_returnsHandledNone() {
        let result = route(
            converting: false,
            hasEventString: false
        )
        XCTAssertEqual(result, Result(handled: true, action: .none))
    }

    // MARK: - Enter when not converting

    func testEnterWhenNotConverting_returnsNotHandled() {
        let result = route(
            character: 0x0D,
            keyCode: 36,
            converting: false
        )
        XCTAssertEqual(result.handled, false)
    }

    // MARK: - Edge: 0x0A (line feed) treated same as 0x0D (carriage return)

    func testLineFeedTreatedAsEnter() {
        let result = route(
            character: 0x0A,
            keyCode: 36,
            converting: true,
            nthCand: 0,
            candidateCount: 3,
            searchMode: 1
        )
        XCTAssertEqual(result, Result(handled: true, action: .fix))
    }

    // MARK: - Google Transliterate shortcut

    func testGoogleTransliterateShortcutWhenConverting_returnsGoogleTransliterate() {
        let result = route(
            converting: true,
            matchesGoogleTransliterateShortcut: true
        )
        XCTAssertEqual(result, Result(handled: true, action: .googleTransliterate))
    }

    func testGoogleTransliterateShortcutWhenNotConverting_ignored() {
        let result = route(
            converting: false,
            matchesGoogleTransliterateShortcut: true,
            hasEventString: false
        )
        // Not converting → shortcut check skipped, falls through
        XCTAssertNotEqual(result.action, .googleTransliterate)
    }

    // MARK: - Edge: 0x08 (backspace alt) treated same as 0x7F

    func testBackspaceAlt0x08WhenConverting_returnsBackspaceInputPat() {
        let result = route(
            character: 0x08,
            keyCode: 51,
            converting: true,
            nthCand: 0,
            candidateCount: 3
        )
        XCTAssertEqual(result, Result(handled: true, action: .backspaceInputPat))
    }
}
