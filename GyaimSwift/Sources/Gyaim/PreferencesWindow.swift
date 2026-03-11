import Cocoa

/// Preferences window for Gyaim keybinding configuration.
class PreferencesWindow: NSWindow {
    static var shared: PreferencesWindow?

    private var hiraganaRecorders: [ShortcutRecorderRow] = []
    private var katakanaRecorders: [ShortcutRecorderRow] = []
    private let contentBox = NSView()
    private var logSizeLabel: NSTextField?
    private var logToggle: NSButton?
    private var clipboardToggle: NSButton?
    private var selectedTextToggle: NSButton?

    static func show() {
        if shared == nil {
            shared = PreferencesWindow()
        }
        shared?.level = .floating
        shared?.makeKeyAndOrderFront(nil)
        shared?.becomeKey()
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }

    init() {
        let frame = NSRect(x: 0, y: 0, width: 480, height: 400)
        super.init(contentRect: frame,
                   styleMask: [.titled, .closable],
                   backing: .buffered,
                   defer: false)
        title = "Gyaim 設定"
        center()
        isReleasedWhenClosed = false

        contentBox.frame = frame
        contentView = contentBox

        buildUI()
        loadBindings()
    }

    override func close() {
        super.close()
        NSApp.setActivationPolicy(.prohibited)
    }

    override func keyDown(with event: NSEvent) {
        // Cmd+W to close
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "w" {
            close()
            return
        }
        super.keyDown(with: event)
    }

