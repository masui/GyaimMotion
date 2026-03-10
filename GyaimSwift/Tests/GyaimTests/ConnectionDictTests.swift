import XCTest
@testable import Gyaim

final class ConnectionDictTests: XCTestCase {
    var dict: ConnectionDict!

    override func setUpWithError() throws {
        // Try test bundle first
        if let path = Bundle(for: type(of: self)).path(forResource: "dict", ofType: "txt") {
            dict = ConnectionDict(dictFile: path)
            return
        }
        // Fall back to source tree path
        let sourceFile = URL(fileURLWithPath: #file)
        let projectDir = sourceFile
            .deletingLastPathComponent() // GyaimTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // GyaimSwift
        let dictPath = projectDir.appendingPathComponent("Resources/dict.txt").path
        if FileManager.default.fileExists(atPath: dictPath) {
            dict = ConnectionDict(dictFile: dictPath)
            return
        }
        throw XCTSkip("dict.txt not found")
    }

    func testSearchSimple() throws {
        var results: [(String, String)] = []
        dict.search(pat: "man", searchMode: 1) { word, pat, _ in
            results.append((word, pat))
        }
        let words = results.map(\.0)
        XCTAssertTrue(words.contains("万"), "Expected '万' in results: \(words)")
    }

    func testSearchPrefixMode() throws {
        var results: [(String, String)] = []
        dict.search(pat: "tou", searchMode: 0) { word, pat, _ in
            results.append((word, pat))
        }
        XCTAssertFalse(results.isEmpty, "Expected results for prefix 'tou'")
    }

    func testSearchCompound() throws {
        // "i"(言, in=10, out=11) + "*います"(in=11) = "言います"
        var results: [(String, String)] = []
        dict.search(pat: "iimasu", searchMode: 1) { word, pat, _ in
            results.append((word, pat))
        }
        let words = results.map(\.0)
        // The compound should include words connected via outConnection
        XCTAssertTrue(words.contains { $0.contains("言") },
                      "Expected compound containing '言' in results: \(words)")
    }
}
