import Cocoa

/// Display mode for the candidate window.
enum CandidateDisplayMode: Int {
    case list = 0     // 現行の縦リスト (Google IME風)
    case classic = 1  // オリジナルGyaim風横並び (candwin.png背景)

    /// Current display mode from UserDefaults (default: .list).
    static var current: CandidateDisplayMode {
        let raw = UserDefaults.standard.object(forKey: "candidateDisplayMode") as? Int ?? 0
        return CandidateDisplayMode(rawValue: raw) ?? .list
    }

    /// Persist the display mode to UserDefaults.
    static func setCurrent(_ mode: CandidateDisplayMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: "candidateDisplayMode")
    }

    /// Maximum number of visible candidates for this mode.
    var maxVisible: Int {
        switch self {
        case .list: return 9
        case .classic: return 11
        }
    }
}

/// Candidate display window — non-activating panel that never steals focus.
/// Supports two display modes: vertical list (default) and classic horizontal.
class CandidateWindow: NSPanel {
    static var shared: CandidateWindow?

    // MARK: - List mode views
    private let stackView = NSStackView()
    private let containerView = NSView()
    private var candidateLabels: [NSTextField] = []

    // MARK: - Classic mode views
    private var classicImageView: NSImageView?
    private var classicTextField: NSTextField?

    // MARK: - Constraint groups (toggled per mode)
    private var listConstraints: [NSLayoutConstraint] = []
    private var classicConstraints: [NSLayoutConstraint] = []

    private var initialLocation: NSPoint = .zero

    private let rowHeight: CGFloat = 22
    private let padding: CGFloat = 6
    private let windowWidth: CGFloat = 260
    private let classicBubbleWidth: CGFloat = 300
    private let classicMinHeight: CGFloat = 90

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
        contentView = containerView

        setupListMode()
        setupClassicMode()
        applyDisplayMode()

