import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Config.setup()

        // Clipboard polling (60s interval)
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            CopyText.set(NSPasteboard.general.string(forType: .string))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardTimer?.invalidate()
    }
}
