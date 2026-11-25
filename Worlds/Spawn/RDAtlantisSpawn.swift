import AppKit

@MainActor
@objc(RDAtlantisSpawn)
final class RDAtlantisSpawn: NSObject, NSTextViewDelegate, @preconcurrency RDNestedViewDescriptor {
    private let descriptors = NSMutableArray()
    private let path: String
    private let name: String
    let controller: SpawnController
    private var contentView: NSView!

    @objc(initWithPath:forInstance:withPrefs:)
    init(path: String, forInstance instance: RDAtlantisWorldInstance, withPrefs prefs: RDSpawnConfigRecord?) {
        self.path = path
        self.name = path.components(separatedBy: ":").last ?? path
        self.controller = SpawnController(path: path, instance: instance)
        super.init()
        contentView = controller.makeView(for: self, prefs: prefs)
        RDSpawnViewManager().addView(self)
        controller.viewWasRegistered()
    }

    nonisolated override var description: String {
        "<RDAtlantisSpawn: \(path)>"
    }

    // MARK: Nested view descriptor

    private var isMain: Bool { controller.isMain }
    func view() -> NSView! { contentView }
    func viewUID() -> String! { "Atlantis.spawn:\(path)" }
    func viewPath() -> String! { path }
    func viewName() -> String! { name }
    func viewWeight() -> UInt { UInt(controller.weight) }
    func viewIcon() -> NSImage! { isMain ? controller.worldIcon ?? NSImage(named: "connect") : NSImage(named: "terminal") }
    func subviewDescriptors() -> [Any]! { descriptors.map { $0 } }
    func isFolder() -> Bool { descriptors.count != 0 }
    func isLive() -> Bool { descriptors.contains { ($0 as? RDNestedViewDescriptor)?.isLive() == true } || isLiveSelf() }
    @objc func isLiveSelf() -> Bool { controller.instance.isConnected() }

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
        controller.tearDown()
        if isMain { controller.instance.closeAndRemove() }
        else { controller.instance.spawnWasClosed(self) }
    }

    func closeInfoString() -> String! {
        isMain ? "Closing this view will disconnect this world, and close its other views." : ""
    }

    func viewWasFocused() {
        guard NSApp.isActive else { return }
        controller.inputView.window?.makeFirstResponder(controller.inputView)
        controller.outputView.testForCustomTooltip()
    }

    func viewWasUnfocused() { controller.outputView.hideCustomTooltip() }

    @objc(textView:committedInput:)
    func textView(_ view: NSTextView, committedInput input: NSAttributedString) {
        guard view === controller.inputView else { return }
        controller.submit(input)
    }

    @objc func shouldShowTooltip(for view: RDTextView) -> Bool {
        view === controller.outputView && RDSpawnViewManager().currentFocusedView() as AnyObject? === self
    }

    @objc func world() -> RDAtlantisWorldInstance { controller.instance }
    @objc func prefix() -> String? { controller.prefix() }
    @objc func setPrefix(_ prefix: String?) { controller.setPrefix(prefix) }
    @objc func internalPath() -> String? { controller.internalPath() }
    @objc func setInternalPath(_ path: String?) { controller.setInternalPath(path) }
    @objc func updateStatusBar() { controller.updateStatusBar() }
    @objc func setStatusBarHidden(_ hidden: Bool) { controller.setStatusBarHidden(hidden) }
    @objc func statusBarHidden() -> Bool { controller.statusBarHidden() }
    @objc func setStatusBarBottom(_ bottom: Bool) { controller.setStatusBarBottom(bottom) }
    @objc func statusBarBottom() -> Bool { controller.statusBarBottom() }
    @objc func setStatusBarUserText(_ text: NSAttributedString) { controller.setStatusBarUserText(text) }
    @objc func statusBarUserText() -> String { controller.statusBarUserText() }
    @objc func searchForString(_ sender: Any?) { controller.searchForString(sender) }
    @objc func clearSearchString(_ sender: Any?) { controller.clearSearchString(sender) }
    @objc func stringIntoInput(_ string: String) { controller.stringIntoInput(string) }
    @objc func stringInsertIntoInput(_ string: String?) { controller.stringInsertIntoInput(string) }
    @objc func stringFromInput() -> String { controller.stringFromInput() }
    @objc func stringFromInputSelection() -> String? { controller.stringFromInputSelection() }
    @objc func stringFromOutputSelection() -> String? { controller.stringFromOutputSelection() }
    @objc func appendStringNoTimestamp(_ string: NSAttributedString?) { controller.appendStringNoTimestamp(string) }
    @objc func appendString(_ string: NSAttributedString?) { controller.appendString(string) }
    @objc func ensureNewline() { controller.ensureNewline() }
    @objc func wantsActiveFor(_ string: String) -> Bool { controller.wantsActiveFor(string) }
    @objc func setFont(_ font: NSFont) { controller.setFont(font) }
    @objc func setParagraphStyle(_ style: NSParagraphStyle?) { controller.setParagraphStyle(style) }
    @objc func setLinkStyle(_ attributes: [NSAttributedString.Key: Any]?) { controller.setLinkStyle(attributes) }
    @objc func scrollbackData() -> [Any] { controller.scrollbackData() }
    @objc func clearScrollback() { controller.clearScrollback() }
    @objc func screenWidth() -> Int32 { controller.screenWidth() }
    @objc func screenHeight() -> Int32 { controller.screenHeight() }
}
