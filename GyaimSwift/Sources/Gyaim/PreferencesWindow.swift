import Cocoa

/// Preferences window for Gyaim keybinding configuration.
class PreferencesWindow: NSWindow {
    static var shared: PreferencesWindow?

    private var hiraganaRecorders: [ShortcutRecorderRow] = []
    private var katakanaRecorders: [ShortcutRecorderRow] = []
    private let contentBox = NSView()

    static func show() {
        if shared == nil {
            shared = PreferencesWindow()
        }
        shared?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    init() {
        let frame = NSRect(x: 0, y: 0, width: 480, height: 360)
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

    private func buildUI() {
        var y = frame.height - 50

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

        // Bottom buttons
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

        var y = frame.height - 50

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
