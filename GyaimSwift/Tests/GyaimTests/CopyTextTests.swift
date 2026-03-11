import XCTest
import Cocoa
@testable import Gyaim

final class CopyTextTests: XCTestCase {

    // MARK: - CopyText file I/O

    func testGetReturnsSetContent() {
        let content = "get-test-\(UUID().uuidString)"
        CopyText.set(content)
        XCTAssertEqual(CopyText.get(), content)
    }

    func testNilInputIgnored() {
        let content = "nil-test-\(UUID().uuidString)"
        CopyText.set(content)
        let timeBefore = CopyText.time

        Thread.sleep(forTimeInterval: 0.05)
        CopyText.set(nil)

        XCTAssertEqual(CopyText.time, timeBefore,
                       "set(nil) should not change timestamp")
        XCTAssertEqual(CopyText.get(), content)
    }

    func testTimestampUpdatedOnNewContent() {
        let timeBefore = CopyText.time
        let unique = "new-\(UUID().uuidString)"

        Thread.sleep(forTimeInterval: 0.05)
        CopyText.set(unique)

        XCTAssertGreaterThan(CopyText.time, timeBefore)
    }

    func testTimestampNotUpdatedOnSameContent() {
        let content = "same-\(UUID().uuidString)"
        CopyText.set(content)
        let timeAfterFirst = CopyText.time

        Thread.sleep(forTimeInterval: 0.05)
        CopyText.set(content)

        XCTAssertEqual(CopyText.time, timeAfterFirst,
                       "Timestamp should NOT update when content is the same")
    }

    // MARK: - Pasteboard changeCount based clipboard detection

    func testPasteboardChangeCountIncrementsOnCopy() {
        let pb = NSPasteboard.general
        let before = pb.changeCount
        pb.clearContents()
        pb.setString("test-\(UUID().uuidString)", forType: .string)
        let after = pb.changeCount
        XCTAssertGreaterThan(after, before,
                             "changeCount should increment when pasteboard content changes")
    }

    func testPasteboardChangeCountStableWithoutCopy() {
        let pb = NSPasteboard.general
        let count1 = pb.changeCount
        let count2 = pb.changeCount
        XCTAssertEqual(count1, count2,
                       "changeCount should not change without pasteboard modification")
    }

    func testClipboardCandidateShownOnlyForNewCopy() {
        // Simulate the controller logic:
        // 1. Record changeCount as "seen"
        // 2. User copies → changeCount increments → should show
        // 3. User types again without copying → same changeCount → should NOT show
        let pb = NSPasteboard.general

        // Step 1: Mark current state as seen
        var lastSeen = pb.changeCount

        // Step 2: User copies something new
        pb.clearContents()
        pb.setString("new-clipboard-content", forType: .string)
        let currentCount = pb.changeCount

        XCTAssertNotEqual(currentCount, lastSeen, "Should detect new clipboard content")

        // Simulate consuming the clipboard candidate
        lastSeen = currentCount

        // Step 3: Next input without copying
        let nextCount = pb.changeCount
        XCTAssertEqual(nextCount, lastSeen,
                       "Should NOT show clipboard again without new copy")
    }
}
