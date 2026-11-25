import AppKit

@MainActor
@objc(RDAtlantisSpawn)
final class RDAtlantisSpawn: NSObject, NSTextViewDelegate, @preconcurrency RDNestedViewDescriptor {
    @IBOutlet private var contentView: NSView!
    @IBOutlet private var splitPlaceholder: NSView!
    @IBOutlet private var outputView: RDTextView!
    @IBOutlet private var inputView: RDAtlantisTextInputView!
    @IBOutlet private var timerField: NSTextField!
    @IBOutlet private var statusField: NSTextField!
    @IBOutlet private var statusBar: ImageBackgroundView!
    @IBOutlet private var sslImage: NSImageView!

    private var splitView: RBSplitView!
    private var resizeTooltip: NSPanel!
    private var resizeTextField: NSTextField!
    private let descriptors = NSMutableArray()
    private let path: String
    private let name: String
    private let instance: RDAtlantisWorldInstance
    private var spawnPath: String?
    private var weight: UInt32 = 1
    private var maxLines: UInt32 = 0
    private var defaultsActive = true
    private var activeExceptions: [RDStringPattern] = []
    private var spawnPrefix: String?
    private var font = NSFont.userFixedPitchFont(ofSize: 10) ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    private var backgroundColor = NSColor.black
    private var inputColor = NSColor.white
    private var consoleColor = NSColor.yellow
    private var worldIcon: NSImage?
    private var showTimestamps = false
    private var hasText = false
    private var lastNewline = true
    private var barAtBottom = false
    private var columns: Int32 = 0
    private var rows: Int32 = 0

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "'['HH:mm:ss'] '"
        return formatter
    }()

    @objc(initWithPath:forInstance:withPrefs:)
    init(path: String, forInstance instance: RDAtlantisWorldInstance, withPrefs prefs: RDSpawnConfigRecord?) {
        self.path = path
        self.name = path.components(separatedBy: ":").last ?? path
        self.instance = instance
        super.init()

        guard let nib = NSNib(nibNamed: "SpawnView", bundle: .main),
              nib.instantiate(withOwner: self, topLevelObjects: nil) else {
            preconditionFailure("Could not load SpawnView")
        }

        configureSplitView()
        configureTextViews()
        configureResizeTooltip()
        statusBar.setBackgroundImage(NSImage(named: "StatusBarBackground"))
        layoutStatusBar()
        if let prefs { refreshSpawnPreferences(prefs) }
        setStatusBarBottom(RDSpawnStatusBarAtBottom())
        refreshWorldPreferences()
        updateStatusBar()
        RDSpawnViewManager().addView(self)
        splitView.setAutosaveName(path, recursively: false)
        _ = splitView.restoreState(true)
        splitView.adjustSubviews()
        observeChanges()
        updateScreenDimensions(notifyWorld: false)
    }

    private func configureSplitView() {
        // Keep the pane geometry in the XIB and use Lemuria's frame initializer
        // to supply the split view state that its legacy coder expects.
        guard let split = RBSplitView(frame: splitPlaceholder.frame) else {
            preconditionFailure("Could not create the spawn split view")
        }
        split.autoresizingMask = splitPlaceholder.autoresizingMask
        split.setVertical(false)
        for pane in splitPlaceholder.subviews {
            pane.removeFromSuperview()
            split.addSubview(pane)
        }
        contentView.replaceSubview(splitPlaceholder, with: split)
        splitPlaceholder = nil
        splitView = split
        RDSpawnConfigureDivider(split, NSImage(named: "spawn-dimple"),
                                NSImage(named: "spawn-splitter")?.copy() as? NSImage)
        split.adjustSubviews()
    }

    private func configureTextViews() {
        inputView.delegate = self
        inputView.backgroundColor = backgroundColor
        inputView.textColor = NSColor(white: 0.8, alpha: 1)
        inputView.insertionPointColor = inputColor
        outputView.backgroundColor = backgroundColor
        outputView.textColor = inputColor
        setFont(font)
        outputView.setMaxLines(maxLines)
        outputView.setTooltipDelegate(self)
        for view in [inputView as NSTextView, outputView as NSTextView] {
            view.turnOffKerning(self)
            view.turnOffLigatures(self)
        }
        inputView.isAutomaticDashSubstitutionEnabled = false
        inputView.isAutomaticSpellingCorrectionEnabled = false
        inputView.isAutomaticTextReplacementEnabled = false
        inputView.isAutomaticQuoteSubstitutionEnabled = false
        inputView.isAutomaticLinkDetectionEnabled = false
    }

    private func configureResizeTooltip() {
        let frame = NSRect(x: 0, y: 0, width: 100, height: 25)
        resizeTooltip = NSPanel(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        resizeTooltip.isFloatingPanel = true
        resizeTooltip.hidesOnDeactivate = false
        resizeTooltip.backgroundColor = NSColor(red: 1, green: 1, blue: 0.8, alpha: 1)
        resizeTooltip.alphaValue = 0.9
        resizeTooltip.hasShadow = true
        resizeTextField = NSTextField(frame: frame)
        resizeTextField.font = .labelFont(ofSize: 11)
        resizeTextField.isBordered = false
        resizeTextField.isBezeled = false
        resizeTextField.isSelectable = false
        resizeTextField.drawsBackground = false
        resizeTooltip.contentView?.addSubview(resizeTextField)
    }

    private func observeChanges() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(worldChangedConfig(_:)),
                           name: Notification.Name("RDAtlantisConnectionDidRefreshConfigNotification"), object: instance)
        center.addObserver(self, selector: #selector(outputViewFrameChanged(_:)),
                           name: NSSplitView.didResizeSubviewsNotification, object: splitView)
        outputView.enclosingScrollView?.postsFrameChangedNotifications = true
        center.addObserver(self, selector: #selector(outputViewFrameChanged(_:)),
                           name: NSView.frameDidChangeNotification, object: outputView.enclosingScrollView)
        center.addObserver(self, selector: #selector(statusBarSettingChanged(_:)),
                           name: Notification.Name("RDAtlantisStatusBarDidChangeNotification"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    nonisolated override var description: String {
        "<RDAtlantisSpawn: \(path)>"
    }

    @objc private func hideTooltip() {
        resizeTooltip.orderOut(self)
    }

    private func displayTooltip() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideTooltip), object: nil)
        resizeTextField.stringValue = "\(columns) cols x \(rows) rows"
        resizeTextField.sizeToFit()
        var origin = NSEvent.mouseLocation
        origin.x += 10
        resizeTooltip.setFrame(NSRect(origin: origin, size: resizeTextField.bounds.size), display: true)
        resizeTooltip.orderFront(self)
        perform(#selector(hideTooltip), with: nil, afterDelay: 2)
    }

    @objc func shouldShowTooltip(for view: RDTextView) -> Bool {
        view === outputView && RDSpawnViewManager().currentFocusedView() as AnyObject? === self
    }

    @objc func updateStatusBar() {
        let connected = instance.isConnected()
        if connected {
            let seconds = UInt32(clamping: Int(max(0, instance.connectedSince().map { Date().timeIntervalSince($0) } ?? 0)))
            timerField.stringValue = String(format: "%02u:%02u:%02u", seconds / 3600, seconds / 60 % 60, seconds % 60)
        } else {
            timerField.stringValue = "offline"
        }

        let encoding = instance.stringEncoding()
        let encodingName = encoding == UInt.max ? "default" : String.localizedName(of: String.Encoding(rawValue: encoding))
        var tooltip = "World is \(connected ? "online" : "offline")\n\(encodingName.isEmpty ? "unknown" : encodingName) encoding\n\(columns)x\(rows) screen size"
        let usesSSL = instance.isSSL()
        sslImage.image = NSImage(named: usesSSL ? "statusLockedSelected" : "statusLocked")
        if usesSSL { tooltip += "\nSSL encryption enabled" }
        if instance.isCompressing() { tooltip += "\nNetwork compression enabled" }
        if instance.supportsMCP() { tooltip += "\nMCP extensions enabled" }
        statusBar.toolTip = tooltip
    }

    @objc func setStatusBarHidden(_ hidden: Bool) {
        guard hidden != statusBarHidden() else { return }
        statusBar.isHidden = hidden
        layoutStatusBar()
    }

    @objc func statusBarHidden() -> Bool { statusBar.isHidden }

    @objc func setStatusBarBottom(_ bottom: Bool) {
        guard bottom != barAtBottom else { return }
        barAtBottom = bottom
        layoutStatusBar()
    }

    @objc func statusBarBottom() -> Bool { barAtBottom }

    private func layoutStatusBar() {
        let bounds = contentView.bounds
        let barHeight = statusBar.frame.height
        let visibleHeight = statusBarHidden() ? 0 : barHeight
        statusBar.autoresizingMask = barAtBottom ? [.width, .maxYMargin] : [.width, .minYMargin]
        statusBar.frame = NSRect(x: 0, y: barAtBottom ? 0 : bounds.height - barHeight, width: bounds.width, height: barHeight)
        let oldSize = splitView.frame.size
        splitView.frame = NSRect(x: 0, y: barAtBottom ? visibleHeight : 0, width: bounds.width,
                                 height: max(0, bounds.height - visibleHeight))
        splitView.resizeSubviews(withOldSize: oldSize)
        statusBar.needsDisplay = true
        contentView.needsDisplay = true
    }

    @objc func setStatusBarUserText(_ text: NSAttributedString) { statusField.attributedStringValue = text }
    @objc func statusBarUserText() -> String { statusField.stringValue }

    @objc private func outputViewFrameChanged(_ notification: Notification?) {
        updateScreenDimensions()
    }

    private func updateScreenDimensions(notifyWorld: Bool = true) {
        guard let layout = outputView.layoutManager, let container = outputView.textContainer else { return }
        let fontRect = font.boundingRectForFont
        let cellWidth = max(1, (fontRect.width + fontRect.origin.x).rounded())
        let cellHeight = max(1, layout.defaultLineHeight(for: font))
        let size = outputView.visibleRect.size
        let horizontalPadding = 2 * (outputView.textContainerInset.width + container.lineFragmentPadding)
        let newColumns = max(1, Int32(clamping: Int(((size.width - horizontalPadding) / cellWidth).rounded()))) - (showTimestamps ? 11 : 0)
        let newRows = max(1, Int32(clamping: Int(size.height / cellHeight)))
        if columns != newColumns || rows != newRows {
            columns = newColumns
            rows = newRows
            if notifyWorld && isMain {
                NotificationCenter.default.post(name: Notification.Name("RDAtlantisMainScreenDidChangeNotification"), object: instance)
            }
            if NSApp.currentEvent?.type == .leftMouseDragged { displayTooltip() }
        }
        statusBar.needsDisplay = true
        updateStatusBar()
    }

    @objc private func statusBarSettingChanged(_ notification: Notification?) {
        setStatusBarBottom(RDSpawnStatusBarAtBottom())
        if UserDefaults.standard.bool(forKey: "atlantis.statusbar.kill") {
            setStatusBarHidden(true)
        } else {
            worldChangedConfig(nil)
        }
    }

    // MARK: Nested view descriptor

    private var isMain: Bool {
        let basePath: String? = instance.basePath()
        return path == basePath
    }
    func view() -> NSView! { contentView }
    func viewUID() -> String! { "Atlantis.spawn:\(path)" }
    func viewPath() -> String! { path }
    func viewName() -> String! { name }
    func viewWeight() -> UInt { UInt(weight) }
    func viewIcon() -> NSImage! { isMain ? worldIcon ?? NSImage(named: "connect") : NSImage(named: "terminal") }
    func subviewDescriptors() -> [Any]! { descriptors.map { $0 } }
    func isFolder() -> Bool { descriptors.count != 0 }
    func isLive() -> Bool { descriptors.contains { ($0 as? RDNestedViewDescriptor)?.isLive() == true } || isLiveSelf() }
    @objc func isLiveSelf() -> Bool { instance.isConnected() }

    func addSubview(_ view: RDNestedViewDescriptor!) -> Bool {
        guard let view else { return false }
        descriptors.add(view)
        RDSpawnSortDescriptors(descriptors)
        return true
    }

    func removeSubview(_ view: RDNestedViewDescriptor!) -> Bool {
        guard let view else { return false }
        descriptors.remove(view)
        return true
    }

    func sortSubviews() {
        for case let view as RDNestedViewDescriptor in descriptors { view.sortSubviews() }
        RDSpawnSortDescriptors(descriptors)
    }

    func close() {
        NotificationCenter.default.removeObserver(self)
        if isMain { instance.closeAndRemove() }
        else { instance.spawnWasClosed(self) }
    }

    func closeInfoString() -> String! {
        isMain ? "Closing this view will disconnect this world, and close its other views." : ""
    }

    func viewWasFocused() {
        guard NSApp.isActive else { return }
        inputView.window?.makeFirstResponder(inputView)
        outputView.testForCustomTooltip()
    }

    func viewWasUnfocused() { outputView.hideCustomTooltip() }

    // MARK: Preferences and input

    private func refreshSpawnPreferences(_ prefs: RDSpawnConfigRecord) {
        weight = prefs.weight()
        maxLines = prefs.maxLines()
        defaultsActive = prefs.defaultActive()
        activeExceptions = prefs.activeExceptions() as? [RDStringPattern] ?? []
        outputView.setMaxLines(maxLines)
        if let prefix = prefs.prefix() { spawnPrefix = prefix }
        setStatusBarHidden(!prefs.statusBar() || UserDefaults.standard.bool(forKey: "atlantis.statusbar.kill"))
    }

    private func refreshWorldPreferences() {
        if let color = instance.preference(forKey: "atlantis.colors.background") as? NSColor {
            backgroundColor = color
            outputView.isEditable = true
            outputView.backgroundColor = color
            outputView.isEditable = false
            inputView.backgroundColor = color
        }
        let ansiColors = instance.preference(forKey: "atlantis.colors.ansi") as? [NSColor]
        let defaultColor = instance.preference(forKey: "atlantis.colors.default") as? NSColor
        if let color = defaultColor ?? ansiColors.flatMap({ $0.indices.contains(7) ? $0[7] : nil }) {
            inputColor = color
            inputView.textColor = color
            inputView.insertionPointColor = color
        }
        if let color = instance.preference(forKey: "atlantis.colors.selection") as? NSColor {
            inputView.selectedTextAttributes = [.backgroundColor: color]
            outputView.selectedTextAttributes = [.backgroundColor: color]
        }
        if let color = instance.preference(forKey: "atlantis.colors.system") as? NSColor { consoleColor = color }
        if let displayFont = instance.displayFont(), displayFont !== font { setFont(displayFont) }
        showTimestamps = (instance.preference(forKey: "atlantis.formatting.timestamps") as? NSNumber)?.boolValue ?? false
        worldIcon = instance.preference(forKey: "atlantis.info.icon") as? NSImage
    }

    @objc private func worldChangedConfig(_ notification: Notification?) {
        guard let prefs = instance.config(forSpawn: spawnPath) else { return }
        outputView.commit()
        refreshSpawnPreferences(prefs)
        refreshWorldPreferences()
    }

    @objc func prefix() -> String? { spawnPrefix }
    @objc func setPrefix(_ prefix: String?) { spawnPrefix = prefix }
    @objc func internalPath() -> String? { spawnPath }
    @objc func setInternalPath(_ path: String?) { spawnPath = path }
    @objc func world() -> RDAtlantisWorldInstance { instance }

    @objc(textView:committedInput:)
    func textView(_ view: NSTextView, committedInput input: NSAttributedString) {
        guard view === inputView else { return }
        let result = NSMutableAttributedString(attributedString: input)
        if let prefix = spawnPrefix, !prefix.isEmpty {
            let prefixLength = (prefix as NSString).length
            let alreadyPrefixed = result.length >= prefixLength &&
                (result.string as NSString).substring(to: prefixLength) == prefix
            if !alreadyPrefixed {
                result.replaceCharacters(in: NSRange(location: 0, length: 0),
                                         with: prefix.hasSuffix(" ") ? prefix : prefix + " ")
            }
        }
        instance.handleLocalInput(result, on: self)
    }

    @objc func searchForString(_ sender: Any?) { outputView.searchForString(sender) }
    @objc func clearSearchString(_ sender: Any?) { outputView.clearSearchString(sender) }

    @objc func stringIntoInput(_ string: String) {
        inputView.textStorage?.mutableString.setString(string)
        inputView.backgroundColor = backgroundColor
        inputView.textColor = inputColor
        inputView.insertionPointColor = inputColor
        inputView.font = font
    }

    @objc func stringInsertIntoInput(_ string: String?) {
        if let string { inputView.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0)) }
    }

    @objc func stringFromInput() -> String { inputView.string }
    @objc func stringFromInputSelection() -> String? { selectedText(in: inputView) }
    @objc func stringFromOutputSelection() -> String? { selectedText(in: outputView) }

    private func selectedText(in view: NSTextView) -> String? {
        let selection = view.selectedRange()
        guard selection.length > 0 else { return nil }
        return (view.string as NSString).substring(with: selection)
    }

    // MARK: Output

    private func shouldDisplay(_ string: NSAttributedString) -> Bool {
        string.length != 0 && string.attribute(NSAttributedString.Key("RDScreenOmitLine"), at: 0, effectiveRange: nil) == nil
    }

    @objc func appendStringNoTimestamp(_ string: NSAttributedString?) {
        guard let string, shouldDisplay(string) else { return }
        outputView.appendString(string)
    }

    @objc func ensureNewline() {
        guard !lastNewline else { return }
        outputView.appendString(NSAttributedString(string: "\n"))
        lastNewline = true
    }

    @objc func appendString(_ string: NSAttributedString?) {
        guard let string, shouldDisplay(string) else { return }
        if !hasText {
            hasText = true
            updateScreenDimensions()
        }
        if showTimestamps && lastNewline {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                NSAttributedString.Key("RDOmitSpan"): true,
                .foregroundColor: consoleColor,
                .backgroundColor: backgroundColor
            ]
            attributes[.paragraphStyle] = instance.paragraphStyle()
            let stamped = NSMutableAttributedString(string: Self.timestampFormatter.string(from: Date()), attributes: attributes)
            stamped.append(string)
            outputView.appendString(stamped)
        } else {
            outputView.appendString(string)
        }
        lastNewline = (string.string as NSString).character(at: string.length - 1) == 10
    }

    @objc func wantsActiveFor(_ string: String) -> Bool {
        activeExceptions.contains { $0.patternMatchesString(string) } ? !defaultsActive : defaultsActive
    }

    @objc func setFont(_ font: NSFont) {
        inputView.font = font
        outputView.font = font
        self.font = font
    }

    @objc func setParagraphStyle(_ style: NSParagraphStyle?) { outputView.defaultParagraphStyle = style }
    @objc func setLinkStyle(_ attributes: [NSAttributedString.Key: Any]?) { outputView.linkTextAttributes = attributes }
    @objc func scrollbackData() -> [Any] { RDSpawnScrollback(outputView) }
    @objc func screenWidth() -> Int32 { columns }
    @objc func screenHeight() -> Int32 { rows }
    @objc func clearScrollback() { outputView.clear() }
}
