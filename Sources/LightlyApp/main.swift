import AppKit

// Set the process name so the menu bar shows "Lightly" instead of "lightly-app".
ProcessInfo.processInfo.performSelector(onMainThread: Selector(("setProcessName:")), with: "Lightly", waitUntilDone: true)

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
