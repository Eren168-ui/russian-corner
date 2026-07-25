import Foundation
import RussianCornerCore
@preconcurrency import UserNotifications

public enum ReminderPermissionStatus: Equatable, Sendable {
    case authorized
    case denied
    case undetermined
    case unavailable
}

public struct DailyReminderRequest: Equatable, Sendable {
    public let identifier: String
    public let time: ReminderTime
    public let title: String
    public let body: String
    public let repeatsDaily: Bool

    public init(
        identifier: String,
        time: ReminderTime,
        title: String,
        body: String,
        repeatsDaily: Bool = true
    ) {
        self.identifier = identifier
        self.time = time
        self.title = title
        self.body = body
        self.repeatsDaily = repeatsDaily
    }
}

public protocol ReminderNotificationScheduling: Sendable {
    func authorizationStatus() async -> ReminderPermissionStatus
    func requestAuthorization() async -> ReminderPermissionStatus
    func pendingRequests(
        withIdentifiers identifiers: [String]
    ) async throws -> [DailyReminderRequest]
    func removePendingRequests(withIdentifiers identifiers: [String]) async
    func add(_ request: DailyReminderRequest) async throws
}

public final class SystemReminderNotificationScheduler:
    ReminderNotificationScheduling,
    @unchecked Sendable
{
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func authorizationStatus() async -> ReminderPermissionStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .undetermined
        @unknown default:
            return .unavailable
        }
    }

    public func requestAuthorization() async -> ReminderPermissionStatus {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound]
            )
            guard granted else {
                return .denied
            }
            return await authorizationStatus()
        } catch {
            return .unavailable
        }
    }

    public func pendingRequests(
        withIdentifiers identifiers: [String]
    ) async throws -> [DailyReminderRequest] {
        let requests = await center.pendingNotificationRequests()
        let requestsByID = Dictionary(
            uniqueKeysWithValues: requests.map {
                ($0.identifier, $0)
            }
        )

        return identifiers.compactMap { identifier in
            guard
                let request = requestsByID[identifier],
                let trigger = request.trigger
                    as? UNCalendarNotificationTrigger,
                let hour = trigger.dateComponents.hour,
                let minute = trigger.dateComponents.minute
            else {
                return nil
            }

            return DailyReminderRequest(
                identifier: identifier,
                time: ReminderTime(hour: hour, minute: minute),
                title: request.content.title,
                body: request.content.body,
                repeatsDaily: trigger.repeats
            )
        }
    }

    public func removePendingRequests(
        withIdentifiers identifiers: [String]
    ) async {
        center.removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
    }

    public func add(_ request: DailyReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        var components = DateComponents()
        components.hour = request.time.hour
        components.minute = request.time.minute
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: request.repeatsDaily
        )
        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        )
        try await center.add(notificationRequest)
    }
}

public enum ReminderScheduleResult: Equatable, Sendable {
    case scheduled([String])
    case permissionDenied
    case permissionUndetermined
    case unavailable
    case failed(String)
}

private actor ReminderReplacementCoordinator {
    private var isReplacing = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isReplacing {
            isReplacing = true
            return
        }

        await withCheckedContinuation {
            waiters.append($0)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isReplacing = false
            return
        }
        waiters.removeFirst().resume()
    }
}

public actor ReminderService {
    public static let pendingRequestIDs = [
        "russian-corner.reminder.morning",
        "russian-corner.reminder.evening",
    ]

    private static let replacementCoordinator =
        ReminderReplacementCoordinator()

    private let scheduler: any ReminderNotificationScheduling

    public init(
        scheduler: any ReminderNotificationScheduling =
            SystemReminderNotificationScheduler()
    ) {
        self.scheduler = scheduler
    }

    public func permissionStatus() async -> ReminderPermissionStatus {
        await scheduler.authorizationStatus()
    }

    public func requestPermission() async -> ReminderPermissionStatus {
        await scheduler.requestAuthorization()
    }

    public func schedule(
        settings: RussianCornerSettings
    ) async -> ReminderScheduleResult {
        await Self.replacementCoordinator.acquire()
        let result = await replace(settings: settings)
        await Self.replacementCoordinator.release()
        return result
    }

    public func reconcile(
        settings: RussianCornerSettings,
        requestAuthorizationIfNeeded: Bool
    ) async -> ReminderScheduleResult {
        await Self.replacementCoordinator.acquire()
        let result = await reconcileWithinReplacementGate(
            settings: settings,
            requestAuthorizationIfNeeded: requestAuthorizationIfNeeded
        )
        await Self.replacementCoordinator.release()
        return result
    }

    private func reconcileWithinReplacementGate(
        settings: RussianCornerSettings,
        requestAuthorizationIfNeeded: Bool
    ) async -> ReminderScheduleResult {
        var permission = await scheduler.authorizationStatus()
        if permission == .undetermined && requestAuthorizationIfNeeded {
            permission = await scheduler.requestAuthorization()
        }
        switch permission {
        case .authorized:
            break
        case .denied:
            return .permissionDenied
        case .undetermined:
            return .permissionUndetermined
        case .unavailable:
            return .unavailable
        }

        let oldRequests: [DailyReminderRequest]
        do {
            oldRequests = try await scheduler.pendingRequests(
                withIdentifiers: Self.pendingRequestIDs
            )
        } catch {
            return .failed(error.localizedDescription)
        }
        let expected = reminderRequests(settings: settings)
        guard oldRequests != expected else {
            return .scheduled(Self.pendingRequestIDs)
        }
        return await replaceAuthorized(
            oldRequests: oldRequests,
            newRequests: expected
        )
    }

    private func replace(
        settings: RussianCornerSettings
    ) async -> ReminderScheduleResult {
        switch await scheduler.authorizationStatus() {
        case .authorized:
            break
        case .denied:
            return .permissionDenied
        case .undetermined:
            return .permissionUndetermined
        case .unavailable:
            return .unavailable
        }

        let oldRequests: [DailyReminderRequest]
        do {
            oldRequests = try await scheduler.pendingRequests(
                withIdentifiers: Self.pendingRequestIDs
            )
        } catch {
            return .failed(error.localizedDescription)
        }

        return await replaceAuthorized(
            oldRequests: oldRequests,
            newRequests: reminderRequests(settings: settings)
        )
    }

    private func reminderRequests(
        settings: RussianCornerSettings
    ) -> [DailyReminderRequest] {
        zip(
            Self.pendingRequestIDs,
            settings.reminderTimes
        ).map { identifier, time in
            DailyReminderRequest(
                identifier: identifier,
                time: time,
                title: "Russian Corner",
                body: "该练一轮俄语主动回忆了。"
            )
        }
    }

    private func replaceAuthorized(
        oldRequests: [DailyReminderRequest],
        newRequests: [DailyReminderRequest]
    ) async -> ReminderScheduleResult {
        await scheduler.removePendingRequests(
            withIdentifiers: Self.pendingRequestIDs
        )

        do {
            for request in newRequests {
                try await scheduler.add(request)
            }
            return .scheduled(Self.pendingRequestIDs)
        } catch {
            let message = error.localizedDescription
            await scheduler.removePendingRequests(
                withIdentifiers: Self.pendingRequestIDs
            )
            do {
                for oldRequest in oldRequests {
                    try await scheduler.add(oldRequest)
                }
            } catch {
                let restorationMessage = error.localizedDescription
                await scheduler.removePendingRequests(
                    withIdentifiers: Self.pendingRequestIDs
                )
                return .failed(
                    "\(message) Restore failed: \(restorationMessage)"
                )
            }
            return .failed(message)
        }
    }
}
