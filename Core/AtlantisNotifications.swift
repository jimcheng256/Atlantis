import Foundation
import os
import UserNotifications

final class AtlantisNotifications: NSObject {
    struct Transport {
        let requestAuthorization: (UNAuthorizationOptions) async throws -> Bool
        let add: (UNNotificationRequest) async throws -> Void
    }

    @MainActor static var transport = Transport(
        requestAuthorization: { try await UNUserNotificationCenter.current().requestAuthorization(options: $0) },
        add: { try await UNUserNotificationCenter.current().add($0) }
    )

    @MainActor
    @objc static func configure() {
        NotificationDelivery.shared.configure()
    }

    @objc(postWithTitle:body:spawnPath:)
    static func post(title: String?, body: String?, spawnPath: String?) {
        Task { @MainActor in
            await deliver(
                title: title ?? "",
                body: body ?? "",
                spawnPath: spawnPath
            )
        }
    }

    @MainActor
    static func deliver(title: String, body: String, spawnPath: String?) async {
        guard !title.isEmpty || !body.isEmpty else { return }

        let transport = Self.transport
        do {
            guard try await transport.requestAuthorization([.alert]) else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            if let spawnPath {
                content.userInfo[Self.spawnPathKey] = spawnPath
            }
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            try await transport.add(request)
        } catch {
            Self.logger.error("Could not post notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    static func selectSpawn(at path: String) {
        let manager = RDSpawnViewManager()
        if let view = manager.view(byPath: path) {
            manager.selectView(view)
        }
    }

    fileprivate nonisolated static let spawnPathKey = "spawnPath"
    private static let logger = Logger(subsystem: "net.riverdark.Atlantis", category: "Notifications")
}

@MainActor
private final class NotificationDelivery: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelivery()

    private let center = UNUserNotificationCenter.current()

    func configure() {
        center.delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let path = response.notification.request.content.userInfo[AtlantisNotifications.spawnPathKey] as? String else {
            return
        }

        await AtlantisNotifications.selectSpawn(at: path)
    }
}
