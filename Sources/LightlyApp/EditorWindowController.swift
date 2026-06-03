import AppKit

/// A plain-text editor that opens detected links on a single click. Normal
/// AppKit text views only follow a link on ⌘-click while editing; this one
/// opens it the moment you click, which is what a scratchpad wants.
final class LinkifyingTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        if let url = linkURL(at: event), NSWorkspace.shared.open(url) {
            return  // consumed: don't move the insertion point
        }
        super.mouseDown(with: event)
    }

    /// The URL of the `.link` attribute under the click, if the click actually
    /// landed on a glyph carrying one.
    private func linkURL(at event: NSEvent) -> URL? {
        guard let layoutManager = layoutManager,
              let container = textContainer,
              let storage = textStorage, storage.length > 0 else { return nil }

        var point = convert(event.locationInWindow, from: nil)
        point.x -= textContainerOrigin.x
        point.y -= textContainerOrigin.y

        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(for: point, in: container,
                                                  fractionOfDistanceThroughGlyph: &fraction)
        // A click past the end of a line maps to the last glyph at fraction 1;
        // ignore those so trailing whitespace doesn't trigger the link.
        guard fraction < 1 else { return nil }
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard charIndex < storage.length else { return nil }

        switch storage.attribute(.link, at: charIndex, effectiveRange: nil) {
        case let url as URL: return url
        case let string as String: return URL(string: string)
        default: return nil
        }
    }
}

/// The main (and only) window: a single plain-text editing surface that
/// autosaves to the scratchpad file. No tabs, no titles, no documents.
final class EditorWindowController: NSWindowController, NSTextViewDelegate, NSWindowDelegate {
    private var textView: LinkifyingTextView!
    private var scrollView: NSScrollView!

    /// Detects URLs so they can be styled and made clickable.
    private static let linkDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    /// Guards against re-entrancy: applying link attributes mutates the text
    /// storage, and we don't want that to be mistaken for a user edit.
    private var isLinkifying = false

    private var fontSize: CGFloat = CGFloat(LightlySettings.shared.fontSize)
    private var currentFont: NSFont { NSFont.systemFont(ofSize: fontSize) }

    /// Coalesces rapid keystrokes into a single write a short moment after the
    /// user stops typing.
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounce: TimeInterval = 0.4

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Lightly"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.center()
        // Remember the window's size and position across launches.
        window.setFrameAutosaveName("LightlyMainWindow")
        window.minSize = NSSize(width: 360, height: 240)

        super.init(window: window)
        window.delegate = self

        setupTextView()
        loadContents()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTextView() {
        guard let window = window else { return }

        scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true

        let contentSize = scrollView.contentSize
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(
            size: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        )
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        textView = LinkifyingTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: container)
        textView.delegate = self
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        // Plain text only — Lightly is a scratchpad, not a formatter.
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.font = currentFont
        textView.textContainerInset = NSSize(width: 24, height: 20)
        textView.isContinuousSpellCheckingEnabled = false
        textView.displaysLinkToolTips = true
        // Keep newly typed text in the base style, not whatever a nearby link uses.
        textView.typingAttributes = [
            .font: currentFont,
            .foregroundColor: NSColor.labelColor,
        ]

        scrollView.documentView = textView
        window.contentView = scrollView
        window.makeFirstResponder(textView)
    }

    private func loadContents() {
        textView.string = ScratchpadStore.shared.load()
        linkify()
    }

    /// Replace the editor contents (used after the file location changes).
    func reloadContents(with text: String) {
        textView.string = text
        linkify()
    }

    var currentText: String { textView?.string ?? "" }

    // MARK: - Font size

    var currentFontSize: CGFloat { fontSize }

    /// Change the editor font size, persist it, and re-render. Clamped to the
    /// range defined in `LightlySettings`.
    func setFontSize(_ size: CGFloat) {
        let clamped = min(max(size, CGFloat(LightlySettings.minFontSize)),
                          CGFloat(LightlySettings.maxFontSize))
        guard clamped != fontSize else { return }
        fontSize = clamped
        LightlySettings.shared.setFontSize(Double(clamped))
        textView.font = currentFont
        textView.typingAttributes[.font] = currentFont
        linkify()  // reassert link styling at the new size
    }

    func bumpFontSize(by delta: CGFloat) {
        setFontSize(fontSize + delta)
    }

    func resetFontSize() {
        setFontSize(CGFloat(LightlySettings.defaultFontSize))
    }

    // MARK: - Linkify

    /// Scan the whole document for URLs and apply clickable link styling. Runs
    /// on load and after every edit (paste included). Styling lives only in the
    /// text view — the file on disk stays plain text.
    private func linkify() {
        guard let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)

        isLinkifying = true
        storage.beginEditing()
        // Reset to the base style, then overlay link styling on matches.
        storage.removeAttribute(.link, range: full)
        storage.removeAttribute(.underlineStyle, range: full)
        storage.addAttribute(.font, value: currentFont, range: full)
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)

        Self.linkDetector?.enumerateMatches(in: storage.string, options: [], range: full) { match, _, _ in
            guard let match = match, let url = match.url else { return }
            storage.addAttribute(.link, value: url, range: match.range)
            storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: match.range)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
        }
        storage.endEditing()
        isLinkifying = false
    }

    // MARK: - Autosave

    func textDidChange(_ notification: Notification) {
        guard !isLinkifying else { return }
        scheduleSave()
        scheduleLinkify()
    }

    private var linkifyWorkItem: DispatchWorkItem?

    /// Coalesce link re-scanning so it runs shortly after typing settles,
    /// keeping each keystroke cheap.
    private func scheduleLinkify() {
        linkifyWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.linkify() }
        linkifyWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let text = textView.string
        let work = DispatchWorkItem {
            ScratchpadStore.shared.save(text)
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounce, execute: work)
    }

    /// Flush any pending change to disk immediately (on close / quit / blur).
    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        ScratchpadStore.shared.save(textView.string)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        saveNow()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        saveNow()
        return true
    }
}
