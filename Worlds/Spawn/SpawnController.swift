import AppKit
import SwiftUI

struct SpawnStatus: Equatable {
    var hidden = false
    var atBottom = false
    var message = NSAttributedString(string: "")
    var timer = "offline"
    var tooltip = ""
    var usesSSL = false
}

@MainActor
final class SpawnController: NSObject, ObservableObject {
    private let terminal = SpawnTerminal()
    private weak var hostView: NSView?
    @Published private(set) var status = SpawnStatus()
    private var statusRefreshPending = false

    var splitView: RBSplitView { terminal.splitView }
    var outputView: RDTextView { terminal.outputView }
    var inputView: RDAtlantisTextInputView { terminal.inputView }

    private weak var spawn: RDAtlantisSpawn?
    private var resizeTooltip: NSPanel!
    private var resizeTextField: NSTextField!
    let path: String
    let instance: RDAtlantisWorldInstance
    private var spawnPath: String?
    private(set) var weight: UInt32 = 1
    private var maxLines: UInt32 = 0
    private var defaultsActive = true
    private var activeExceptions: [RDStringPattern] = []
    private var spawnPrefix: String?
    private var font = NSFont.userFixedPitchFont(ofSize: 10) ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    private var backgroundColor = NSColor.black
    private var inputColor = NSColor.white
    private var consoleColor = NSColor.yellow
    private(set) var worldIcon: NSImage?
    private var showTimestamps = false
    private var hasText = false
    private var lastNewline = true
    private var columns: Int32 = 0
    private var rows: Int32 = 0

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "'['HH:mm:ss'] '"
        return formatter
    }()

    init(path: String, instance: RDAtlantisWorldInstance) {
        self.path = path
        self.instance = instance
        super.init()
    }

    func makeView(for spawn: RDAtlantisSpawn, prefs: RDSpawnConfigRecord?) -> NSView {
        self.spawn = spawn
        configureTextViews()
        configureResizeTooltip()
        if let prefs { refreshSpawnPreferences(prefs) }
        setStatusBarBottom(RDSpawnStatusBarAtBottom())
        refreshWorldPreferences()
        updateStatusBar()

        let host = NSHostingView(rootView: SpawnView(controller: self))
        host.sizingOptions = []
        host.frame = NSRect(x: 0, y: 0, width: 617, height: 433)
        hostView = host
        return host
    }

    func viewWasRegistered() {
        hostView?.layoutSubtreeIfNeeded()
        splitView.setAutosaveName(path, recursively: false)
        _ = splitView.restoreState(true)
        splitView.adjustSubviews()
        observeChanges()
        updateScreenDimensions(notifyWorld: false)
        updateStatusBar()
    }

    private func configureTextViews() {
        inputView.delegate = spawn
        inputView.backgroundColor = backgroundColor
        inputView.textColor = NSColor(white: 0.8, alpha: 1)
        inputView.insertionPointColor = inputColor
        outputView.backgroundColor = backgroundColor
        outputView.textColor = inputColor
        setFont(font)
        outputView.setMaxLines(maxLines)
        outputView.setTooltipDelegate(spawn)
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

    func updateStatusBar() {
        var updated = status
        let connected = instance.isConnected()
        if connected {
            let seconds = UInt32(clamping: Int(max(0, instance.connectedSince().map { Date().timeIntervalSince($0) } ?? 0)))
            updated.timer = String(format: "%02u:%02u:%02u", seconds / 3600, seconds / 60 % 60, seconds % 60)
        } else {
            updated.timer = "offline"
        }

        let encoding = instance.stringEncoding()
        let encodingName = encoding == UInt.max ? "default" : String.localizedName(of: String.Encoding(rawValue: encoding))
        var tooltip = "World is \(connected ? "online" : "offline")\n\(encodingName.isEmpty ? "unknown" : encodingName) encoding\n\(columns)x\(rows) screen size"
        let usesSSL = instance.isSSL()
        updated.usesSSL = usesSSL
        if usesSSL { tooltip += "\nSSL encryption enabled" }
        if instance.isCompressing() { tooltip += "\nNetwork compression enabled" }
        if instance.supportsMCP() { tooltip += "\nMCP extensions enabled" }
        updated.tooltip = tooltip
        if updated != status { status = updated }
    }

    func setStatusBarHidden(_ hidden: Bool) {
        if status.hidden != hidden { status.hidden = hidden }
    }

    func statusBarHidden() -> Bool { status.hidden }

    func setStatusBarBottom(_ bottom: Bool) {
        if status.atBottom != bottom { status.atBottom = bottom }
    }

    func statusBarBottom() -> Bool { status.atBottom }

    func setStatusBarUserText(_ text: NSAttributedString) {
        if !status.message.isEqual(to: text) {
            status.message = NSAttributedString(attributedString: text)
        }
    }

    func statusBarUserText() -> String { status.message.string }

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
        scheduleStatusRefresh()
    }

    private func scheduleStatusRefresh() {
        guard !statusRefreshPending else { return }
        statusRefreshPending = true
        // SwiftUI can resize the split view during a layout update.
        Task { @MainActor [weak self] in
            guard let self else { return }
            statusRefreshPending = false
            if spawn != nil { updateStatusBar() }
        }
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

    var isMain: Bool {
        let basePath: String? = instance.basePath()
        return path == basePath
    }
    func tearDown() {
        NotificationCenter.default.removeObserver(self)
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        hideTooltip()
        inputView.delegate = nil
        outputView.setTooltipDelegate(nil)
        RDSpawnSetEditorRouting(inputView, outputView, false)
        spawn = nil
    }

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

    func prefix() -> String? { spawnPrefix }
    func setPrefix(_ prefix: String?) { spawnPrefix = prefix }
    func internalPath() -> String? { spawnPath }
    func setInternalPath(_ path: String?) { spawnPath = path }

    func submit(_ input: NSAttributedString) {
        guard let spawn else { return }
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
        instance.handleLocalInput(result, on: spawn)
    }

    func searchForString(_ sender: Any?) { outputView.searchForString(sender) }
    func clearSearchString(_ sender: Any?) { outputView.clearSearchString(sender) }

    func stringIntoInput(_ string: String) {
        inputView.textStorage?.mutableString.setString(string)
        inputView.backgroundColor = backgroundColor
        inputView.textColor = inputColor
        inputView.insertionPointColor = inputColor
        inputView.font = font
    }

    func stringInsertIntoInput(_ string: String?) {
        if let string { inputView.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0)) }
    }

    func stringFromInput() -> String { inputView.string }
    func stringFromInputSelection() -> String? { selectedText(in: inputView) }
    func stringFromOutputSelection() -> String? { selectedText(in: outputView) }

    private func selectedText(in view: NSTextView) -> String? {
        let selection = view.selectedRange()
        guard selection.length > 0 else { return nil }
        return (view.string as NSString).substring(with: selection)
    }

    // MARK: Output

    private func shouldDisplay(_ string: NSAttributedString) -> Bool {
        string.length != 0 && string.attribute(NSAttributedString.Key("RDScreenOmitLine"), at: 0, effectiveRange: nil) == nil
    }

    func appendStringNoTimestamp(_ string: NSAttributedString?) {
        guard let string, shouldDisplay(string) else { return }
        outputView.appendString(string)
    }

    func ensureNewline() {
        guard !lastNewline else { return }
        outputView.appendString(NSAttributedString(string: "\n"))
        lastNewline = true
    }

    func appendString(_ string: NSAttributedString?) {
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

    func wantsActiveFor(_ string: String) -> Bool {
        activeExceptions.contains { $0.patternMatchesString(string) } ? !defaultsActive : defaultsActive
    }

    func setFont(_ font: NSFont) {
        inputView.font = font
        outputView.font = font
        self.font = font
    }

    func setParagraphStyle(_ style: NSParagraphStyle?) { outputView.defaultParagraphStyle = style }
    func setLinkStyle(_ attributes: [NSAttributedString.Key: Any]?) { outputView.linkTextAttributes = attributes }
    func scrollbackData() -> [Any] { RDSpawnScrollback(outputView) }
    func screenWidth() -> Int32 { columns }
    func screenHeight() -> Int32 { rows }
    func clearScrollback() { outputView.clear() }
}
