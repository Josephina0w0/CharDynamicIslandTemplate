import SwiftUI
import SwiftData
import UIKit
import UserNotifications

extension Notification.Name {
    static let companionStateDidChange = Notification.Name("companionStateDidChange")
    static let companionOpenSummary = Notification.Name("companionOpenSummary")
    static let companionOpenReminder = Notification.Name("companionOpenReminder")
    static let companionOpenTracker = Notification.Name("companionOpenTracker")
}

final class MobileAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        CompanionNotificationScheduler.registerCategories()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        _ = try? SharedStateRepository.shared.mutate { _ in }
        Task {
            let state = SharedStateRepository.shared.load()
            await CompanionActionRuntime.refreshSystemSurfaces(with: state)
            await MainActor.run {
                NotificationCenter.default.post(name: .companionStateDidChange, object: nil)
            }
        }
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            do {
                switch response.actionIdentifier {
                case CompanionNotificationID.finishBreak:
                    _ = try await CompanionActionRuntime.finishBreak(source: .notificationAction)
                case CompanionNotificationID.extendBreak:
                    _ = try await CompanionActionRuntime.extendBreak(source: .notificationAction)
                default:
                    if let reminderID = response.notification.request.content.userInfo["reminderID"] as? String {
                        _ = try SharedStateRepository.shared.mutate { state in
                            state.events.append(StateEvent(
                                id: UUID(),
                                kind: .reminderAction,
                                date: Date(),
                                source: .notificationAction,
                                detail: "opened:\(reminderID)"
                            ))
                        }
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .companionOpenReminder,
                                object: reminderID
                            )
                        }
                    }
                }
                await MainActor.run {
                    NotificationCenter.default.post(name: .companionStateDidChange, object: nil)
                    NotificationCenter.default.post(name: .companionOpenSummary, object: nil)
                }
            } catch {
                // State remains recoverable from the event ledger on next launch.
            }
            completionHandler()
        }
    }
}

@main
struct CharacterCompanionMobileApp: App {
    @UIApplicationDelegateAdaptor(MobileAppDelegate.self) private var appDelegate
    @StateObject private var store = MobileAppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .onReceive(NotificationCenter.default.publisher(for: .companionStateDidChange)) { _ in
                    store.refresh()
                }
                .task {
                    store.refresh()
                    store.refreshSystemSurfaces()
                }
                .onOpenURL { url in
                    if url.host == "tracker" {
                        NotificationCenter.default.post(name: .companionOpenTracker, object: nil)
                        return
                    }
                    NotificationCenter.default.post(name: .companionOpenSummary, object: nil)
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let reminderID = components.queryItems?.first(where: { $0.name == "reminder" })?.value {
                        NotificationCenter.default.post(name: .companionOpenReminder, object: reminderID)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.refresh()
                        store.refreshNotificationStatus()
                        store.refreshSystemSurfaces()
                    }
                }
        }
        .modelContainer(for: [TrackerProject.self, TrackerHistoryEntry.self, DailyFocusItem.self])
    }
}
