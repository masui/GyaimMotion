import Cocoa
import InputMethodKit

let server = IMKServer(name: "Gyaim_Connection",
                       bundleIdentifier: Bundle.main.bundleIdentifier!)

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
