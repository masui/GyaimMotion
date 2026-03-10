import Cocoa

/// User dictionary editor window for ~/.gyaim/localdict.txt
class DictEditorWindow: NSWindow, NSTableViewDataSource, NSTableViewDelegate {
    static var shared: DictEditorWindow?

    private var entries: [(reading: String, word: String)] = []
    private let tableView = NSTableView()
    private let readingColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("reading"))
    private let wordColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("word"))

    static func show() {
        if shared == nil {
            shared = DictEditorWindow()
        }
        shared?.loadEntries()
        shared?.level = .floating
        shared?.makeKeyAndOrderFront(nil)
        shared?.becomeKey()
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }

    init() {
        let frame = NSRect(x: 0, y: 0, width: 500, height: 450)
        super.init(contentRect: frame,
                   styleMask: [.titled, .closable, .resizable],
                   backing: .buffered,
                   defer: false)
        title = "Gyaim ユーザー辞書"
        center()
        isReleasedWhenClosed = false
        minSize = NSSize(width: 400, height: 300)

        let container = NSView(frame: frame)
        contentView = container

        // Table setup
        readingColumn.title = "読み"
        readingColumn.width = 180
        readingColumn.isEditable = true
        wordColumn.title = "単語"
        wordColumn.width = 280
        wordColumn.isEditable = true

        tableView.addTableColumn(readingColumn)
        tableView.addTableColumn(wordColumn)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.headerView = NSTableHeaderView()

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        // Buttons
        let addBtn = NSButton(title: "追加", target: self, action: #selector(addEntry))
        addBtn.bezelStyle = .rounded
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(addBtn)

        let deleteBtn = NSButton(title: "削除", target: self, action: #selector(deleteEntry))
        deleteBtn.bezelStyle = .rounded
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(deleteBtn)

        let saveBtn = NSButton(title: "保存", target: self, action: #selector(saveEntries))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(saveBtn)

        let reloadBtn = NSButton(title: "再読込", target: self, action: #selector(reloadEntries))
        reloadBtn.bezelStyle = .rounded
        reloadBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(reloadBtn)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: addBtn.topAnchor, constant: -10),

            addBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            addBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            addBtn.widthAnchor.constraint(equalToConstant: 60),

            deleteBtn.leadingAnchor.constraint(equalTo: addBtn.trailingAnchor, constant: 8),
            deleteBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            deleteBtn.widthAnchor.constraint(equalToConstant: 60),

            reloadBtn.leadingAnchor.constraint(equalTo: deleteBtn.trailingAnchor, constant: 8),
            reloadBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            reloadBtn.widthAnchor.constraint(equalToConstant: 70),

            saveBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            saveBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            saveBtn.widthAnchor.constraint(equalToConstant: 60),
        ])

        loadEntries()
    }

    override func close() {
        super.close()
        NSApp.setActivationPolicy(.prohibited)
    }

    // MARK: - Data

    private func loadEntries() {
        entries = []
        let dict = WordSearch.loadDict(dictFile: Config.localDictFile)
        for entry in dict {
            if entry.count >= 2 {
                entries.append((reading: entry[0], word: entry[1]))
            }
        }
        tableView.reloadData()
    }

    @objc private func saveEntries() {
        // Commit any in-progress cell editing
        makeFirstResponder(nil)
        var dict: [[String]] = []
        for e in entries {
            let r = e.reading.trimmingCharacters(in: .whitespaces)
            let w = e.word.trimmingCharacters(in: .whitespaces)
            if !r.isEmpty, !w.isEmpty {
                dict.append([r, w])
            }
        }
        WordSearch.saveDict(dictFile: Config.localDictFile, dict: dict)

        // Flash title to confirm save
        let orig = title
        title = "保存しました ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.title = orig
        }
    }

    @objc private func addEntry() {
        entries.insert((reading: "", word: ""), at: 0)
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        tableView.editColumn(0, row: 0, with: nil, select: true)
    }

    @objc private func deleteEntry() {
        let selected = tableView.selectedRowIndexes
        guard !selected.isEmpty else { return }
        entries = entries.enumerated().filter { !selected.contains($0.offset) }.map(\.element)
        tableView.reloadData()
    }

    @objc private func reloadEntries() {
        loadEntries()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < entries.count else { return nil }
        if tableColumn?.identifier.rawValue == "reading" {
            return entries[row].reading
        } else {
            return entries[row].word
        }
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard row < entries.count, let value = object as? String else { return }
        if tableColumn?.identifier.rawValue == "reading" {
            entries[row].reading = value
        } else {
            entries[row].word = value
        }
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        24
    }
}
