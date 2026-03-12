import XCTest
@testable import Gyaim

final class GoogleTransliterateTests: XCTestCase {

    // MARK: - filterCandidates (pure function)

    func testFilterRemovesHiragana() {
        let result = GoogleTransliterate.filterCandidates(
            raw: ["目黒", "めぐろ", "目黒区"],
            query: "meguro"
        )
        XCTAssertFalse(result.contains("めぐろ"))
        XCTAssertTrue(result.contains("目黒"))
        XCTAssertTrue(result.contains("目黒区"))
    }

    func testFilterRemovesKatakana() {
        let result = GoogleTransliterate.filterCandidates(
            raw: ["東京", "トウキョウ", "とうきょう"],
            query: "toukyou"
        )
        XCTAssertFalse(result.contains("トウキョウ"))
        XCTAssertFalse(result.contains("とうきょう"))
        XCTAssertTrue(result.contains("東京"))
    }

    func testFilterPreservesKanji() {
        let result = GoogleTransliterate.filterCandidates(
            raw: ["渋谷", "渋谷区", "渋谷駅"],
            query: "sibuya"
        )
        XCTAssertEqual(result, ["渋谷", "渋谷区", "渋谷駅"])
    }

    func testFilterDeduplicates() {
        let result = GoogleTransliterate.filterCandidates(
            raw: ["東京", "東京", "東京都"],
            query: "toukyou"
        )
        XCTAssertEqual(result, ["東京", "東京都"])
    }

    func testFilterEmptyInput() {
        let result = GoogleTransliterate.filterCandidates(
            raw: [],
            query: "test"
        )
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - buildGoogleCandidates (candidate assembly)

    func testBuildGoogleCandidatesWithResults() {
        let results = ["目黒", "目黒区"]
        let candidates = GoogleTransliterate.buildGoogleCandidates(
            apiResults: results,
            query: "meguro"
        )
        let words = candidates.map(\.word)
        // First should be the raw query
        XCTAssertEqual(words.first, "meguro")
        // API results follow
        XCTAssertTrue(words.contains("目黒"))
        XCTAssertTrue(words.contains("目黒区"))
        // Hiragana/katakana fallback at end
        XCTAssertTrue(words.contains("めぐろ"))
        XCTAssertTrue(words.contains("メグロ"))
    }

    func testBuildGoogleCandidatesEmptyResults() {
        let candidates = GoogleTransliterate.buildGoogleCandidates(
            apiResults: [],
            query: "meguro"
        )
        let words = candidates.map(\.word)
        XCTAssertEqual(words.first, "meguro")
        XCTAssertTrue(words.contains("めぐろ"))
        XCTAssertTrue(words.contains("メグロ"))
    }

    func testBuildGoogleCandidatesDeduplicates() {
        let candidates = GoogleTransliterate.buildGoogleCandidates(
            apiResults: ["めぐろ", "目黒"],
            query: "meguro"
        )
        let words = candidates.map(\.word)
        // "めぐろ" should appear only once
        XCTAssertEqual(words.filter { $0 == "めぐろ" }.count, 1)
    }

    func testBuildGoogleCandidatesReadingIsSet() {
        let candidates = GoogleTransliterate.buildGoogleCandidates(
            apiResults: ["目黒"],
            query: "meguro"
        )
        // API result candidates should have reading set
        let meguro = candidates.first { $0.word == "目黒" }
        XCTAssertEqual(meguro?.reading, "meguro")
    }

    // MARK: - Trigger suffix configuration

    func testDefaultTriggerSuffix() {
        // Clean up any existing value
        UserDefaults.standard.removeObject(forKey: "googleTransliterateTrigger")
        XCTAssertEqual(GoogleTransliterate.triggerSuffix, "`")
    }

    func testCustomTriggerSuffix() {
        let original = UserDefaults.standard.string(forKey: "googleTransliterateTrigger")
        defer {
            if let orig = original {
                UserDefaults.standard.set(orig, forKey: "googleTransliterateTrigger")
            } else {
                UserDefaults.standard.removeObject(forKey: "googleTransliterateTrigger")
            }
        }

        GoogleTransliterate.setTriggerSuffix("@")
        XCTAssertEqual(GoogleTransliterate.triggerSuffix, "@")
    }

    func testHasTriggerSuffix() {
        UserDefaults.standard.removeObject(forKey: "googleTransliterateTrigger")
        XCTAssertTrue(GoogleTransliterate.hasTriggerSuffix("meguro`"))
        XCTAssertFalse(GoogleTransliterate.hasTriggerSuffix("meguro"))
        XCTAssertFalse(GoogleTransliterate.hasTriggerSuffix("`"))  // single char only
    }

    func testHasTriggerSuffixCustom() {
        let original = UserDefaults.standard.string(forKey: "googleTransliterateTrigger")
        defer {
            if let orig = original {
                UserDefaults.standard.set(orig, forKey: "googleTransliterateTrigger")
            } else {
                UserDefaults.standard.removeObject(forKey: "googleTransliterateTrigger")
            }
        }

        GoogleTransliterate.setTriggerSuffix("@")
        XCTAssertTrue(GoogleTransliterate.hasTriggerSuffix("meguro@"))
        XCTAssertFalse(GoogleTransliterate.hasTriggerSuffix("meguro`"))
    }

    func testStripTriggerSuffix() {
        UserDefaults.standard.removeObject(forKey: "googleTransliterateTrigger")
        XCTAssertEqual(GoogleTransliterate.stripTriggerSuffix("meguro`"), "meguro")
    }

    // MARK: - combineSegments (multi-word issue #14)

    func testCombineSegmentsSingle() {
        let result = GoogleTransliterate.combineSegments([["増井", "桝井"]])
        XCTAssertEqual(result, ["増井", "桝井"])
    }

    func testCombineSegmentsMultiple() {
        let result = GoogleTransliterate.combineSegments([
            ["増井", "桝井"],
            ["俊之", "敏之"]
        ])
        XCTAssertEqual(result, ["増井俊之", "増井敏之", "桝井俊之", "桝井敏之"])
    }

    func testCombineSegmentsThreeSegments() {
        let result = GoogleTransliterate.combineSegments([
            ["A", "B"],
            ["1", "2"],
            ["x"]
        ])
        XCTAssertEqual(result, ["A1x", "A2x", "B1x", "B2x"])
    }

    func testCombineSegmentsEmpty() {
        let result = GoogleTransliterate.combineSegments([])
        XCTAssertTrue(result.isEmpty)
    }

    func testCombineSegmentsRespectsLimit() {
        let result = GoogleTransliterate.combineSegments([
            ["A", "B", "C", "D", "E"],
            ["1", "2", "3", "4", "5"]
        ], limit: 5)
        XCTAssertEqual(result.count, 5)
    }

    // MARK: - Timeout configuration

    func testSessionHasShortTimeout() {
        // Verify the shared session has a reasonable timeout (not default 60s)
        let timeout = GoogleTransliterate.sessionTimeout
        XCTAssertLessThanOrEqual(timeout, 5.0)
        XCTAssertGreaterThan(timeout, 0)
    }
}
