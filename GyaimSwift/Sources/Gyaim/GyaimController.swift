import Cocoa
import InputMethodKit

/// Polls NSPasteboard.changeCount to record the actual copy timestamp.
/// Uses both a RunLoop timer (for main thread) and a GCD timer (for background)
/// to ensure at least one fires in the IME process environment.
final class ClipboardMonitor {
    private let lock = NSLock()
    private var _changeCount: Int
    private var _lastChangeDate: Date = .distantPast
    private var gcdTimer: DispatchSourceTimer?
    private var runLoopTimer: Timer?

    var changeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _changeCount
    }

    var lastChangeDate: Date {
        lock.lock()
        defer { lock.unlock() }
        return _lastChangeDate
    }

    init() {
        _changeCount = NSPasteboard.general.changeCount
        startPolling()
    }

    private func startPolling() {
        // GCD timer (works even without a RunLoop)
        let source = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        source.schedule(deadline: .now() + 0.5, repeating: 0.5)
        source.setEventHandler { [weak self] in self?.poll() }
        source.resume()
        gcdTimer = source

        // RunLoop timer (works on main thread in IME process)
        DispatchQueue.main.async { [weak self] in
            let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.poll()
            }
            RunLoop.main.add(timer, forMode: .common)
            self?.runLoopTimer = timer
        }
    }

    private func poll() {
        let current = NSPasteboard.general.changeCount
        lock.lock()
        if current != _changeCount {
            _changeCount = current
            _lastChangeDate = Date()
            lock.unlock()
            Log.input.debug("ClipboardMonitor: changeCount → \(current)")
        } else {
            lock.unlock()
        }
    }

    deinit {
        gcdTimer?.cancel()
        runLoopTimer?.invalidate()
    }
}

/// Central IME controller implementing InputMethodKit protocol.
/// Ported from GyaimController.rb (Toshiyuki Masui, 2011-2015)
@objc(GyaimController)
class GyaimController: IMKInputController {
    private static var shared: GyaimController?

    private var inputPat = ""
    private var candidates: [SearchCandidate] = []
    private var nthCand = 0
    private var searchMode = 0
    private var tmpImageDisplayed = false
    private var bsThrough = false
    /// Clipboard text captured at input start.
    private var clipboardCandidate: String?
    /// Selected text captured at the moment of first keystroke.
    private var selectedCandidate: String?
    /// Monitors NSPasteboard.changeCount to record the actual copy time.
    private static let clipboardMonitor = ClipboardMonitor()
    /// The changeCount that was last consumed (shown as candidate to user).
    private static var lastConsumedCC: Int = NSPasteboard.general.changeCount

