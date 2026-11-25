import AppKit
import SwiftUI

@MainActor
@objc(WindowingPreferences)
final class WindowingPreferences: NSObject, @preconcurrency AtlantisPreferencePane {
    enum Grouping: String, CaseIterable {
        case automatic = "default"
        case contained
        case scattered

        var label: String {
            switch self {
            case .automatic: "Automatically group and place spawns"
            case .contained: "Open all spawns in one window"
            case .scattered: "Open each spawn in its own window"
            }
        }
    }

    enum Style: String, CaseIterable {
        case source
        case tabbed
        case outline

        var label: String {
            switch self {
            case .source: "Source list"
            case .tabbed: "Tabs"
            case .outline: "Classic outline"
            }
        }

        var displayClass: AnyClass {
            switch self {
            case .source: RDNestedSourceView.self
            case .tabbed: RDNestedTabBarView.self
            case .outline: RDNestedOutlineView.self
            }
        }
    }

    @MainActor
    final class Settings: ObservableObject {
        let defaults: UserDefaults
        let changeStyle: (Style) -> Void
        let syncDisplay: () -> Void
        let changeStatusPosition: (Bool) -> Void
        let changeStatusVisibility: () -> Void

        init(
            defaults: UserDefaults,
            changeStyle: @escaping (Style) -> Void,
            syncDisplay: @escaping () -> Void,
            changeStatusPosition: @escaping (Bool) -> Void,
            changeStatusVisibility: @escaping () -> Void
        ) {
            self.defaults = defaults
            self.changeStyle = changeStyle
            self.syncDisplay = syncDisplay
            self.changeStatusPosition = changeStatusPosition
            self.changeStatusVisibility = changeStatusVisibility
        }

        var grouping: Grouping {
            get { defaults.string(forKey: "lemuria.window.behavior").flatMap(Grouping.init(rawValue:)) ?? .automatic }
            set {
                objectWillChange.send()
                defaults.set(newValue.rawValue, forKey: "lemuria.window.behavior")
            }
        }

        var style: Style {
            get { defaults.string(forKey: "lemuria.display.style").flatMap(Style.init(rawValue:)) ?? .source }
            set {
                objectWillChange.send()
                changeStyle(newValue)
                defaults.set(newValue.rawValue, forKey: "lemuria.display.style")
            }
        }

        var drag: Bool {
            get { !defaults.bool(forKey: "lemuria.dragging.disabled") }
            set { set(!newValue, forKey: "lemuria.dragging.disabled") }
        }

        var smallIcons: Bool {
            get { defaults.bool(forKey: "lemuria.display.smallicons") }
            set {
                set(newValue, forKey: "lemuria.display.smallicons")
                syncDisplay()
            }
        }

        var bottomStatus: Bool {
            get { defaults.bool(forKey: "atlantis.statusbar.bottom") }
            set {
                set(newValue, forKey: "atlantis.statusbar.bottom")
                changeStatusPosition(newValue)
            }
        }

        var hideStatus: Bool {
            get { defaults.bool(forKey: "atlantis.statusbar.kill") }
            set {
                set(newValue, forKey: "atlantis.statusbar.kill")
                changeStatusVisibility()
            }
        }

        private func set(_ value: Bool, forKey key: String) {
            objectWillChange.send()
            defaults.set(value, forKey: key)
        }
    }

    private lazy var settings = Settings(
        defaults: .standard,
        changeStyle: { RDSpawnViewManager().setDisplay($0.displayClass) },
        syncDisplay: { RDSpawnViewManager().syncDisplayClass() },
        changeStatusPosition: { RDPreferenceMainController()?.setStatusBarBottom($0) },
        changeStatusVisibility: { [weak self] in
            guard let self else { return }
            NotificationCenter.default.post(name: Self.statusBarChanged, object: self)
        }
    )

    static let statusBarChanged = Notification.Name("RDAtlantisStatusBarDidChangeNotification")

    private lazy var host: NSHostingView<WindowingPreferencesForm> = {
        let host = NSHostingView(rootView: WindowingPreferencesForm(settings: settings))
        host.sizingOptions = []
        host.frame.size = NSSize(width: 476, height: 322)
        return host
    }()

    @objc func preferencePaneName() -> String! { "Windowing" }
    @objc func preferencePaneImage() -> NSImage! { NSImage(named: "window") }

    @objc func preferencePaneView() -> NSView! {
        settings.objectWillChange.send()
        return host
    }

    @objc func preferencePaneCommit() {
        settings.defaults.synchronize()
    }
}

private struct WindowingPreferencesForm: View {
    @ObservedObject var settings: WindowingPreferences.Settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Allow spawns to be dragged to new windows once open", isOn: $settings.drag)
                Picker("Spawn windowing behavior", selection: $settings.grouping) {
                    ForEach(WindowingPreferences.Grouping.allCases, id: \.self) { grouping in
                        Text(grouping.label).tag(grouping)
                    }
                }
                Picker("Window display style", selection: $settings.style) {
                    ForEach(WindowingPreferences.Style.allCases, id: \.self) { style in
                        Text(style.label).tag(style)
                    }
                }
                Toggle("Always use small icons", isOn: $settings.smallIcons)
                    .disabled(settings.style != .source)
                Toggle("Put spawn status bars at the bottom", isOn: $settings.bottomStatus)
                Toggle("Remove status bar from all spawns", isOn: $settings.hideStatus)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }
}
