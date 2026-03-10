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
    private var textView: NSTextView?

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)

        if candWindow == nil {
            candWindow = CandidateWindow()
            textView = candWindow?.candTextView
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

        // F6: confirm as hiragana, F7: confirm as katakana
        let kVKF6: UInt16 = 97
        let kVKF7: UInt16 = 98
        if converting, keyCode == kVKF6 {
            fixAsKana(hiragana: true, client: sender)
            showWindow()
            return true
        }
        if converting, keyCode == kVKF7 {
            fixAsKana(hiragana: false, client: sender)
            showWindow()
            return true
        }

        guard let eventString = event.characters, !eventString.isEmpty else { return true }

        guard let c = eventString.utf8.first else { return true }
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

            // Prepend recent clipboard
            let copytext = CopyText.get()
            if !copytext.isEmpty,
               Date().timeIntervalSince(CopyText.time) < 5,
               copytext.range(of: "^[0-9a-f]{32}$", options: [.regularExpression, .caseInsensitive]) == nil,
               !copytext.hasPrefix("http") {
                candidates.insert(SearchCandidate(word: copytext), at: 0)
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

        // Update candidate list in text view
        if let tv = textView {
            var candList: [String] = []
            for i in 0...10 {
                let idx = nthCand + 1 + i
                guard idx < words.count, let cand = words[safe: idx] else { break }
                candList.append(cand)
            }
            let displayText = candList.joined(separator: " ")
            tv.textStorage?.setAttributedString(
                NSAttributedString(string: displayText,
                                   attributes: [.font: NSFont.systemFont(ofSize: 14),
                                                .foregroundColor: NSColor.black]))
        }
    }

    // MARK: - Fix as Kana (F6/F7)

    private func fixAsKana(hiragana: Bool, client sender: Any?) {
        guard converting else { return }
        let word = hiragana ? rk.roma2hiragana(inputPat) : rk.roma2katakana(inputPat)
        guard !word.isEmpty, let client = sender as? IMKTextInput else {
            resetState()
            return
        }
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
            if inputPat.hasSuffix("?") {
                let pat = String(inputPat.dropLast())
                if let encrypted = Crypt.encrypt(word, salt: pat) {
                    ws?.register(word: encrypted, reading: "?")
                }
            } else {
                ws?.register(word: word, reading: inputPat)
            }
            selectedStr = nil
        } else {
            if let reading = candidate.reading {
                if reading != "ds", reading != "?" {
                    ws?.study(word: word, reading: reading)
                }
            } else {
                if inputPat != "ds", inputPat != "?" {
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
            hideWindow()
            return
        }
        guard let client = client() as? IMKTextInput else { return }
        var lineRect = NSRect.zero
        client.attributes(forCharacterIndex: 0, lineHeightRectangle: &lineRect)
        var origin = lineRect.origin
        origin.x -= 15
        origin.y -= 125
        candWindow?.setFrameOrigin(origin)
        candWindow?.orderFront(nil)
        NSApp.unhide(nil)
    }

    private func hideWindow() {
        candWindow?.orderOut(nil)
        NSApp.hide(nil)
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