    private func buildUI() {
        var y = frame.height - 60

        // Title
        let titleLabel = makeLabel("キーボードショートカット", bold: true)
        titleLabel.frame = NSRect(x: 20, y: y, width: 440, height: 24)
        contentBox.addSubview(titleLabel)
        y -= 10

        // Hiragana section
        y -= 30
        let hiraLabel = makeLabel("ひらがな確定:")
        hiraLabel.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        contentBox.addSubview(hiraLabel)

        for shortcut in KeyBindings.shared.hiragana {
            y -= 32
            let row = ShortcutRecorderRow(frame: NSRect(x: 30, y: y, width: 420, height: 28))
            row.setShortcut(shortcut)
            row.onRemove = { [weak self] r in self?.removeHiraganaRow(r) }
            contentBox.addSubview(row)
            hiraganaRecorders.append(row)
        }

        y -= 30
        let addHiraBtn = NSButton(title: "+ 追加", target: self, action: #selector(addHiraganaShortcut))
        addHiraBtn.frame = NSRect(x: 30, y: y, width: 80, height: 24)
        addHiraBtn.bezelStyle = .rounded
        addHiraBtn.tag = 1
        contentBox.addSubview(addHiraBtn)

        // Katakana section
        y -= 40
        let kataLabel = makeLabel("カタカナ確定:")
        kataLabel.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        contentBox.addSubview(kataLabel)

        for shortcut in KeyBindings.shared.katakana {
            y -= 32
            let row = ShortcutRecorderRow(frame: NSRect(x: 30, y: y, width: 420, height: 28))
            row.setShortcut(shortcut)
            row.onRemove = { [weak self] r in self?.removeKatakanaRow(r) }
            contentBox.addSubview(row)
            katakanaRecorders.append(row)
        }

        y -= 30
        let addKataBtn = NSButton(title: "+ 追加", target: self, action: #selector(addKatakanaShortcut))
        addKataBtn.frame = NSRect(x: 30, y: y, width: 80, height: 24)
        addKataBtn.bezelStyle = .rounded
        addKataBtn.tag = 2
        contentBox.addSubview(addKataBtn)

        // Candidate section
        y -= 40
        let candTitle = makeLabel("候補", bold: true)
        candTitle.frame = NSRect(x: 20, y: y, width: 440, height: 24)
        contentBox.addSubview(candTitle)

        y -= 28
        let cbToggle = NSButton(checkboxWithTitle: "クリップボードの内容を候補に表示する", target: self, action: #selector(toggleClipboardCandidate(_:)))
        cbToggle.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        cbToggle.state = GyaimController.isClipboardCandidateEnabled ? .on : .off
        contentBox.addSubview(cbToggle)
        clipboardToggle = cbToggle

        y -= 24
        let stToggle = NSButton(checkboxWithTitle: "選択テキストを候補に表示する", target: self, action: #selector(toggleSelectedTextCandidate(_:)))
        stToggle.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        stToggle.state = GyaimController.isSelectedTextCandidateEnabled ? .on : .off
        contentBox.addSubview(stToggle)
        selectedTextToggle = stToggle

        // Log section
        y -= 40
        let logTitle = makeLabel("ログ", bold: true)
        logTitle.frame = NSRect(x: 20, y: y, width: 440, height: 24)
        contentBox.addSubview(logTitle)

        y -= 28
        let toggle = NSButton(checkboxWithTitle: "ロギングを有効にする", target: self, action: #selector(toggleLogging(_:)))
        toggle.frame = NSRect(x: 20, y: y, width: 250, height: 20)
        toggle.state = Log.isEnabled ? .on : .off
        contentBox.addSubview(toggle)
        logToggle = toggle

        y -= 24
        let sizeLabel = makeLabel(logSizeString())
        sizeLabel.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        contentBox.addSubview(sizeLabel)
        logSizeLabel = sizeLabel

        let clearBtn = NSButton(title: "ログを削除", target: self, action: #selector(clearLogs))
        clearBtn.frame = NSRect(x: 230, y: y - 2, width: 100, height: 24)
        clearBtn.bezelStyle = .rounded
        contentBox.addSubview(clearBtn)

        let finderBtn = NSButton(title: "Finderで表示", target: self, action: #selector(showInFinder))
        finderBtn.frame = NSRect(x: 340, y: y - 2, width: 120, height: 24)
        finderBtn.bezelStyle = .rounded
        contentBox.addSubview(finderBtn)

        // Bottom buttons
        let bottomMargin: CGFloat = 56 // 12 + 32 (button) + 12 padding
        resizeToFitContent(lastY: y, bottomMargin: bottomMargin)

        let saveBtn = NSButton(title: "保存", target: self, action: #selector(saveAndClose))
        saveBtn.frame = NSRect(x: 380, y: 12, width: 80, height: 32)
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        contentBox.addSubview(saveBtn)

        let resetBtn = NSButton(title: "初期値に戻す", target: self, action: #selector(resetDefaults))
        resetBtn.frame = NSRect(x: 20, y: 12, width: 120, height: 32)
        resetBtn.bezelStyle = .rounded
        contentBox.addSubview(resetBtn)
    }

    private func loadBindings() {
        for (i, row) in hiraganaRecorders.enumerated() {
            if i < KeyBindings.shared.hiragana.count {
                row.setShortcut(KeyBindings.shared.hiragana[i])
            }
        }
        for (i, row) in katakanaRecorders.enumerated() {
            if i < KeyBindings.shared.katakana.count {
                row.setShortcut(KeyBindings.shared.katakana[i])
            }
        }
    }

    @objc private func addHiraganaShortcut() {
        let row = ShortcutRecorderRow(frame: .zero)
        row.onRemove = { [weak self] r in self?.removeHiraganaRow(r) }
        hiraganaRecorders.append(row)
        contentBox.addSubview(row)
        rebuildLayout()
    }

    @objc private func addKatakanaShortcut() {
        let row = ShortcutRecorderRow(frame: .zero)
        row.onRemove = { [weak self] r in self?.removeKatakanaRow(r) }
        katakanaRecorders.append(row)
        contentBox.addSubview(row)
        rebuildLayout()
    }

    private func removeHiraganaRow(_ row: ShortcutRecorderRow) {
        guard hiraganaRecorders.count > 1 else { return }
        row.removeFromSuperview()
        hiraganaRecorders.removeAll { $0 === row }
        rebuildLayout()
    }

    private func removeKatakanaRow(_ row: ShortcutRecorderRow) {
        guard katakanaRecorders.count > 1 else { return }
        row.removeFromSuperview()
        katakanaRecorders.removeAll { $0 === row }
        rebuildLayout()
    }

    private func rebuildLayout() {
        // Remove all subviews and rebuild
        contentBox.subviews.forEach { $0.removeFromSuperview() }
        hiraganaRecorders.forEach { $0.removeFromSuperview() }
        katakanaRecorders.forEach { $0.removeFromSuperview() }

        var y = frame.height - 60

        let titleLabel = makeLabel("キーボードショートカット", bold: true)
        titleLabel.frame = NSRect(x: 20, y: y, width: 440, height: 24)
        contentBox.addSubview(titleLabel)

        y -= 40
        let hiraLabel = makeLabel("ひらがな確定:")
        hiraLabel.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        contentBox.addSubview(hiraLabel)

        for row in hiraganaRecorders {
            y -= 32
            row.frame = NSRect(x: 30, y: y, width: 420, height: 28)
            contentBox.addSubview(row)
        }

        y -= 30
        let addHiraBtn = NSButton(title: "+ 追加", target: self, action: #selector(addHiraganaShortcut))
        addHiraBtn.frame = NSRect(x: 30, y: y, width: 80, height: 24)
        addHiraBtn.bezelStyle = .rounded
        contentBox.addSubview(addHiraBtn)

        y -= 40
        let kataLabel = makeLabel("カタカナ確定:")
        kataLabel.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        contentBox.addSubview(kataLabel)

        for row in katakanaRecorders {
            y -= 32
            row.frame = NSRect(x: 30, y: y, width: 420, height: 28)
            contentBox.addSubview(row)
        }

        y -= 30
        let addKataBtn = NSButton(title: "+ 追加", target: self, action: #selector(addKatakanaShortcut))
        addKataBtn.frame = NSRect(x: 30, y: y, width: 80, height: 24)
        addKataBtn.bezelStyle = .rounded
        contentBox.addSubview(addKataBtn)

        // Candidate section in rebuildLayout
        y -= 40
        let candTitle = makeLabel("候補", bold: true)
        candTitle.frame = NSRect(x: 20, y: y, width: 440, height: 24)
        contentBox.addSubview(candTitle)

        y -= 28
        let cbToggle = NSButton(checkboxWithTitle: "クリップボードの内容を候補に表示する", target: self, action: #selector(toggleClipboardCandidate(_:)))
        cbToggle.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        cbToggle.state = GyaimController.isClipboardCandidateEnabled ? .on : .off
        contentBox.addSubview(cbToggle)
        clipboardToggle = cbToggle

        y -= 24
        let stToggle = NSButton(checkboxWithTitle: "選択テキストを候補に表示する", target: self, action: #selector(toggleSelectedTextCandidate(_:)))
        stToggle.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        stToggle.state = GyaimController.isSelectedTextCandidateEnabled ? .on : .off
        contentBox.addSubview(stToggle)
        selectedTextToggle = stToggle

        // Log section in rebuildLayout
        y -= 40
        let logTitle = makeLabel("ログ", bold: true)
        logTitle.frame = NSRect(x: 20, y: y, width: 440, height: 24)
        contentBox.addSubview(logTitle)

        y -= 28
        let toggle = NSButton(checkboxWithTitle: "ロギングを有効にする", target: self, action: #selector(toggleLogging(_:)))
        toggle.frame = NSRect(x: 20, y: y, width: 250, height: 20)
        toggle.state = Log.isEnabled ? .on : .off
        contentBox.addSubview(toggle)
        logToggle = toggle

        y -= 24
        let sizeLabel = makeLabel(logSizeString())
        sizeLabel.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        contentBox.addSubview(sizeLabel)
        logSizeLabel = sizeLabel

        let clearBtn = NSButton(title: "ログを削除", target: self, action: #selector(clearLogs))
        clearBtn.frame = NSRect(x: 230, y: y - 2, width: 100, height: 24)
        clearBtn.bezelStyle = .rounded
        contentBox.addSubview(clearBtn)

        let finderBtn = NSButton(title: "Finderで表示", target: self, action: #selector(showInFinder))
        finderBtn.frame = NSRect(x: 340, y: y - 2, width: 120, height: 24)
        finderBtn.bezelStyle = .rounded
        contentBox.addSubview(finderBtn)

        let bottomMargin: CGFloat = 56
        resizeToFitContent(lastY: y, bottomMargin: bottomMargin)

        let saveBtn = NSButton(title: "保存", target: self, action: #selector(saveAndClose))
        saveBtn.frame = NSRect(x: 380, y: 12, width: 80, height: 32)
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        contentBox.addSubview(saveBtn)

        let resetBtn = NSButton(title: "初期値に戻す", target: self, action: #selector(resetDefaults))
        resetBtn.frame = NSRect(x: 20, y: 12, width: 120, height: 32)
        resetBtn.bezelStyle = .rounded
        contentBox.addSubview(resetBtn)
    }

    @objc private func saveAndClose() {
        KeyBindings.shared.hiragana = hiraganaRecorders.compactMap { $0.shortcut }
        KeyBindings.shared.katakana = katakanaRecorders.compactMap { $0.shortcut }
        KeyBindings.shared.save()
        close()
    }

    @objc private func resetDefaults() {
        KeyBindings.shared.reset()
        hiraganaRecorders.forEach { $0.removeFromSuperview() }
        katakanaRecorders.forEach { $0.removeFromSuperview() }
        hiraganaRecorders = []
        katakanaRecorders = []

        for shortcut in KeyBindings.shared.hiragana {
            let row = ShortcutRecorderRow(frame: .zero)
            row.setShortcut(shortcut)
            row.onRemove = { [weak self] r in self?.removeHiraganaRow(r) }
            hiraganaRecorders.append(row)
        }
        for shortcut in KeyBindings.shared.katakana {
            let row = ShortcutRecorderRow(frame: .zero)
            row.setShortcut(shortcut)
            row.onRemove = { [weak self] r in self?.removeKatakanaRow(r) }
            katakanaRecorders.append(row)
        }
        rebuildLayout()
    }

    @objc private func toggleClipboardCandidate(_ sender: NSButton) {
        GyaimController.setClipboardCandidateEnabled(sender.state == .on)
    }

    @objc private func toggleSelectedTextCandidate(_ sender: NSButton) {
        GyaimController.setSelectedTextCandidateEnabled(sender.state == .on)
    }

    @objc private func toggleLogging(_ sender: NSButton) {
        let enabled = sender.state == .on
        Log.setEnabled(enabled)
        logSizeLabel?.stringValue = logSizeString()
    }

    @objc private func clearLogs() {
        FileLogger.shared.clearLog()
        // Small delay to let the async queue finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.logSizeLabel?.stringValue = self?.logSizeString() ?? "0 B"
        }
    }

    @objc private func showInFinder() {
        let logPath = "\(Config.gyaimDir)/gyaim.log"
        let fm = FileManager.default
        if fm.fileExists(atPath: logPath) {
            NSWorkspace.shared.selectFile(logPath, inFileViewerRootedAtPath: "")
        } else {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: Config.gyaimDir)
        }
    }

    private func logSizeString() -> String {
        let size = FileLogger.shared.logFileSize()
        if size == 0 { return "gyaim.log: 0 B" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "gyaim.log: \(formatter.string(fromByteCount: size))"
    }

    /// Resize window so that all content fits. `lastY` is the Y coordinate of
    /// the lowest content element (before bottom buttons). `bottomMargin` is the
    /// space reserved for the save/reset buttons at the bottom.
    private func resizeToFitContent(lastY: CGFloat, bottomMargin: CGFloat) {
        // Content is laid out top-down from frame.height - 50.
        // The required height = (frame.height - lastY) + bottomMargin + topPadding
        let topPadding: CGFloat = 60
        let contentHeight = (frame.height - lastY) + bottomMargin + topPadding
        let requiredHeight = max(contentHeight, 300) // minimum height

        // Calculate the offset to shift all existing subviews down
        let delta = requiredHeight - frame.height
        if abs(delta) > 1 {
            // Move all existing subviews by delta (they were placed relative to old frame.height)
            for subview in contentBox.subviews {
                subview.frame.origin.y += delta
            }
            // Resize the window, keeping the top-left corner stable
            let oldFrame = self.frame
            let newFrame = NSRect(
                x: oldFrame.origin.x,
                y: oldFrame.origin.y - delta,
                width: oldFrame.width,
                height: requiredHeight
            )
            setFrame(newFrame, display: true)
            contentBox.frame = NSRect(x: 0, y: 0, width: newFrame.width, height: newFrame.height)
        }
    }

    private func makeLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        if bold {
            label.font = NSFont.boldSystemFont(ofSize: 14)
        }
        return label
    }
}

/// A single row: [shortcut display] [Record button] [Remove button]
class ShortcutRecorderRow: NSView {
    var shortcut: KeyShortcut?
    var onRemove: ((ShortcutRecorderRow) -> Void)?

    private let displayField = NSTextField()
    private let recordBtn = NSButton()
    private let removeBtn = NSButton()
    private var isRecording = false
    private var eventMonitor: Any?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        displayField.isEditable = false
        displayField.isBezeled = true
        displayField.bezelStyle = .roundedBezel
        displayField.stringValue = "未設定"
        displayField.alignment = .center
        addSubview(displayField)

        recordBtn.title = "記録"
        recordBtn.bezelStyle = .rounded
        recordBtn.target = self
        recordBtn.action = #selector(toggleRecording)
        addSubview(recordBtn)

        removeBtn.title = "×"
        removeBtn.bezelStyle = .rounded
        removeBtn.target = self
        removeBtn.action = #selector(removeSelf)
        addSubview(removeBtn)
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        displayField.frame = NSRect(x: 0, y: 0, width: w - 150, height: h)
        recordBtn.frame = NSRect(x: w - 140, y: 0, width: 80, height: h)
        removeBtn.frame = NSRect(x: w - 50, y: 0, width: 40, height: h)
    }

    func setShortcut(_ s: KeyShortcut) {
        shortcut = s
        displayField.stringValue = s.displayString
    }

    @objc private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        recordBtn.title = "入力待ち..."
        displayField.stringValue = "キーを押してください"
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        recordBtn.title = "記録"
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let s = KeyShortcut.from(event: event)
        setShortcut(s)
        stopRecording()
    }

    @objc private func removeSelf() {
        onRemove?(self)
    }
}
