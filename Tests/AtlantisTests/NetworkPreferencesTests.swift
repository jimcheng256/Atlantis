import XCTest
@testable import Atlantis

final class NetworkPreferencesTests: XCTestCase {
    @MainActor
    func testProxyModesEnableTheExpectedFields() {
        withSettings { settings in
            let all = NetworkPreferences.Field.allCases
            let expectations: [[NetworkPreferences.Field]] = [[], all, all, [.host, .port]]
            for (mode, enabledFields) in expectations.enumerated() {
                settings.proxyType = mode
                XCTAssertEqual(NetworkPreferences.Field.allCases.filter { settings.enabled($0) }, enabledFields)
                XCTAssertEqual(settings.defaults.integer(forKey: "atlantis.network.proxyType"), mode)
            }
        }
    }

    @MainActor
    func testEditingAndReloadPreserveStoredProxyValues() {
        withSettings { settings in
            settings.proxyType = 2
            settings.edit(.port, value: "1080")
            settings.edit(.host, value: "proxy.example")
            settings.edit(.username, value: "user")
            settings.edit(.password, value: "secret")
            XCTAssertNil(settings.defaults.object(forKey: NetworkPreferences.Field.port.key))
            for field in NetworkPreferences.Field.allCases { settings.save(field) }
            XCTAssertEqual(settings.defaults.integer(forKey: NetworkPreferences.Field.port.key), 1080)

            settings.proxyType = 3
            settings.reload()
            XCTAssertEqual(settings.values[.host], "proxy.example")
            XCTAssertEqual(settings.values[.port], "1080")
            XCTAssertEqual(settings.values[.username], "user")
            XCTAssertEqual(settings.values[.password], "secret")
            XCTAssertFalse(settings.enabled(.password))

            settings.edit(.port, value: "invalid")
            settings.save(.port)
            settings.reload()
            XCTAssertEqual(settings.values[.port], "")
        }
    }

    @MainActor
    func testNetworkTogglesUseExistingKeys() {
        withSettings { settings in
            settings.drop = true
            settings.compress = true
            XCTAssertTrue(settings.defaults.bool(forKey: "atlantis.network.drop"))
            XCTAssertTrue(settings.defaults.bool(forKey: "atlantis.network.compress"))
        }
    }

    @MainActor
    private func withSettings(_ body: (NetworkPreferences.Settings) -> Void) {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(NetworkPreferences.Settings(defaults: defaults))
    }
}
