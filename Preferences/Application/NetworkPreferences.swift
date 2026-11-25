import AppKit
import SwiftUI

@MainActor
@objc(NetworkPreferences)
final class NetworkPreferences: NSObject, @preconcurrency AtlantisPreferencePane {
    enum Field: String, CaseIterable {
        case host = "proxyHost"
        case port = "proxyPort"
        case username = "proxyUser"
        case password = "proxyPass"

        var label: String {
            switch self {
            case .host: "Hostname"
            case .port: "Port"
            case .username: "Username"
            case .password: "Password"
            }
        }

        var key: String { "atlantis.network." + rawValue }
    }

    @MainActor
    final class Settings: ObservableObject {
        let defaults: UserDefaults
        @Published private(set) var values: [Field: String] = [:]

        init(defaults: UserDefaults) {
            self.defaults = defaults
            reload()
        }

        func reload() {
            values = Dictionary(uniqueKeysWithValues: Field.allCases.map { field in
                if field == .port {
                    let port = defaults.integer(forKey: field.key)
                    return (field, port == 0 ? "" : String(port))
                }
                return (field, defaults.string(forKey: field.key) ?? "")
            })
        }

        var proxyType: Int {
            get { defaults.integer(forKey: "atlantis.network.proxyType") }
            set {
                objectWillChange.send()
                defaults.set(newValue, forKey: "atlantis.network.proxyType")
            }
        }

        var drop: Bool {
            get { defaults.bool(forKey: "atlantis.network.drop") }
            set {
                objectWillChange.send()
                defaults.set(newValue, forKey: "atlantis.network.drop")
            }
        }

        var compress: Bool {
            get { defaults.bool(forKey: "atlantis.network.compress") }
            set {
                objectWillChange.send()
                defaults.set(newValue, forKey: "atlantis.network.compress")
            }
        }

        func enabled(_ field: Field) -> Bool {
            switch proxyType {
            case 1, 2: true
            case 3: field == .host || field == .port
            default: false
            }
        }

        func edit(_ field: Field, value: String) {
            values[field] = value
        }

        func save(_ field: Field) {
            let value = values[field, default: ""]
            if field == .port {
                defaults.set((value as NSString).intValue, forKey: field.key)
            } else {
                defaults.set(value, forKey: field.key)
            }
        }
    }

    private let settings = Settings(defaults: .standard)
    private lazy var host: NSHostingView<NetworkPreferencesForm> = {
        let host = NSHostingView(rootView: NetworkPreferencesForm(settings: settings))
        host.sizingOptions = []
        host.frame.size = NSSize(width: 428, height: 322)
        return host
    }()

    @objc func preferencePaneName() -> String! { "Networking" }
    @objc func preferencePaneImage() -> NSImage! { NSImage(named: "Network") }

    @objc func preferencePaneView() -> NSView! {
        settings.reload()
        return host
    }

    @objc func preferencePaneCommit() {
        settings.defaults.synchronize()
    }
}

private struct NetworkPreferencesForm: View {
    @ObservedObject var settings: NetworkPreferences.Settings
    @FocusState private var activeField: NetworkPreferences.Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                GroupBox("General Performance") {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Disconnect worlds when network connection is lost", isOn: $settings.drop)
                        Toggle("Compress network traffic when available", isOn: $settings.compress)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Network Proxy") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Proxy Type", selection: $settings.proxyType) {
                            Text("None").tag(0)
                            Text("SOCKS4").tag(1)
                            Text("SOCKS5").tag(2)
                            Text("HTTP").tag(3)
                        }
                        ForEach(NetworkPreferences.Field.allCases, id: \.self) { field in
                            fieldView(field)
                                .disabled(!settings.enabled(field))
                                .focused($activeField, equals: field)
                                .onSubmit { settings.save(field) }
                        }
                    }
                }
            }
            .padding(12)
        }
        .onChange(of: activeField) { [activeField] newField in
            if let previous = activeField, previous != newField {
                settings.save(previous)
            }
        }
    }

    @ViewBuilder
    private func fieldView(_ field: NetworkPreferences.Field) -> some View {
        let value = Binding(
            get: { settings.values[field, default: ""] },
            set: { settings.edit(field, value: $0) }
        )
        if field == .password {
            SecureField(field.label, text: value)
        } else {
            TextField(field.label, text: value)
        }
    }
}
