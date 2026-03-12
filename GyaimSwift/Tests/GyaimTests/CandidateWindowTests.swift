import XCTest
@testable import Gyaim

final class CandidateWindowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "candidateDisplayMode")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "candidateDisplayMode")
        super.tearDown()
    }

    // MARK: - Phase 1: enum + UserDefaults

    func testDefaultDisplayModeIsList() {
        XCTAssertEqual(CandidateDisplayMode.current, .list)
    }

    func testSetDisplayModeClassic() {
        CandidateDisplayMode.setCurrent(.classic)
        XCTAssertEqual(CandidateDisplayMode.current, .classic)
    }

    func testSetDisplayModeList() {
        CandidateDisplayMode.setCurrent(.classic)
        CandidateDisplayMode.setCurrent(.list)
        XCTAssertEqual(CandidateDisplayMode.current, .list)
    }

    // MARK: - Phase 2: Classic mode rendering

    func testUpdateCandidatesClassicMode() {
        CandidateDisplayMode.setCurrent(.classic)
        let window = CandidateWindow()
        window.updateCandidates(["候補1", "候補2", "候補3"], selectedIndex: 0)

        // Classic mode should have classicTextField with space-separated text
        let textField = findClassicTextField(in: window)
        XCTAssertNotNil(textField, "クラシックモードにはテキストフィールドが必要")
        XCTAssertTrue(textField?.stringValue.contains("候補1") ?? false)
        XCTAssertTrue(textField?.stringValue.contains("候補2") ?? false)

        // Classic mode should have background image view
        let imageView = findClassicImageView(in: window)
        XCTAssertNotNil(imageView, "クラシックモードには背景画像が必要")

        CandidateWindow.shared = nil
    }

    func testClassicModeMaxVisible() {
        CandidateDisplayMode.setCurrent(.classic)
        let window = CandidateWindow()
        let words = (0..<15).map { "候補\($0)" }
        window.updateCandidates(words, selectedIndex: 0)

        let textField = findClassicTextField(in: window)
        XCTAssertNotNil(textField)
        // Classic mode shows at most 11 candidates (double-space separated)
        let parts = textField!.stringValue.components(separatedBy: "  ").filter { !$0.isEmpty }
        XCTAssertLessThanOrEqual(parts.count, 11, "クラシックモードは最大11候補")

        CandidateWindow.shared = nil
    }

    func testApplyDisplayModeSwitches() {
        let window = CandidateWindow()
        window.updateCandidates(["A", "B", "C"], selectedIndex: 0)

        // Default list mode — stackView should have labels
        let stackLabels = findStackViewLabels(in: window)
        XCTAssertFalse(stackLabels.isEmpty, "リストモードではstackViewにラベルがあるべき")

        // Switch to classic
        CandidateDisplayMode.setCurrent(.classic)
        window.applyDisplayMode()
        window.updateCandidates(["A", "B", "C"], selectedIndex: 0)

        let textField = findClassicTextField(in: window)
        XCTAssertNotNil(textField, "クラシックモード切り替え後にテキストフィールドがあるべき")

        // Switch back to list
        CandidateDisplayMode.setCurrent(.list)
        window.applyDisplayMode()
        window.updateCandidates(["A", "B", "C"], selectedIndex: 0)

        let stackLabelsAfter = findStackViewLabels(in: window)
        XCTAssertFalse(stackLabelsAfter.isEmpty, "リストモードに戻った後stackViewにラベルがあるべき")

        CandidateWindow.shared = nil
    }

    func testListModeMaxVisible() {
        CandidateDisplayMode.setCurrent(.list)
        let window = CandidateWindow()
        let words = (0..<15).map { "候補\($0)" }
        window.updateCandidates(words, selectedIndex: 0)

        let labels = findStackViewLabels(in: window)
        XCTAssertLessThanOrEqual(labels.count, 9, "リストモードは最大9候補")

        CandidateWindow.shared = nil
    }

    // MARK: - Window positioning (pure function tests)

    // lineRect.origin.y = カーソル行の下端 (macOS座標系: Y上向き)
    // lineRect.origin.y + lineRect.height = カーソル行の上端
    // setFrameOrigin = ウィンドウの左下を設定

    func testListModePositionsBelowCursor() {
        // 画面中央のカーソル、リストモード → カーソルの下に配置
        let lineRect = NSRect(x: 100, y: 500, width: 1, height: 20)
        let winSize = NSSize(width: 260, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        let origin = CandidateWindowPositioner.calculate(
            lineRect: lineRect, winSize: winSize,
            screenFrame: screenFrame, mode: .list)

        // ウィンドウ上端 = カーソル下端 - gap
        XCTAssertEqual(origin.y, lineRect.origin.y - winSize.height - 5,
                       "リストモードはカーソルの下に配置")
        XCTAssertEqual(origin.x, lineRect.origin.x - 5)
    }

    func testListModeFlipsAboveWhenNearScreenBottom() {
        // カーソルが画面下端付近 → 下に収まらないので上にフリップ
        let lineRect = NSRect(x: 100, y: 50, width: 1, height: 20)
        let winSize = NSSize(width: 260, height: 200)
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        let origin = CandidateWindowPositioner.calculate(
            lineRect: lineRect, winSize: winSize,
            screenFrame: screenFrame, mode: .list)

        // カーソル上端の上に配置
        XCTAssertEqual(origin.y, lineRect.origin.y + lineRect.height + 5,
                       "画面下端ではカーソルの上に配置")
    }

    func testClassicModePositionsBelowCursor() {
        // クラシックモード: 他のIMEと同様にカーソルの下に配置
        // (吹き出しの三角は装飾であり、位置決めはカーソル下が自然)
        let lineRect = NSRect(x: 100, y: 500, width: 1, height: 20)
        let winSize = NSSize(width: 300, height: 100)
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        let origin = CandidateWindowPositioner.calculate(
            lineRect: lineRect, winSize: winSize,
            screenFrame: screenFrame, mode: .classic)

        // ウィンドウ上端 = カーソル下端 (gap=0でぴったり)
        XCTAssertEqual(origin.y, lineRect.origin.y - winSize.height,
                       "クラシックモードはカーソルの下に配置")
    }

    func testClassicModeFlipsAboveWhenNearScreenBottom() {
        let lineRect = NSRect(x: 100, y: 50, width: 1, height: 20)
        let winSize = NSSize(width: 300, height: 100)
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        let origin = CandidateWindowPositioner.calculate(
            lineRect: lineRect, winSize: winSize,
            screenFrame: screenFrame, mode: .classic)

        // 下に収まらないのでカーソル上端の上に配置
        XCTAssertEqual(origin.y, lineRect.origin.y + lineRect.height,
                       "画面下端ではカーソルの上に配置")
    }

    func testPositionClampsToScreenRight() {
        // カーソルが画面右端付近 → ウィンドウが右にはみ出さない
        let lineRect = NSRect(x: 1400, y: 500, width: 1, height: 20)
        let winSize = NSSize(width: 300, height: 100)
        let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

        let origin = CandidateWindowPositioner.calculate(
            lineRect: lineRect, winSize: winSize,
            screenFrame: screenFrame, mode: .classic)

        XCTAssertLessThanOrEqual(origin.x + winSize.width, screenFrame.maxX,
                                  "ウィンドウが画面右端からはみ出さない")
    }

    // MARK: - Helpers

    private func findClassicTextField(in window: CandidateWindow) -> NSTextField? {
        guard let contentView = window.contentView else { return nil }
        return findView(in: contentView) { (tf: NSTextField) in
            tf.tag == 1001 // classicTextField tag
        }
    }

    private func findClassicImageView(in window: CandidateWindow) -> NSImageView? {
        guard let contentView = window.contentView else { return nil }
        return findView(in: contentView) { (iv: NSImageView) in true }
    }

    private func findStackViewLabels(in window: CandidateWindow) -> [NSTextField] {
        guard let contentView = window.contentView else { return [] }
        var labels: [NSTextField] = []
        findLabelsInStackView(in: contentView, labels: &labels)
        return labels
    }

    private func findLabelsInStackView(in view: NSView, labels: inout [NSTextField]) {
        if let stackView = view as? NSStackView {
            for subview in stackView.arrangedSubviews {
                if let tf = subview as? NSTextField {
                    labels.append(tf)
                }
            }
            return
        }
        for subview in view.subviews {
            findLabelsInStackView(in: subview, labels: &labels)
        }
    }

    private func findView<T: NSView>(in view: NSView, matching predicate: (T) -> Bool) -> T? {
        if let match = view as? T, predicate(match) {
            return match
        }
        for subview in view.subviews {
            if let found = findView(in: subview, matching: predicate) {
                return found
            }
        }
        return nil
    }
}
