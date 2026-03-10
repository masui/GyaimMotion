import Cocoa
import InputMethodKit

/// Central IME controller implementing InputMethodKit protocol.
/// Ported from GyaimController.rb (Toshiyuki Masui, 2011-2015)
@objc(GyaimController)
class GyaimController: IMKInputController {
    private static var shared: GyaimController?

    private var inputPat = ""
    private var candidates: [SearchCandidate] = []
    private var nthCand = 0
    private var searchMode = 0
    private var selectedStr: String?
    private var tmpImageDisplayed = false
    private var bsThrough = false

    private var ws: WordSearch?
    private var rk = RomaKana()
    private var candWindow: CandidateWindow?

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)

        if candWindow == nil {
            candWindow = CandidateWindow()
        }

        if ws == nil {
            if let dictPath = Bundle.main.path(forResource: "dict", ofType: "txt") {
                ws = WordSearch(connectionDictFile: dictPath,
                                localDictFile: Config.localDictFile,
                                studyDictFile: Config.studyDictFile)
            }
        }

        if let client = inputClient as? (IMKTextInput & NSObjectProtocol) {
            CopyText.set(NSPasteboard.general.string(forType: .string))
        }

        resetState()
        GyaimController.shared = self
    }

    override func activateServer(_ sender: Any!) {
        CopyText.set(NSPasteboard.general.string(forType: .string))
        ws?.start()
        showWindow()
    }

    override func deactivateServer(_ sender: Any!) {
        hideWindow()
        fix()
        ws?.finish()
    }

    private func resetState() {
        inputPat = ""
        candidates = []
        nthCand = 0
        searchMode = 0
        selectedStr = nil
    }

    private var converting: Bool {
        !inputPat.isEmpty
    }

    // MARK: - Menu & Preferences

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "Gyaim")
        let item = NSMenuItem(title: "Gyaim 設定...",
                              action: #selector(openPreferences(_:)),
                              keyEquivalent: "")
        item.target = self
        menu.addItem(item)

        let dictItem = NSMenuItem(title: "ユーザー辞書...",
                                  action: #selector(openDictEditor(_:)),
                                  keyEquivalent: "")
        dictItem.target = self
        menu.addItem(dictItem)
        return menu
    }

    @objc func openDictEditor(_ sender: Any?) {
        DictEditorWindow.show()
    }

    @objc func openPreferences(_ sender: Any?) {
        PreferencesWindow.show()
    }

    override func showPreferences(_ sender: Any!) {
        PreferencesWindow.show()
    }

    // MARK: - Event Handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        let kVirtualJISRomanModeKey: UInt16 = 102
        let kVirtualJISKanaModeKey: UInt16 = 104

        guard event.type == .keyDown else { return false }

        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags

        // Remember selected text for potential registration
        if let client = sender as? IMKTextInput {
            let range = client.selectedRange()
            if let attrStr = client.attributedSubstring(from: range) {
                let s = attrStr.string
                if !s.isEmpty { selectedStr = s }
            }
        }

        if keyCode == kVirtualJISKanaModeKey || keyCode == kVirtualJISRomanModeKey {
            return true
        }

        // Configurable shortcuts: hiragana / katakana confirm (modifier keys)
        if converting, KeyBindings.shared.matchesHiragana(event: event) {
            fixAsKana(hiragana: true, client: sender)
            return true
        }
        if converting, KeyBindings.shared.matchesKatakana(event: event) {
            fixAsKana(hiragana: false, client: sender)
            return true
        }

        guard let eventString = event.characters, !eventString.isEmpty else { return true }

        guard let c = eventString.utf8.first else { return true }

        // Single-key kana confirm: ; → hiragana, q → katakana (configurable)
        if converting, modifierFlags.intersection([.control, .command, .option]).isEmpty {
            if c == KeyBindings.shared.hiraganaChar {
                fixAsKana(hiragana: true, client: sender)
                return true
            }
            if c == KeyBindings.shared.katakanaChar {
                fixAsKana(hiragana: false, client: sender)
                return true
            }
        }

        var handled = false

        // Backspace / Escape
        if c == 0x08 || c == 0x7f || c == 0x1b {
            if converting, tmpImageDisplayed, !bsThrough {
                tmpImageDisplayed = false
                Emulation.key(Emulation.deleteKeyCode)
                return true
            }
            if !bsThrough, converting {
                if nthCand > 0 {
                    nthCand -= 1
                    showCands(client: sender)
                } else {
                    inputPat = String(inputPat.dropLast())
                    searchAndShowCands(client: sender)
                }
                handled = true
            }
            bsThrough = false
        }
        // Space
        else if c == 0x20 {
            if converting {
                if tmpImageDisplayed {
                    Emulation.key("z", modifier: .maskCommand)
                    Emulation.key(Emulation.spaceKeyCode)
                    tmpImageDisplayed = false
                    return true
                }
                if nthCand < candidates.count - 1 {
                    nthCand += 1
                    showCands(client: sender)
                }
                handled = true
            }
        }
        // Enter
        else if c == 0x0a || c == 0x0d {
            if converting {
                if tmpImageDisplayed {
                    tmpImageDisplayed = false
                    resetState()
                    return true
                }
                if searchMode > 0 {
                    fix(client: sender)
                } else {
                    if nthCand == 0 {
                        searchMode = 1
                        searchAndShowCands(client: sender)
                    } else {
                        fix(client: sender)
                    }
                }
                handled = true
            }
        }
        // Number keys 1-9: select candidate from list (only when list is visible)
        else if converting, nthCand > 0 || searchMode > 0,
                c >= 0x31, c <= 0x39,
                modifierFlags.intersection([.control, .command, .option]).isEmpty {
            let num = Int(c - 0x30) // 1-9
            let targetIndex = nthCand + num
            if targetIndex < candidates.count {
                nthCand = targetIndex
                fix(client: sender)
            }
            handled = true
        }
        // Printable character (0x21-0x7e), no Control/Command/Option
        else if c >= 0x21, c <= 0x7e,
                modifierFlags.intersection([.control, .command, .option]).isEmpty {
            if nthCand > 0 || searchMode > 0 {
                fix(client: sender)
            }
            inputPat += eventString
            searchAndShowCands(client: sender)
            searchMode = 0
            handled = true
        }

        showWindow()
        return handled
    }

    // MARK: - Search & Display

    private func searchAndShowCands(client sender: Any?) {
        guard let ws else { return }

        if searchMode == 1 {
            candidates = ws.search(query: inputPat, searchMode: searchMode)
            let katakana = rk.roma2katakana(inputPat)
            if !katakana.isEmpty {
                candidates = candidates.filter { $0.word != katakana }
                candidates.insert(SearchCandidate(word: katakana), at: 0)
            }
            let hiragana = rk.roma2hiragana(inputPat)
            if !hiragana.isEmpty {
                candidates = candidates.filter { $0.word != hiragana }
                candidates.insert(SearchCandidate(word: hiragana), at: 0)
            }
        } else {
            candidates = ws.search(query: inputPat, searchMode: searchMode)

            // Prepend selected text if valid
            if let sel = selectedStr,
               !sel.trimmingCharacters(in: .whitespaces).isEmpty,
               sel.range(of: "^[0-9a-f]{32}$", options: [.regularExpression, .caseInsensitive]) == nil,
               !sel.hasPrefix("http") {
                candidates.insert(SearchCandidate(word: sel), at: 0)
            }

            // Input pattern itself as first candidate
            candidates.insert(SearchCandidate(word: inputPat), at: 0)

            // Add hiragana if few candidates
            if candidates.count < 8 {
                let hiragana = rk.roma2hiragana(inputPat)
                candidates.append(SearchCandidate(word: hiragana))
            }

            // Deduplicate preserving order
            var seen: Set<String> = []
            candidates = candidates.filter { c in
                if seen.contains(c.word) { return false }
                seen.insert(c.word)
                return true
            }
        }

        nthCand = 0
        showCands(client: sender)
    }

    private func showCands(client sender: Any?) {
        let words = candidates.map(\.word)
        guard nthCand < words.count, let word = words[safe: nthCand] else { return }

        guard let client = sender as? IMKTextInput else { return }

        if ImageManager.isImageCandidate(word) {
            // Image candidate handling
            client.insertText(" ", replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
            bsThrough = true
            Emulation.key(Emulation.deleteKeyCode)
            ImageManager.pasteGyazoToPasteboard(word)
            Emulation.key("v", modifier: .maskCommand)
            tmpImageDisplayed = true
        } else {
            if tmpImageDisplayed {
                Emulation.key("z", modifier: .maskCommand)
                tmpImageDisplayed = false
            }

            let kTSMHiliteRawText = 2
            let attrs = mark(forStyle: kTSMHiliteRawText, at: NSRange(location: 0, length: word.count))
                as? [NSAttributedString.Key: Any] ?? [:]
            let attrStr = NSAttributedString(string: word, attributes: attrs)
            client.setMarkedText(attrStr,
                                 selectionRange: NSRange(location: word.count, length: 0),
                                 replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }

        // Update vertical candidate list
        var candList: [String] = []
        for i in 0..<9 {
            let idx = nthCand + 1 + i
            guard idx < words.count, let cand = words[safe: idx] else { break }
            candList.append(cand)
        }
        candWindow?.updateCandidates(candList, selectedIndex: -1)
    }

    // MARK: - Fix as Kana (F6/F7)

    private func fixAsKana(hiragana: Bool, client sender: Any?) {
        guard converting else { return }
        let word = hiragana ? rk.roma2hiragana(inputPat) : rk.roma2katakana(inputPat)

        let resolvedClient = (sender as? IMKTextInput) ?? (self.client() as? IMKTextInput)
        guard !word.isEmpty, let client = resolvedClient else {
            resetState()
            hideWindow()
            return
        }

        let attrs: [NSAttributedString.Key: Any] = [:]
        let attrStr = NSAttributedString(string: word, attributes: attrs)
        client.setMarkedText(attrStr,
                             selectionRange: NSRange(location: word.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        client.insertText(word, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        ws?.study(word: word, reading: inputPat)
        resetState()
        hideWindow()
    }

    // MARK: - Fix (commit selection)

    private func fix(client sender: Any? = nil) {
        guard nthCand < candidates.count else {
            resetState()
            return
        }
        let candidate = candidates[nthCand]
        let word = candidate.word

        guard let client = sender as? IMKTextInput else {
            resetState()
            return
        }

        if ImageManager.isImageCandidate(word) {
            if !tmpImageDisplayed {
                Emulation.key("v", modifier: .maskCommand)
            }
            tmpImageDisplayed = false
        } else {
            client.insertText(word, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        }

        // Register/study logic
        if word == selectedStr {
            ws?.register(word: word, reading: inputPat)
            selectedStr = nil
        } else {
            if let reading = candidate.reading {
                if reading != "ds" {
                    ws?.study(word: word, reading: reading)
                }
            } else {
                if inputPat != "ds" {
                    ws?.study(word: word, reading: inputPat)
                }
            }
        }

        resetState()
        hideWindow()
    }

    // MARK: - Window Management

    private func showWindow() {
        guard converting else {
            candWindow?.orderOut(nil)
            return
        }
        guard let cw = candWindow,
              let client = client() as? IMKTextInput else { return }
        var lineRect = NSRect.zero
        client.attributes(forCharacterIndex: 0, lineHeightRectangle: &lineRect)

        let cursorOrigin = lineRect.origin
        let cursorHeight = lineRect.height
        let winHeight = cw.frame.height

        var origin = cursorOrigin
        origin.x -= 5

        // If window would go below screen bottom, show above cursor instead
        if origin.y - winHeight - 5 < 0 {
            origin.y = cursorOrigin.y + cursorHeight + 5
        } else {
            origin.y = cursorOrigin.y - winHeight - 5
        }

        cw.setFrameOrigin(origin)
        cw.orderFront(nil)
        NSApp.unhide(nil)
    }

    private func hideWindow() {
        candWindow?.orderOut(nil)
    }

    // Class method for async candidate updates (e.g., from Google)
    static func showCands(_ newCandidates: [SearchCandidate]) {
        guard let gc = shared else { return }
        gc.candidates = newCandidates
        gc.searchMode = 2
        gc.showCands(client: gc.client())
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
