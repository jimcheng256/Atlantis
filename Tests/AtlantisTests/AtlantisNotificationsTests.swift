import AppKit
import UserNotifications
import XCTest
@testable import Atlantis

final class AtlantisNotificationsTests: XCTestCase {
    @MainActor
    func testNotificationActionIsRegisteredUnderItsAtlantisName() throws {
        let controller = try XCTUnwrap(RDPreferenceMainController())
        let actions = try XCTUnwrap(controller.eventActions())
        let registered = try XCTUnwrap(actions.actions(for: AtlantisTypeEvent))
        XCTAssertTrue(registered.contains { ($0 as? AnyClass) == Action_Notification.self })
        XCTAssertEqual(Action_Notification.actionName(), "Atlantis: Display Notification")
        let action = try XCTUnwrap(Action_Notification(string: "Message", title: "Title"))
        XCTAssertNotNil(action.actionConfigurationView())
    }

    @MainActor
    func testLegacyArchivedWorldEventPostsExpandedNotificationForOriginatingSpawn() async throws {
        let world = NotificationTestWorld()
        let spawn = makeSpawn(in: world)
        defer { removeSpawn(spawn) }

        let action = try XCTUnwrap(Action_Notification(string: "%{event.line}", title: "Page for %{world.character}"))
        let event = WorldEvent()
        event.eventSetEnabled(true)
        event.eventAddAction(action)
        let encoder = NSKeyedArchiver(requiringSecureCoding: false)
        encoder.setClassName("Action_Growl", for: Action_Notification.self)
        encoder.encode(event, forKey: NSKeyedArchiveRootObjectKey)
        encoder.finishEncoding()
        let decoder = try NSKeyedUnarchiver(forReadingFrom: encoder.encodedData)
        decoder.requiresSecureCoding = false
        let restored = try XCTUnwrap(decoder.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? WorldEvent)
        decoder.finishDecoding()
        let state = try XCTUnwrap(AtlantisState(
            string: NSMutableAttributedString(string: "Alice pages: Hello"),
            inWorld: world,
            for: spawn
        ))

        let submitted = expectation(description: "World event submitted a local notification")
        let previous = AtlantisNotifications.transport
        defer { AtlantisNotifications.transport = previous }
        AtlantisNotifications.transport = .init(
            requestAuthorization: { options in
                XCTAssertEqual(options, [.alert])
                return true
            },
            add: { request in
                XCTAssertEqual(request.content.title, "Page for Player")
                XCTAssertEqual(request.content.body, "Alice pages: Hello")
                XCTAssertEqual(request.content.userInfo["spawnPath"] as? String, spawn.viewPath())
                XCTAssertNil(request.trigger)
                submitted.fulfill()
            }
        )

        restored.execute(for: state)
        let result = await XCTWaiter.fulfillment(of: [submitted], timeout: 2)
        XCTAssertEqual(result, .completed)
    }

    @MainActor
    func testDeniedPermissionDoesNotSubmitNotification() async {
        var authorizationRequests = 0
        let previous = AtlantisNotifications.transport
        defer { AtlantisNotifications.transport = previous }
        AtlantisNotifications.transport = .init(
            requestAuthorization: { _ in
                authorizationRequests += 1
                return false
            },
            add: { _ in XCTFail("Delivery must respect denied permission") }
        )

        await AtlantisNotifications.deliver(title: "Title", body: "Body", spawnPath: nil)

        XCTAssertEqual(authorizationRequests, 1)
    }

    @MainActor
    func testEmptyNotificationDoesNotRequestPermission() async {
        let previous = AtlantisNotifications.transport
        defer { AtlantisNotifications.transport = previous }
        AtlantisNotifications.transport = .init(
            requestAuthorization: { _ in
                XCTFail("Empty notifications should not request permission")
                return true
            },
            add: { _ in XCTFail("Empty notifications should not be submitted") }
        )

        await AtlantisNotifications.deliver(title: "", body: "", spawnPath: nil)
    }

    @MainActor
    func testNotificationRoutingSelectsOpenSpawnAndIgnoresClosedSpawn() throws {
        let world = NotificationTestWorld()
        let first = makeSpawn(in: world)
        let second = makeSpawn(in: world)
        let firstPath = first.viewPath() ?? ""
        let secondPath = second.viewPath() ?? ""
        defer {
            removeSpawn(first)
            if RDSpawnViewManager().view(byPath: secondPath) != nil {
                removeSpawn(second)
            }
        }

        let manager = RDSpawnViewManager()
        manager.selectView(second)

        AtlantisNotifications.selectSpawn(at: firstPath)
        let window = try XCTUnwrap(first.view().window as? RDNestedViewWindow)
        XCTAssertTrue(window.displayView().selectedView() as AnyObject? === first)

        removeSpawn(second)
        AtlantisNotifications.selectSpawn(at: secondPath)
        XCTAssertTrue(window.displayView().selectedView() as AnyObject? === first)
    }

