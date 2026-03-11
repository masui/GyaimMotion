import Cocoa

/// Vertical candidate display window — non-activating panel that never steals focus.
class CandidateWindow: NSPanel {
    static var shared: CandidateWindow?

    private let stackView = NSStackView()
    private let containerView = NSView()
    private var candidateLabels: [NSTextField] = []
    private var initialLocation: NSPoint = .zero

    private let maxVisible = 9
    private let rowHeight: CGFloat = 22
    private let padding: CGFloat = 6
    private let windowWidth: CGFloat = 260

    init() {
        let frame = NSRect(x: 0, y: 0, width: 260, height: 30)

        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        becomesKeyOnlyIfNeeded = true

        backgroundColor = .clear
        level = .statusBar
        alphaValue = 1.0
        isOpaque = false
        hasShadow = true
        canHide = true
        hidesOnDeactivate = false

        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor(white: 0.95, alpha: 0.95).cgColor
        containerView.layer?.cornerRadius = 6
        containerView.layer?.borderColor = NSColor(white: 0.8, alpha: 1.0).cgColor
        containerView.layer?.borderWidth = 0.5
        contentView = containerView

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 1
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding),
        ])

        CandidateWindow.shared = self
    }

    /// Update the candidate list. `selected` is the currently highlighted index within `words`.
    func updateCandidates(_ words: [String], selectedIndex: Int) {
        // Remove old labels
        candidateLabels.forEach { $0.removeFromSuperview() }
        candidateLabels.removeAll()

        guard !words.isEmpty else {
            setContentSize(NSSize(width: windowWidth, height: 30))
            return
        }

        let count = min(words.count, maxVisible)
        for i in 0..<count {
            let label = makeLabel(index: i, word: words[i], isSelected: i == selectedIndex)
            stackView.addArrangedSubview(label)
            candidateLabels.append(label)
        }

        let totalHeight = padding * 2 + CGFloat(count) * rowHeight + CGFloat(max(0, count - 1)) * stackView.spacing
        setContentSize(NSSize(width: windowWidth, height: totalHeight))
    }

    private func makeLabel(index: Int, word: String, isSelected: Bool) -> NSTextField {
        let prefix = index < 9 ? "\(index + 1). " : "   "
        let label = NSTextField(labelWithString: "\(prefix)\(word)")
        label.font = NSFont.systemFont(ofSize: 14)
        label.textColor = isSelected ? .white : .controlTextColor
        label.drawsBackground = isSelected
        label.backgroundColor = isSelected ? .controlAccentColor : .clear
        label.isBezeled = false
        label.isEditable = false
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.heightAnchor.constraint(equalToConstant: rowHeight),
            label.widthAnchor.constraint(equalToConstant: windowWidth - padding * 2),
        ])
        if isSelected {
            label.wantsLayer = true
            label.layer?.cornerRadius = 3
        }
        return label
    }

    // MARK: - Dragging

    override func mouseDown(with event: NSEvent) {
        let windowFrame = frame
        initialLocation = convertPoint(toScreen: event.locationInWindow)
        initialLocation.x -= windowFrame.origin.x
        initialLocation.y -= windowFrame.origin.y
    }

    override func mouseDragged(with event: NSEvent) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let windowFrame = frame

        let currentLocation = convertPoint(toScreen: event.locationInWindow)
        var newOrigin = NSPoint(x: currentLocation.x - initialLocation.x,
                                y: currentLocation.y - initialLocation.y)

        if newOrigin.y + windowFrame.height > screenFrame.origin.y + screenFrame.height {
            newOrigin.y = screenFrame.origin.y + screenFrame.height - windowFrame.height
        }

        setFrameOrigin(newOrigin)
    }
}
