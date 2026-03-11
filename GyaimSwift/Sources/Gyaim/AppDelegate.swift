import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Config.setup()
        Log.config.info("Gyaim launched")

        // Clipboard polling (60s interval)
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            CopyText.set(NSPasteboard.general.string(forType: .string))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.config.info("Gyaim terminating")
        FileLogger.shared.flush()
        clipboardTimer?.invalidate()
    }
}
