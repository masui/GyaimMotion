import XCTest
@testable import Gyaim

final class ExternalCandidateTests: XCTestCase {

    // MARK: - isValidExternalCandidate

    func testValidExternalCandidate() {
        XCTAssertTrue(GyaimController.isValidExternalCandidate("東京タワー"))
        XCTAssertTrue(GyaimController.isValidExternalCandidate("hello world"))
        XCTAssertTrue(GyaimController.isValidExternalCandidate("テスト"))
    }

    func testEmptyStringIsInvalid() {
        XCTAssertFalse(GyaimController.isValidExternalCandidate(""))
    }

    func testWhitespaceOnlyIsInvalid() {
        XCTAssertFalse(GyaimController.isValidExternalCandidate("   "))
        XCTAssertFalse(GyaimController.isValidExternalCandidate("\t"))
    }

    func testURLIsInvalid() {
        XCTAssertFalse(GyaimController.isValidExternalCandidate("https://example.com"))
        XCTAssertFalse(GyaimController.isValidExternalCandidate("http://example.com/path"))
    }

    func testGyazoHashIsInvalid() {
        // 32-character hex string (Gyazo image hash)
        XCTAssertFalse(GyaimController.isValidExternalCandidate("abcdef1234567890abcdef1234567890"))
    }

    func testNon32CharHexIsValid() {
        // Not exactly 32 chars → valid
        XCTAssertTrue(GyaimController.isValidExternalCandidate("abcdef"))
    }

    // MARK: - buildPrefixCandidates

    func testBuildWithNoExternalCandidates() {
        let searchResults = [
            SearchCandidate(word: "万", reading: "man"),
            SearchCandidate(word: "漫", reading: "man"),
        ]
        let result = GyaimController.buildPrefixCandidates(
            searchResults: searchResults,
            inputPat: "man",
            clipboardCandidate: nil,
            selectedCandidate: nil,
            hiragana: "まん"
        )
        let words = result.map(\.word)
        // First candidate should be the input pattern itself
        XCTAssertEqual(words.first, "man")
        // Search results should follow
        XCTAssertTrue(words.contains("万"))
        XCTAssertTrue(words.contains("漫"))
        // Hiragana appended (total < 8)
        XCTAssertTrue(words.contains("まん"))
    }

    func testBuildWithClipboardCandidate() {
        let searchResults = [
            SearchCandidate(word: "万", reading: "man"),
        ]
        let result = GyaimController.buildPrefixCandidates(
            searchResults: searchResults,
            inputPat: "man",
            clipboardCandidate: "クリップボード",
            selectedCandidate: nil,
            hiragana: "まん"
        )
        let words = result.map(\.word)
        // Order: inputPat, clipboard, search results, hiragana
        XCTAssertEqual(words[0], "man")
        XCTAssertEqual(words[1], "クリップボード")
        XCTAssertTrue(words.contains("万"))
    }

    func testBuildWithSelectedCandidate() {
        let searchResults = [
            SearchCandidate(word: "万", reading: "man"),
        ]
        let result = GyaimController.buildPrefixCandidates(
            searchResults: searchResults,
            inputPat: "man",
            clipboardCandidate: nil,
            selectedCandidate: "選択テキスト",
            hiragana: "まん"
        )
        let words = result.map(\.word)
        XCTAssertEqual(words[0], "man")
        XCTAssertEqual(words[1], "選択テキスト")
    }

    func testBuildWithBothExternalCandidates() {
        let searchResults = [
            SearchCandidate(word: "万", reading: "man"),
        ]
        let result = GyaimController.buildPrefixCandidates(
            searchResults: searchResults,
            inputPat: "man",
            clipboardCandidate: "コピー済み",
            selectedCandidate: "選択中",
            hiragana: "まん"
        )
        let words = result.map(\.word)
        // Order: inputPat, clipboard, selected, search results...
        XCTAssertEqual(words[0], "man")
        XCTAssertEqual(words[1], "コピー済み")
        XCTAssertEqual(words[2], "選択中")
        XCTAssertTrue(words.contains("万"))
    }

    func testBuildRejectInvalidClipboard() {
        let result = GyaimController.buildPrefixCandidates(
            searchResults: [],
            inputPat: "test",
            clipboardCandidate: "https://example.com",
            selectedCandidate: nil,
            hiragana: "てすと"
        )
        let words = result.map(\.word)
        XCTAssertFalse(words.contains("https://example.com"))
    }

    func testBuildRejectInvalidSelected() {
        let result = GyaimController.buildPrefixCandidates(
            searchResults: [],
            inputPat: "test",
            clipboardCandidate: nil,
            selectedCandidate: "abcdef1234567890abcdef1234567890", // Gyazo hash
            hiragana: "てすと"
        )
        let words = result.map(\.word)
        XCTAssertFalse(words.contains("abcdef1234567890abcdef1234567890"))
    }