    private var ws: WordSearch?
    private var rk = RomaKana()
    private var candWindow: CandidateWindow?
    /// Tracks the in-flight Google Transliterate query to discard stale results.
    private var pendingGoogleQuery: String?

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
            } else {
                Log.input.error("dict.txt not found in bundle")
            }
        }
        Log.input.info("GyaimController initialized")

        if let client = inputClient as? (IMKTextInput & NSObjectProtocol) {
            CopyText.set(NSPasteboard.general.string(forType: .string))
        }

        resetState()
        GyaimController.shared = self
    }

    override func activateServer(_ sender: Any!) {
        Log.input.info("IME activated (pasteboardCC=\(NSPasteboard.general.changeCount), lastConsumedCC=\(GyaimController.lastConsumedCC))")
        CopyText.set(NSPasteboard.general.string(forType: .string))
        ws?.start()
        showWindow()
    }

    override func deactivateServer(_ sender: Any!) {
        Log.input.info("IME deactivated")
        hideWindow()
        fix()
        ws?.finish()
    }

    private func resetState() {
        inputPat = ""
        candidates = []
        nthCand = 0
        searchMode = 0
        clipboardCandidate = nil
        selectedCandidate = nil
        pendingGoogleQuery = nil
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
        Log.input.debug("keyDown: keyCode=\(keyCode), chars=\(event.characters ?? ""), mods=\(modifierFlags.rawValue)")


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

        // Google Transliterate shortcut (e.g. Ctrl+G)
        if converting, KeyBindings.shared.matchesGoogleTransliterate(event: event) {
            triggerGoogleTransliterate(client: sender)
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
            // Capture selected text and clipboard only on the first keystroke of a new input
            if inputPat.isEmpty {
                captureExternalCandidates(client: sender)
            }
            inputPat += eventString
            searchAndShowCands(client: sender)
            searchMode = 0
            handled = true
        }

        showWindow()
        return handled
    }

    // MARK: - Event Routing (Testable)

    /// Describes the outcome of event routing without side effects.
    struct HandleResult: Equatable {
        var handled: Bool
        var action: HandleAction

        enum HandleAction: Equatable {
            case none
            case searchAndShow
            case showCands
            case fix
            case fixThenSearchAndShow
            case fixAsKana(hiragana: Bool)
            case backspaceInputPat
            case decrementNthCand
            case incrementNthCand
            case setSearchModeAndSearch
            case numberKeySelect(Int)
            case jisModKey
            case emulateDelete
            case resetTmpImage
            case undoAndSpace
            case undoThenInsertChar
            case googleTransliterate
        }
    }

    /// Pure routing logic extracted from handle(_:client:) for unit testing.
    /// All branching decisions are encoded in the returned HandleResult.
    static func routeEvent(
        character: UInt8,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        converting: Bool,
        nthCand: Int,
        candidateCount: Int,
        searchMode: Int,
        tmpImageDisplayed: Bool,
        bsThrough: Bool,
        hiraganaChar: UInt8,
        katakanaChar: UInt8,
        matchesHiraganaShortcut: Bool,
        matchesKatakanaShortcut: Bool,
        matchesGoogleTransliterateShortcut: Bool = false,
        inputPatEmpty: Bool,
        hasEventString: Bool
    ) -> HandleResult {
        let kVirtualJISRomanModeKey: UInt16 = 102
        let kVirtualJISKanaModeKey: UInt16 = 104

        // JIS kana/roman mode keys
        if keyCode == kVirtualJISKanaModeKey || keyCode == kVirtualJISRomanModeKey {
            return HandleResult(handled: true, action: .jisModKey)
        }

        // Configurable shortcuts: hiragana / katakana confirm (modifier keys)
        if converting, matchesHiraganaShortcut {
            return HandleResult(handled: true, action: .fixAsKana(hiragana: true))
        }
        if converting, matchesKatakanaShortcut {
            return HandleResult(handled: true, action: .fixAsKana(hiragana: false))
        }

        // Google Transliterate shortcut (e.g. Ctrl+G)
        if converting, matchesGoogleTransliterateShortcut {
            return HandleResult(handled: true, action: .googleTransliterate)
        }

        // No event string → handled (consumed, no action)
        guard hasEventString else {
            return HandleResult(handled: true, action: .none)
        }

        let c = character

        // Single-key kana confirm: ; → hiragana, q → katakana (configurable)
        if converting, modifierFlags.intersection([.control, .command, .option]).isEmpty {
            if c == hiraganaChar {
                return HandleResult(handled: true, action: .fixAsKana(hiragana: true))
            }
            if c == katakanaChar {
                return HandleResult(handled: true, action: .fixAsKana(hiragana: false))
            }
        }

        // Backspace / Escape
        if c == 0x08 || c == 0x7f || c == 0x1b {
            if converting, tmpImageDisplayed, !bsThrough {
                return HandleResult(handled: true, action: .emulateDelete)
            }
            if !bsThrough, converting {
                if nthCand > 0 {
                    return HandleResult(handled: true, action: .decrementNthCand)
                } else {
                    return HandleResult(handled: true, action: .backspaceInputPat)
                }
            }
            return HandleResult(handled: false, action: .none)
        }

        // Space
        if c == 0x20 {
            if converting {
                if tmpImageDisplayed {
                    return HandleResult(handled: true, action: .undoAndSpace)
                }
                if nthCand < candidateCount - 1 {
                    return HandleResult(handled: true, action: .incrementNthCand)
                }
                return HandleResult(handled: true, action: .none)
            }
            return HandleResult(handled: false, action: .none)
        }

        // Enter
        if c == 0x0a || c == 0x0d {
            if converting {
                if tmpImageDisplayed {
                    return HandleResult(handled: true, action: .resetTmpImage)
                }
                if searchMode > 0 {
                    return HandleResult(handled: true, action: .fix)
                } else {
                    if nthCand == 0 {
                        return HandleResult(handled: true, action: .setSearchModeAndSearch)
                    } else {
                        return HandleResult(handled: true, action: .fix)
                    }
                }
            }
            return HandleResult(handled: false, action: .none)
        }

        // Number keys 1-9: select candidate from list (only when list is visible)
        if converting, nthCand > 0 || searchMode > 0,
           c >= 0x31, c <= 0x39,
           modifierFlags.intersection([.control, .command, .option]).isEmpty {
            let num = Int(c - 0x30)
            let targetIndex = nthCand + num
            if targetIndex < candidateCount {
                return HandleResult(handled: true, action: .numberKeySelect(targetIndex))
            }
            return HandleResult(handled: true, action: .none)
        }

        // Printable character (0x21-0x7e), no Control/Command/Option
        if c >= 0x21, c <= 0x7e,
           modifierFlags.intersection([.control, .command, .option]).isEmpty {
            if nthCand > 0 || searchMode > 0 {
                return HandleResult(handled: true, action: .fixThenSearchAndShow)
            }
            return HandleResult(handled: true, action: .searchAndShow)
        }

        return HandleResult(handled: false, action: .none)
    }

    // MARK: - External Candidate Capture

    /// Capture selected text and clipboard at input start.
    /// Called once when the first printable character is typed.
    static var isClipboardCandidateEnabled: Bool {
        // Default true — UserDefaults returns false for unset booleans,
        // so we use object(forKey:) to detect "never set" and default to true.
        UserDefaults.standard.object(forKey: "clipboardCandidateEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "clipboardCandidateEnabled")
    }
    static func setClipboardCandidateEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "clipboardCandidateEnabled")
    }

    static var isSelectedTextCandidateEnabled: Bool {
        UserDefaults.standard.object(forKey: "selectedTextCandidateEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "selectedTextCandidateEnabled")
    }
    static func setSelectedTextCandidateEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "selectedTextCandidateEnabled")
    }

    private func captureExternalCandidates(client sender: Any?) {
        // Capture selected text from the active application
        if GyaimController.isSelectedTextCandidateEnabled {
            if let client = sender as? IMKTextInput {
                let range = client.selectedRange()
                if range.length > 0 {
                    if let attrStr = client.attributedSubstring(from: range) {
                        let s = attrStr.string
                        if !s.isEmpty {
                            selectedCandidate = s
                            Log.input.info("Captured selected text: \"\(s)\"")
                        }
                    }
                }
            }
        }

        // Clipboard candidate logic:
        // - ClipboardMonitor polls changeCount every 0.5s to record WHEN the copy happened
        // - We compare current changeCount against lastConsumedCC (static, survives instance recreation)
        // - Only show if: new copy detected AND copy happened within 5 seconds
        guard GyaimController.isClipboardCandidateEnabled else { return }

        let currentCC = NSPasteboard.general.changeCount
        let monitor = GyaimController.clipboardMonitor

        // If the monitor hasn't caught up yet (copy happened between polls),
        // the copy is very recent — treat elapsed as 0.
        let monitorCC = monitor.changeCount
        let elapsed: TimeInterval
        if currentCC == monitorCC {
            elapsed = Date().timeIntervalSince(monitor.lastChangeDate)
        } else {
            elapsed = 0
        }

        if currentCC != GyaimController.lastConsumedCC {
            GyaimController.lastConsumedCC = currentCC

            if elapsed < 5.0 {
                if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
                    clipboardCandidate = text
                    Log.input.info("Captured clipboard (elapsed: \(String(format: "%.1f", elapsed))s): \"\(text.prefix(50))\"")
                }
            }
        }
    }

    /// Check if a string is a valid external candidate (not a Gyazo hash, not a URL).
    static func isValidExternalCandidate(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }
        if ImageManager.isImageCandidate(trimmed) { return false }
        if trimmed.hasPrefix("http") { return false }
        return true
    }

    /// Build prefix-mode candidate list with external candidates injected.
    /// Extracted for testability.
    static func buildPrefixCandidates(
        searchResults: [SearchCandidate],
        inputPat: String,
        clipboardCandidate: String?,
        selectedCandidate: String?,
        hiragana: String
    ) -> [SearchCandidate] {
        var candidates = searchResults

        // Prepend selected text if available
        if let sel = selectedCandidate, isValidExternalCandidate(sel) {
            candidates.insert(SearchCandidate(word: sel), at: 0)
        }

        // Prepend clipboard text if available
        if let clip = clipboardCandidate, isValidExternalCandidate(clip) {
            candidates.insert(SearchCandidate(word: clip), at: 0)
        }

        // Input pattern itself as first candidate
        candidates.insert(SearchCandidate(word: inputPat), at: 0)

        // Add hiragana if few candidates
        if candidates.count < 8, !hiragana.isEmpty {
            candidates.append(SearchCandidate(word: hiragana))
        }

        // Deduplicate preserving order
        var seen: Set<String> = []
        candidates = candidates.filter { c in
            if seen.contains(c.word) { return false }
            seen.insert(c.word)
            return true
        }

        return candidates
    }

    // MARK: - Search & Display

    /// Trigger Google Transliterate for the current inputPat.
    /// Called by either suffix trigger (e.g. "meguro`") or shortcut (e.g. Ctrl+G).
    private func triggerGoogleTransliterate(query: String? = nil, client sender: Any? = nil) {
        let q = query ?? inputPat
        guard !q.isEmpty else { return }

        pendingGoogleQuery = q
        Log.input.info("Google Transliterate triggered: \"\(q)\"")

        // Show query as marked text while waiting
        candidates = GoogleTransliterate.buildGoogleCandidates(apiResults: [], query: q)
        nthCand = 0
        showCands(client: sender ?? self.client())

        GoogleTransliterate.searchCands(q) { [weak self] results in
            guard let self else { return }
            // Stale guard: discard if inputPat has changed
            guard self.pendingGoogleQuery == q else {
                Log.input.debug("Google Transliterate stale result discarded for \"\(q)\"")
                return
            }
            self.pendingGoogleQuery = nil

            let googleCandidates = GoogleTransliterate.buildGoogleCandidates(
                apiResults: results, query: q)
            Log.input.info("Google Transliterate results for \"\(q)\": \(results)")
            GyaimController.showCands(googleCandidates)
        }
    }

    private func searchAndShowCands(client sender: Any?) {
        guard let ws else { return }

        // Google Transliterate: suffix trigger (e.g. "meguro`")
        if GoogleTransliterate.hasTriggerSuffix(inputPat) {
            let query = GoogleTransliterate.stripTriggerSuffix(inputPat)
            triggerGoogleTransliterate(query: query, client: sender)
            return
        }

        if searchMode == 1 {
            candidates = PerfLog.measure("search(\(inputPat), exact)", logger: Log.input) {
                ws.search(query: inputPat, searchMode: searchMode)
            }
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
            let searchResults = PerfLog.measure("search(\(inputPat), prefix)", logger: Log.input) {
                ws.search(query: inputPat, searchMode: searchMode)
            }
            let hiragana = rk.roma2hiragana(inputPat)
            candidates = Self.buildPrefixCandidates(
                searchResults: searchResults,
                inputPat: inputPat,
                clipboardCandidate: clipboardCandidate,
                selectedCandidate: selectedCandidate,
                hiragana: hiragana
            )
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

        // Update candidate list (count depends on display mode)
        let maxCandList = CandidateDisplayMode.current.maxVisible
        var candList: [String] = []
        for i in 0..<maxCandList {
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
        let kanaType = hiragana ? "hiragana" : "katakana"
        Log.input.info("Fixed as kana(\(kanaType)): \"\(word)\" (input: \"\(inputPat)\", candidates: \(candidates.count))")

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
        let reading = candidate.reading ?? inputPat
        let candidateWords = candidates.map(\.word)
        Log.input.info("Fixed: \"\(word)\" (reading: \"\(reading)\", index: \(nthCand)/\(candidates.count), candidates: \(candidateWords))")

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

        // Register or study logic
        let isExternalCandidate = (word == clipboardCandidate || word == selectedCandidate)
        if isExternalCandidate {
            // External candidate (clipboard/selected text) → register to user dict
            ws?.register(word: word, reading: inputPat)
            Log.input.info("Registered to user dict: \"\(word)\" (reading: \"\(inputPat)\")")
        } else if let reading = candidate.reading {
            if reading != "ds" {
                ws?.study(word: word, reading: reading)
            }
        } else {
            if inputPat != "ds" {
                ws?.study(word: word, reading: inputPat)
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

        let winSize = cw.frame.size
        let mode = CandidateDisplayMode.current
        let screenFrame = NSScreen.main?.frame ?? .zero

        let origin = CandidateWindowPositioner.calculate(
            lineRect: lineRect,
            winSize: winSize,
            screenFrame: screenFrame,
            mode: mode)

        Log.ui.info("showWindow: lineRect=\(lineRect) winSize=\(winSize) mode=\(mode == .classic ? "classic" : "list") -> origin=\(origin)")
        cw.setFrameOrigin(origin)
        cw.orderFront(nil)
    }

    private func hideWindow() {
        candWindow?.orderOut(nil)
    }

    /// Class method for async candidate updates (e.g., from Google Transliterate).
    /// Sets searchMode = 2 to indicate "Google results displayed".
    /// searchMode values: 0 = prefix, 1 = exact, 2 = Google Transliterate results.
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