        CandidateWindow.shared = self
    }

    // MARK: - Mode Setup

    private func setupListMode() {
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 1
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)

        listConstraints = [
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding),
        ]
    }

    private func setupClassicMode() {
        // Background bubble image — fills entire container
        let imageView = NSImageView()
        imageView.imageScaling = .scaleAxesIndependently
        imageView.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(named: "candwin") {
            imageView.image = img
        } else if let url = Bundle.main.url(forResource: "candwin", withExtension: "png"),
                  let img = NSImage(contentsOf: url) {
            imageView.image = img
        }
        imageView.isHidden = true
        containerView.addSubview(imageView)
        classicImageView = imageView

        // Wrapping text field — its intrinsic height drives the window size
        let textField = NSTextField(wrappingLabelWithString: "")
        textField.tag = 1001
        textField.font = NSFont.systemFont(ofSize: 14)
        textField.textColor = NSColor(white: 0.15, alpha: 1.0)
        textField.drawsBackground = false
        textField.isBezeled = false
        textField.isEditable = false
        textField.lineBreakMode = .byWordWrapping
        textField.usesSingleLineMode = false
        textField.maximumNumberOfLines = 0
        textField.preferredMaxLayoutWidth = classicBubbleWidth - 36
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.isHidden = true
        containerView.addSubview(textField)
        classicTextField = textField

        // Text field defines the content area; image stretches to fill.
        // Bubble tail is at bottom-left, so bottom inset is larger.
        classicConstraints = [
            // Image fills the entire container
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            // Text inset inside the bubble
            textField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            textField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24),
            // Fixed width for the bubble
            containerView.widthAnchor.constraint(equalToConstant: classicBubbleWidth),
        ]
    }

    /// Switch between list and classic mode visibility and constraints.
    func applyDisplayMode() {
        let mode = CandidateDisplayMode.current
        let isList = mode == .list

        // Deactivate all constraints first, then activate only current mode
        NSLayoutConstraint.deactivate(listConstraints)
        NSLayoutConstraint.deactivate(classicConstraints)

        stackView.isHidden = !isList
        classicImageView?.isHidden = isList
        classicTextField?.isHidden = isList

        if isList {
            NSLayoutConstraint.activate(listConstraints)
            containerView.layer?.backgroundColor = NSColor(white: 0.95, alpha: 0.95).cgColor
            containerView.layer?.cornerRadius = 6
            containerView.layer?.borderColor = NSColor(white: 0.8, alpha: 1.0).cgColor
            containerView.layer?.borderWidth = 0.5
        } else {
            NSLayoutConstraint.activate(classicConstraints)
            containerView.layer?.backgroundColor = NSColor.clear.cgColor
            containerView.layer?.cornerRadius = 0
            containerView.layer?.borderWidth = 0
        }
    }

    // MARK: - Update Candidates

    /// Update the candidate list. `selected` is the currently highlighted index within `words`.
    func updateCandidates(_ words: [String], selectedIndex: Int) {
        let mode = CandidateDisplayMode.current
        switch mode {
        case .list:
            updateListMode(words, selectedIndex: selectedIndex)
        case .classic:
            updateClassicMode(words, selectedIndex: selectedIndex)
        }
    }

    private func updateListMode(_ words: [String], selectedIndex: Int) {
        candidateLabels.forEach { $0.removeFromSuperview() }
        candidateLabels.removeAll()

        guard !words.isEmpty else {
            setContentSize(NSSize(width: windowWidth, height: 30))
            return
        }

        Log.ui.debug("updateCandidates(list): \(words.count) candidates")
        let maxVisible = CandidateDisplayMode.list.maxVisible
        let count = min(words.count, maxVisible)
        for i in 0..<count {
            let label = makeLabel(index: i, word: words[i], isSelected: i == selectedIndex)
            stackView.addArrangedSubview(label)
            candidateLabels.append(label)
        }

        let totalHeight = padding * 2 + CGFloat(count) * rowHeight + CGFloat(max(0, count - 1)) * stackView.spacing
        setContentSize(NSSize(width: windowWidth, height: totalHeight))
    }

    private func updateClassicMode(_ words: [String], selectedIndex: Int) {
        candidateLabels.forEach { $0.removeFromSuperview() }
        candidateLabels.removeAll()

        guard !words.isEmpty else {
            classicTextField?.stringValue = ""
            resizeToFitClassic()
            return
        }

        Log.ui.debug("updateCandidates(classic): \(words.count) candidates")
        let maxVisible = CandidateDisplayMode.classic.maxVisible
        let count = min(words.count, maxVisible)
        let visibleWords = Array(words.prefix(count))
        classicTextField?.stringValue = visibleWords.joined(separator: "  ")
        resizeToFitClassic()
    }

    /// Let AutoLayout calculate the natural size of the classic view, then resize the window.
    /// Only updates the content size — position is determined by showWindow() in GyaimController.
    private func resizeToFitClassic() {
        containerView.layoutSubtreeIfNeeded()
        let fitting = containerView.fittingSize
        let newSize = NSSize(width: max(fitting.width, classicBubbleWidth),
                             height: max(fitting.height, classicMinHeight))
        setContentSize(newSize)
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

// MARK: - Testable Position Calculator

struct CandidateWindowPositioner {
    /// Calculate the window origin given cursor rect, window size, screen bounds, and display mode.
    ///
    /// - Parameters:
    ///   - lineRect: The cursor line rectangle in screen coordinates (macOS Y-up: origin.y = bottom of line).
    ///   - winSize: The candidate window size.
    ///   - screenFrame: The visible screen frame.
    ///   - mode: The current display mode.
    /// - Returns: The bottom-left origin point for the window.
    static func calculate(
        lineRect: NSRect,
        winSize: NSSize,
        screenFrame: NSRect,
        mode: CandidateDisplayMode
    ) -> NSPoint {
        let gap: CGFloat = mode == .list ? 5 : 0

        // Default: place window below cursor
        var y = lineRect.origin.y - winSize.height - gap

        // Flip above cursor if window would go below screen bottom
        if y < screenFrame.minY {
            y = lineRect.origin.y + lineRect.height + gap
        }

        // X position: align with cursor, offset slightly for list mode
        var x = lineRect.origin.x - (mode == .list ? 5 : 0)

        // Clamp to screen right edge
        if x + winSize.width > screenFrame.maxX {
            x = screenFrame.maxX - winSize.width
        }

        // Clamp to screen left edge
        if x < screenFrame.minX {
            x = screenFrame.minX
        }

        return NSPoint(x: x, y: y)
    }
}
