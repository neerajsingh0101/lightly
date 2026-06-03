import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var editorWindowController: EditorWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        setupMainMenu()

        let controller = EditorWindowController()
        editorWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Flush any unsaved text before the app exits.
    func applicationWillTerminate(_ notification: Notification) {
        editorWindowController?.saveNow()
    }

    /// There's only one window — reopen it when the Dock icon is clicked.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            editorWindowController?.showWindow(nil)
        }
        return true
    }

    // MARK: - Settings

    @objc private func openSettings() {
        guard let editor = editorWindowController else { return }
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(editor: editor)
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Font size (View menu)

    @objc private func increaseFontSize() { editorWindowController?.bumpFontSize(by: 1) }
    @objc private func decreaseFontSize() { editorWindowController?.bumpFontSize(by: -1) }
    @objc private func resetFontSize() { editorWindowController?.resetFontSize() }

    // MARK: - Menu

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "About Lightly", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = updaterController
        appMenu.addItem(updateItem)

        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Lightly", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Lightly", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Edit menu — standard text editing commands (undo, cut/copy/paste,
        // select all, find). Without these the text view's key equivalents
        // (⌘Z, ⌘C, ⌘V, ⌘A) don't fire.
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Find…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")

        // View menu — live font size controls (also available in Settings).
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let increase = NSMenuItem(title: "Increase Font Size", action: #selector(increaseFontSize), keyEquivalent: "+")
        increase.target = self
        viewMenu.addItem(increase)
        let decrease = NSMenuItem(title: "Decrease Font Size", action: #selector(decreaseFontSize), keyEquivalent: "-")
        decrease.target = self
        viewMenu.addItem(decrease)
        let reset = NSMenuItem(title: "Reset Font Size", action: #selector(resetFontSize), keyEquivalent: "0")
        reset.target = self
        viewMenu.addItem(reset)

        // Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }
}
