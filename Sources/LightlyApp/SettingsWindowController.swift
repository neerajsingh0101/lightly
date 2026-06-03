import AppKit

/// Lightly's settings: where the scratchpad file lives, and the editor font
/// size. Both apply live to the editor as you change them.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private weak var editor: EditorWindowController?

    private var pathField: NSTextField!
    private var fontSizeField: NSTextField!
    private var fontStepper: NSStepper!

    init(editor: EditorWindowController) {
        self.editor = editor

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 188),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.setFrameAutosaveName("LightlySettingsWindow")

        super.init(window: window)
        window.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // --- Scratchpad file location ---
        let fileLabel = makeLabel("Scratchpad file:")
        pathField = NSTextField(labelWithString: ScratchpadStore.shared.fileURL.path)
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.textColor = .secondaryLabelColor
        pathField.translatesAutoresizingMaskIntoConstraints = false
        pathField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let changeButton = NSButton(title: "Change…", target: self, action: #selector(changeLocation))
        changeButton.bezelStyle = .rounded
        changeButton.translatesAutoresizingMaskIntoConstraints = false
        changeButton.setContentHuggingPriority(.required, for: .horizontal)

        // --- Font size ---
        let fontLabel = makeLabel("Font size:")
        fontStepper = NSStepper()
        fontStepper.minValue = LightlySettings.minFontSize
        fontStepper.maxValue = LightlySettings.maxFontSize
        fontStepper.increment = 1
        fontStepper.valueWraps = false
        fontStepper.integerValue = Int(LightlySettings.shared.fontSize)
        fontStepper.target = self
        fontStepper.action = #selector(stepperChanged)
        fontStepper.translatesAutoresizingMaskIntoConstraints = false

        fontSizeField = NSTextField(string: String(Int(LightlySettings.shared.fontSize)))
        fontSizeField.alignment = .center
        fontSizeField.target = self
        fontSizeField.action = #selector(fontFieldChanged)
        fontSizeField.translatesAutoresizingMaskIntoConstraints = false

        let ptLabel = makeLabel("pt")
        ptLabel.textColor = .secondaryLabelColor

        content.addSubview(fileLabel)
        content.addSubview(pathField)
        content.addSubview(changeButton)
        content.addSubview(fontLabel)
        content.addSubview(fontSizeField)
        content.addSubview(fontStepper)
        content.addSubview(ptLabel)

        let margin: CGFloat = 20
        NSLayoutConstraint.activate([
            // Row 1: file
            fileLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: margin),
            fileLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: margin),

            pathField.topAnchor.constraint(equalTo: fileLabel.bottomAnchor, constant: 6),
            pathField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: margin),
            pathField.trailingAnchor.constraint(equalTo: changeButton.leadingAnchor, constant: -10),
            pathField.centerYAnchor.constraint(equalTo: changeButton.centerYAnchor),

            changeButton.topAnchor.constraint(equalTo: fileLabel.bottomAnchor, constant: 2),
            changeButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -margin),

            // Row 2: font size
            fontLabel.topAnchor.constraint(equalTo: changeButton.bottomAnchor, constant: 26),
            fontLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: margin),

            fontSizeField.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            fontSizeField.leadingAnchor.constraint(equalTo: fontLabel.trailingAnchor, constant: 10),
            fontSizeField.widthAnchor.constraint(equalToConstant: 48),

            fontStepper.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            fontStepper.leadingAnchor.constraint(equalTo: fontSizeField.trailingAnchor, constant: 4),

            ptLabel.centerYAnchor.constraint(equalTo: fontLabel.centerYAnchor),
            ptLabel.leadingAnchor.constraint(equalTo: fontStepper.trailingAnchor, constant: 8),
        ])
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    // MARK: - Actions

    @objc private func changeLocation() {
        guard let window = window else { return }

        let panel = NSSavePanel()
        panel.title = "Choose where to save your scratchpad"
        panel.message = "Pick a file location — point this at a Dropbox folder to back it up."
        panel.prompt = "Use This File"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.isExtensionHidden = false

        let current = ScratchpadStore.shared.fileURL
        panel.nameFieldStringValue = current.lastPathComponent
        panel.directoryURL = current.deletingLastPathComponent()

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let editor = self?.editor else { return }
            editor.saveNow()  // persist current text before switching files
            let text = ScratchpadStore.shared.relocate(to: url.path, currentText: editor.currentText)
            editor.reloadContents(with: text)
            self?.pathField.stringValue = ScratchpadStore.shared.fileURL.path
        }
    }

    @objc private func stepperChanged() {
        applyFontSize(CGFloat(fontStepper.integerValue))
    }

    @objc private func fontFieldChanged() {
        guard let value = Double(fontSizeField.stringValue) else {
            // Reject garbage: snap the field back to the current value.
            syncFontControls()
            return
        }
        applyFontSize(CGFloat(value))
    }

    private func applyFontSize(_ size: CGFloat) {
        editor?.setFontSize(size)
        syncFontControls()
    }

    /// Reflect the editor's (clamped) font size back into both controls.
    private func syncFontControls() {
        let size = Int(editor?.currentFontSize ?? CGFloat(LightlySettings.shared.fontSize))
        fontStepper.integerValue = size
        fontSizeField.stringValue = String(size)
    }
}
