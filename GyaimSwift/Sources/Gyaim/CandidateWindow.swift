import Cocoa

/// Candidate display window — borderless, transparent, draggable.
/// Replaces CandWindow.rb + CandTextView.rb + CandView.rb (no XIB needed).
class CandidateWindow: NSWindow {
    static var shared: CandidateWindow?

    let candTextView: NSTextView
    private var initialLocation: NSPoint = .zero

    init() {
        // Match candwin.png dimensions (241x126)
        let frame = NSRect(x: 0, y: 0, width: 241, height: 126)

        candTextView = NSTextView(frame: NSRect(x: 5, y: 5, width: 231, height: 70))
        candTextView.isEditable = false
        candTextView.isSelectable = false
        candTextView.drawsBackground = false
        candTextView.font = NSFont.systemFont(ofSize: 14)
        candTextView.textColor = .black

        super.init(contentRect: frame,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)

        backgroundColor = .clear
        level = .statusBar
        alphaValue = 1.0
        isOpaque = false
        hasShadow = true
        canHide = true
        hidesOnDeactivate = false

        // Background view with candwin.png
        let contentView = CandBackgroundView(frame: frame)
        self.contentView = contentView

        // Scroll view for candidate text
        let scrollView = NSScrollView(frame: NSRect(x: 5, y: 5, width: 231, height: 70))
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = candTextView
        contentView.addSubview(scrollView)

        CandidateWindow.shared = self
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

        // Don't drag above menu bar
        if newOrigin.y + windowFrame.height > screenFrame.origin.y + screenFrame.height {
            newOrigin.y = screenFrame.origin.y + screenFrame.height - windowFrame.height
        }

        setFrameOrigin(newOrigin)
    }
}

/// Background view that draws candwin.png.
class CandBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        if let imagePath = Bundle.main.path(forResource: "candwin", ofType: "png"),
           let image = NSImage(contentsOfFile: imagePath) {
            image.draw(in: bounds, from: .zero,
                       operation: .sourceOver, fraction: 1.0)
        }
    }
}