    @MainActor
    func testLiveWorldEventNotificationDeliveryAndClick() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["ATLANTIS_LIVE_NOTIFICATIONS"] == "1",
            "Requires an interactive macOS session and an opt-in test run."
        )

        guard UserDefaults.standard.string(forKey: "lemuria.display.style") == "source" else {
            XCTFail("Launch the live test with -lemuria.display.style source.")
            return
        }
        NSLog("Live notification test is preparing its spawns.")
        let world = NotificationTestWorld()
        let group = "Live Notification \(UUID())"
        let sourcePath = group + " Source"
        let otherPath = group + " Other"
        let placementKeys = [sourcePath, otherPath].map { "lemuria.viewWindow.\($0)" }
        for key in placementKeys {
            UserDefaults.standard.set("lemuria_main", forKey: key)
        }
        let source = makeSpawn(in: world, path: sourcePath)
        let other = makeSpawn(in: world, path: otherPath)
        defer {
            removeSpawn(other)
            removeSpawn(source)
            for key in placementKeys {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let manager = RDSpawnViewManager()
        manager.selectView(source)
        guard let window = source.view().window as? RDNestedViewWindow else {
            XCTFail("The source spawn has no hosted window.")
            return
        }
        manager.selectView(other)
        guard window.displayView().selectedView() as AnyObject? === other else {
            XCTFail("The two test spawns must share a window to verify selection after a click.")
            return
        }

        let title = "Atlantis live notification test"
        let body = "Select this notification to open Source. (\(UUID()))"
        let center = UNUserNotificationCenter.current()
        NSLog("Live notification test is checking authorization.")
        let initialSettings = await center.notificationSettings()
        XCTAssertNotEqual(initialSettings.authorizationStatus, .denied, "Enable Atlantis notifications in System Settings.")
        guard initialSettings.authorizationStatus != .denied else { return }

        let event = WorldEvent()
        event.eventSetEnabled(true)
        guard let action = Action_Notification(string: "%{event.line}", title: title),
              let state = AtlantisState(string: NSMutableAttributedString(string: body), inWorld: world, for: source) else {
            XCTFail("Could not create the live notification event.")
            return
        }
        event.eventAddAction(action)

        NSLog("Live notification test is submitting its world event.")
        event.execute(for: state)
        var delivered: UNNotificationRequest?
        let deliveryDeadline = ContinuousClock.now + .seconds(60)
        while delivered == nil && ContinuousClock.now < deliveryDeadline {
            delivered = await center.deliveredNotifications().first {
                $0.request.content.title == title && $0.request.content.body == body
            }?.request
            if delivered == nil { try await Task.sleep(for: .milliseconds(200)) }
        }

        guard let request = delivered else {
            let settings = await center.notificationSettings()
            XCTFail("macOS did not report delivery. Authorization status: \(settings.authorizationStatus.rawValue)")
            return
        }
        NSLog("macOS reported delivery. Click Atlantis live notification test to verify routing.")
        defer { center.removeDeliveredNotifications(withIdentifiers: [request.identifier]) }
        XCTAssertEqual(request.content.userInfo["spawnPath"] as? String, source.viewPath())

        let clickDeadline = ContinuousClock.now + .seconds(60)
        while window.displayView().selectedView() as AnyObject? !== source && ContinuousClock.now < clickDeadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        guard window.displayView().selectedView() as AnyObject? === source else {
            XCTFail("Click the test notification in Notification Center.")
            return
        }
        NSLog("The notification click selected the Source spawn.")
    }

    @MainActor
    private func makeSpawn(in world: NotificationTestWorld, path: String = "Notification Tests \(UUID())") -> RDAtlantisSpawn {
        RDAtlantisSpawn(path: path, forInstance: world, withPrefs: nil)
    }

    @MainActor
    private func removeSpawn(_ spawn: RDAtlantisSpawn) {
        RDSpawnViewManager().removeView(spawn)
        UserDefaults.standard.removeObject(forKey: "RBSplitView H \(spawn.viewPath() ?? "")")
    }
}

private final class NotificationTestWorld: RDAtlantisWorldInstance {
    override func baseStateInfo() -> [AnyHashable: Any]! {
        ["world.name": "Notification Test", "world.character": "Player"]
    }

    override func preference(forKey key: String!) -> Any! { nil }

    override func stringEncoding() -> UInt { UInt.max }

    override func closeAndRemove() {}
}
