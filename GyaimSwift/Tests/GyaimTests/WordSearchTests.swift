import XCTest
@testable import Gyaim

final class WordSearchTests: XCTestCase {
    var ws: WordSearch!
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let localDict = tempDir.appendingPathComponent("localdict.txt")
        let studyDict = tempDir.appendingPathComponent("studydict.txt")
        try "".write(to: localDict, atomically: true, encoding: .utf8)
        try "".write(to: studyDict, atomically: true, encoding: .utf8)

        // Find dict.txt
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // GyaimTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // GyaimSwift
        let dictPath = projectDir.appendingPathComponent("Resources/dict.txt").path

        guard FileManager.default.fileExists(atPath: dictPath) else {
            throw XCTSkip("dict.txt not found at \(dictPath)")
        }

        ws = WordSearch(connectionDictFile: dictPath,
                        localDictFile: localDict.path,
                        studyDictFile: studyDict.path)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSearchPrefix() throws {
        try XCTSkipIf(ws == nil)
        let results = ws.search(query: "man", searchMode: 0)
        let words = results.map(\.word)
        XCTAssertTrue(words.contains("万"), "Expected '万' in \(words)")
    }

    func testSearchExact() throws {
        try XCTSkipIf(ws == nil)
        let results = ws.search(query: "man", searchMode: 1)
        let words = results.map(\.word)
        XCTAssertTrue(words.contains("万"), "Expected '万' in exact search: \(words)")
    }

    func testTimestamp() throws {
        try XCTSkipIf(ws == nil)
        let results = ws.search(query: "ds", searchMode: 0)
        XCTAssertFalse(results.isEmpty, "Expected timestamp result for 'ds'")
        XCTAssertTrue(results[0].word.contains("/"), "Timestamp should contain '/'")
    }

    func testUppercase() throws {
        try XCTSkipIf(ws == nil)
        let results = ws.search(query: "Hello", searchMode: 0)
        XCTAssertEqual(results.first?.word, "Hello")
    }

    func testEmptyQuery() throws {
        try XCTSkipIf(ws == nil)
        let results = ws.search(query: "", searchMode: 0)
        XCTAssertTrue(results.isEmpty)
    }

    func testRegisterAndSearch() throws {
        try XCTSkipIf(ws == nil)
        ws.register(word: "テスト単語", reading: "testtango")
        let results = ws.search(query: "testtango", searchMode: 1)
        let words = results.map(\.word)
        XCTAssertTrue(words.contains("テスト単語"))
    }
}