    func testBuildDeduplicates() {
        let searchResults = [
            SearchCandidate(word: "万", reading: "man"),
            SearchCandidate(word: "万", reading: "man"), // duplicate
        ]
        let result = GyaimController.buildPrefixCandidates(
            searchResults: searchResults,
            inputPat: "man",
            clipboardCandidate: "万", // same as search result
            selectedCandidate: nil,
            hiragana: "まん"
        )
        let words = result.map(\.word)
        // "万" should appear only once
        XCTAssertEqual(words.filter { $0 == "万" }.count, 1)
    }

    func testBuildDoesNotAppendHiraganaWhenEnoughCandidates() {
        // Create 8+ search results
        let searchResults = (1...10).map {
            SearchCandidate(word: "候補\($0)", reading: "kouho\($0)")
        }
        let result = GyaimController.buildPrefixCandidates(
            searchResults: searchResults,
            inputPat: "kouho",
            clipboardCandidate: nil,
            selectedCandidate: nil,
            hiragana: "こうほ"
        )
        let words = result.map(\.word)
        XCTAssertFalse(words.contains("こうほ"), "Hiragana should not be added when >= 8 candidates")
    }

    // MARK: - selectedCandidate specific tests

    func testBuildSelectedCandidatePosition() {
        // When both clipboard and selected are present,
        // order is: inputPat, clipboard, selected, search results
        let result = GyaimController.buildPrefixCandidates(
            searchResults: [SearchCandidate(word: "亜", reading: "a")],
            inputPat: "a",
            clipboardCandidate: "クリップ",
            selectedCandidate: "選択中テキスト",
            hiragana: "あ"
        )
        let words = result.map(\.word)
        XCTAssertEqual(words[0], "a")
        XCTAssertEqual(words[1], "クリップ")
        XCTAssertEqual(words[2], "選択中テキスト")
    }

    func testBuildSelectedCandidateWithoutClipboard() {
        // Selected text alone should appear at position 1 (after inputPat)
        let result = GyaimController.buildPrefixCandidates(
            searchResults: [SearchCandidate(word: "亜", reading: "a")],
            inputPat: "a",
            clipboardCandidate: nil,
            selectedCandidate: "選択のみ",
            hiragana: "あ"
        )
        let words = result.map(\.word)
        XCTAssertEqual(words[0], "a")
        XCTAssertEqual(words[1], "選択のみ")
        XCTAssertTrue(words.contains("亜"))
    }

    func testBuildSelectedCandidateDeduplicatesWithSearchResults() {
        // If selected text matches a search result, it should not appear twice
        let result = GyaimController.buildPrefixCandidates(
            searchResults: [SearchCandidate(word: "東京", reading: "toukyou")],
            inputPat: "toukyou",
            clipboardCandidate: nil,
            selectedCandidate: "東京",
            hiragana: "とうきょう"
        )
        let words = result.map(\.word)
        XCTAssertEqual(words.filter { $0 == "東京" }.count, 1)
    }

    func testBuildSelectedCandidateRejectsURL() {
        let result = GyaimController.buildPrefixCandidates(
            searchResults: [],
            inputPat: "test",
            clipboardCandidate: nil,
            selectedCandidate: "https://example.com/path",
            hiragana: "てすと"
        )
        let words = result.map(\.word)
        XCTAssertFalse(words.contains("https://example.com/path"))
    }

    func testBuildSelectedCandidateRejectsWhitespace() {
        let result = GyaimController.buildPrefixCandidates(
            searchResults: [],
            inputPat: "test",
            clipboardCandidate: nil,
            selectedCandidate: "   ",
            hiragana: "てすと"
        )
        let words = result.map(\.word)
        // Whitespace-only should be rejected by isValidExternalCandidate
        XCTAssertEqual(words.filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }.count, 0)
    }

    func testBuildSelectedCandidateRejectsGyazoHash() {
        let hash = "abcdef1234567890abcdef1234567890"
        let result = GyaimController.buildPrefixCandidates(
            searchResults: [],
            inputPat: "test",
            clipboardCandidate: nil,
            selectedCandidate: hash,
            hiragana: "てすと"
        )
        let words = result.map(\.word)
        XCTAssertFalse(words.contains(hash))
    }

    func testBuildSelectedCandidateDeduplicatesWithClipboard() {
        // If selected and clipboard are the same, should appear only once
        let result = GyaimController.buildPrefixCandidates(
            searchResults: [],
            inputPat: "test",
            clipboardCandidate: "同じテキスト",
            selectedCandidate: "同じテキスト",
            hiragana: "てすと"
        )
        let words = result.map(\.word)
        XCTAssertEqual(words.filter { $0 == "同じテキスト" }.count, 1)
    }

    func testBuildExternalCandidatesNotInExactMode() {
        // buildPrefixCandidates is only called in prefix mode (searchMode == 0).
        // In exact mode (searchMode == 1), external candidates are not injected.
        // This test verifies that the static method does inject when called,
        // confirming the controller's responsibility is only about when to call it.
        let result = GyaimController.buildPrefixCandidates(
            searchResults: [],
            inputPat: "test",
            clipboardCandidate: "clipboard",
            selectedCandidate: "selected",
            hiragana: "てすと"
        )
        let words = result.map(\.word)
        XCTAssertTrue(words.contains("clipboard"))
        XCTAssertTrue(words.contains("selected"))
    }
}
