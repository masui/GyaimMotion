import XCTest
@testable import Gyaim

final class PreferencesWindowTests: XCTestCase {

    private var window: PreferencesWindow!

    override func setUp() {
        super.setUp()
        // Reset UserDefaults to ensure clean state
        UserDefaults.standard.removeObject(forKey: "clipboardCandidateEnabled")
        UserDefaults.standard.removeObject(forKey: "selectedTextCandidateEnabled")
        window = PreferencesWindow()
    }

    override func tearDown() {
        window.close()
        PreferencesWindow.shared = nil
        window = nil
        UserDefaults.standard.removeObject(forKey: "clipboardCandidateEnabled")
        UserDefaults.standard.removeObject(forKey: "selectedTextCandidateEnabled")
        super.tearDown()
    }

    // MARK: - Helpers

    /// Find a checkbox (NSButton) by its title in the window's content view hierarchy.
    private func findCheckbox(titled title: String) -> NSButton? {
        guard let contentView = window.contentView else { return nil }
        return findButton(in: contentView, titled: title)
    }

    private func findButton(in view: NSView, titled title: String) -> NSButton? {
        for subview in view.subviews {
            if let button = subview as? NSButton, button.title == title {
                return button
            }
            if let found = findButton(in: subview, titled: title) {
                return found
            }
        }
        return nil
    }

    // MARK: - Checkbox existence

    func testClipboardToggleExists() {
        let toggle = findCheckbox(titled: "クリップボードの内容を候補に表示する")
        XCTAssertNotNil(toggle, "クリップボード候補のトグルが見つからない")
    }

    func testSelectedTextToggleExists() {
        let toggle = findCheckbox(titled: "選択テキストを候補に表示する")
        XCTAssertNotNil(toggle, "選択テキスト候補のトグルが見つからない")
    }

    func testLogToggleExists() {
        let toggle = findCheckbox(titled: "ロギングを有効にする")
        XCTAssertNotNil(toggle, "ログトグルが見つからない")
    }

    // MARK: - Default state (both ON when UserDefaults unset)

    func testClipboardToggleDefaultOn() {
        let toggle = findCheckbox(titled: "クリップボードの内容を候補に表示する")!
        XCTAssertEqual(toggle.state, .on, "デフォルトでONであるべき")
    }

    func testSelectedTextToggleDefaultOn() {
        let toggle = findCheckbox(titled: "選択テキストを候補に表示する")!
        XCTAssertEqual(toggle.state, .on, "デフォルトでONであるべき")
    }

    // MARK: - Toggle reflects pre-set UserDefaults

    func testClipboardToggleReflectsDisabledSetting() {
        window.close()
        GyaimController.setClipboardCandidateEnabled(false)
        window = PreferencesWindow()

        let toggle = findCheckbox(titled: "クリップボードの内容を候補に表示する")!
        XCTAssertEqual(toggle.state, .off, "UserDefaultsがfalseならOFFであるべき")
    }

    func testSelectedTextToggleReflectsDisabledSetting() {
        window.close()
        GyaimController.setSelectedTextCandidateEnabled(false)
        window = PreferencesWindow()

        let toggle = findCheckbox(titled: "選択テキストを候補に表示する")!
        XCTAssertEqual(toggle.state, .off, "UserDefaultsがfalseならOFFであるべき")
    }

    // MARK: - Click toggle updates UserDefaults

    func testClickClipboardToggleUpdatesUserDefaults() {
        let toggle = findCheckbox(titled: "クリップボードの内容を候補に表示する")!
        // Simulate click: toggle OFF
        toggle.state = .off
        toggle.sendAction(toggle.action, to: toggle.target)
        XCTAssertFalse(GyaimController.isClipboardCandidateEnabled)

        // Simulate click: toggle ON
        toggle.state = .on
        toggle.sendAction(toggle.action, to: toggle.target)
        XCTAssertTrue(GyaimController.isClipboardCandidateEnabled)
    }

    func testClickSelectedTextToggleUpdatesUserDefaults() {
        let toggle = findCheckbox(titled: "選択テキストを候補に表示する")!
        toggle.state = .off
        toggle.sendAction(toggle.action, to: toggle.target)
        XCTAssertFalse(GyaimController.isSelectedTextCandidateEnabled)

        toggle.state = .on
        toggle.sendAction(toggle.action, to: toggle.target)
        XCTAssertTrue(GyaimController.isSelectedTextCandidateEnabled)
    }

    // MARK: - Section title exists

    func testCandidateSectionTitleExists() {
        guard let contentView = window.contentView else {
            XCTFail("contentView is nil")
            return
        }
        let labels = contentView.subviews.compactMap { $0 as? NSTextField }
        let found = labels.contains { $0.stringValue == "候補" }
        XCTAssertTrue(found, "「候補」セクションタイトルが見つからない")
    }
}
