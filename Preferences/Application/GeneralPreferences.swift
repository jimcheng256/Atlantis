import AppKit
import SwiftUI

@MainActor
@objc(GeneralPreferences)
final class GeneralPreferences: NSObject, @preconcurrency AtlantisPreferencePane {
    enum Option: String {
        case checkOnStartup = "atlantis.update.skipcheck"
        case clearInput = "atlantis.text.retainOnCommit"
        case noSlashies = "atlantis.input.noSlashies"
        case silentConvert = "atlantis.input.silentConvert"
        case openBook = "atlantis.startup.openBook"
        case fugueEdit = "atlantis.grab.fugueedit"
        case shortcut = "atlantis.shortcut.spawns"
        case doubleConnect = "atlantis.worldMenu.doubleConnect"
        case badgeInactive = "atlantis.badge.inactive"
        case badgeHidden = "atlantis.badge.hidden"
        case shrinkURLs = "atlantis.input.urlAutoshrink"
        case javaScript = "atlantis.scripting.disableJavaScript"

        var inverted: Bool { self == .checkOnStartup || self == .clearInput || self == .javaScript }
    }

    @MainActor
    final class Settings: ObservableObject {
        let defaults: UserDefaults
        let shortcutChanged: (Bool) -> Void
        let refreshBadge: () -> Void
        @Published var urlLength = ""

        init(defaults: UserDefaults, shortcutChanged: @escaping (Bool) -> Void, refreshBadge: @escaping () -> Void) {
            self.defaults = defaults
            self.shortcutChanged = shortcutChanged
            self.refreshBadge = refreshBadge
            reload()
        }

        func reload() {
            urlLength = String(defaults.object(forKey: "atlantis.input.urlMaxLen") == nil
                ? 60 : defaults.integer(forKey: "atlantis.input.urlMaxLen"))
        }

        func enabled(_ option: Option) -> Bool {
            defaults.bool(forKey: option.rawValue) != option.inverted
        }

        func setEnabled(_ enabled: Bool, for option: Option) {
            objectWillChange.send()
            if option == .shortcut { shortcutChanged(enabled) }
            defaults.set(enabled != option.inverted, forKey: option.rawValue)
            if option == .badgeInactive || option == .badgeHidden { refreshBadge() }
            if option == .shrinkURLs && enabled { saveURLLength() }
        }

        var beep: Int {
            get { defaults.integer(forKey: "atlantis.beeptype") }
            set {
                objectWillChange.send()
                defaults.set(newValue, forKey: "atlantis.beeptype")
            }
        }

        func saveURLLength() {
            defaults.set((urlLength as NSString).intValue, forKey: "atlantis.input.urlMaxLen")
        }
    }

    private let settings: Settings
    private lazy var host: NSHostingView<GeneralPreferencesForm> = {
        let host = NSHostingView(rootView: GeneralPreferencesForm(settings: settings))
        host.sizingOptions = []
        host.frame.size = NSSize(width: 433, height: 414)
        return host
    }()

    override init() {
        settings = Settings(
            defaults: .standard,
            shortcutChanged: { (NSApp as? RDAtlantisApplication)?.shortcutSpawns($0) },
            refreshBadge: { RDPreferenceMainController()?.refreshBadge() }
        )
        super.init()
    }

    @objc func preferencePaneName() -> String! { "General" }
    @objc func preferencePaneImage() -> NSImage! { NSImage(named: "General_Prefs") }

    @objc func preferencePaneView() -> NSView! {
        settings.reload()
        return host
    }

    @objc func preferencePaneCommit() {
        settings.defaults.synchronize()
    }
}

struct GeneralPreferencesForm: View {
    @ObservedObject var settings: GeneralPreferences.Settings
    var sectionFrameChanged: ((String, CGRect) -> Void)? = nil
    @FocusState private var editingURLLength: Bool
    private static let viewport = "General preferences viewport"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                group("Global UI Options") {
                    toggle("Use Command+Number spawn shortcuts", .shortcut)
                    toggle("Show Dock badge only when Atlantis is inactive", .badgeInactive)
                    toggle("Hide Dock badge when Atlantis is hidden", .badgeHidden)
                    toggle("Allow double-connecting worlds from the toolbar", .doubleConnect)
                    Picker("When receiving a bell", selection: $settings.beep) {
                        Text("Do nothing").tag(0)
                        Text("Show \"Beep!\"").tag(1)
                        Text("Play system beep").tag(2)
                    }
                }
                group("Global Window Options") {
                    toggle("Aliases do not require a leading /", .noSlashies)
                    toggle("Support FugueEdit input-grabbing", .fugueEdit)
                    toggle("Clear input window on enter", .clearInput)
                    toggle("Do not warn when stripping unsupported characters", .silentConvert)
                    HStack {
                        toggle("Shrink URLs longer than", .shrinkURLs)
                        TextField("Maximum URL length", text: $settings.urlLength)
                            .labelsHidden()
                            .frame(width: 64)
                            .disabled(!settings.enabled(.shrinkURLs))
                            .focused($editingURLLength)
                            .onSubmit { settings.saveURLLength() }
                            .onChange(of: editingURLLength) { focused in
                                if !focused { settings.saveURLLength() }
                            }
                    }
                }
                group("Startup Options") {
                    toggle("Check for new versions of Atlantis on startup", .checkOnStartup)
                    toggle("Open Address Book on startup if no autoconnects", .openBook)
                }
                group("Experimental") {
                    toggle("Enable JavaScript scripting (requires restart)", .javaScript)
                }
            }
            // Let the scroll view clip the viewport without compressing the sections.
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
        }
        .coordinateSpace(name: Self.viewport)
    }

    private func toggle(_ title: String, _ option: GeneralPreferences.Option) -> some View {
        Toggle(title, isOn: Binding(
            get: { settings.enabled(option) },
            set: { settings.setEnabled($0, for: option) }
        ))
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 4, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Self.viewport))
        } action: { frame in
            sectionFrameChanged?(title, frame)
        }
    }
}
