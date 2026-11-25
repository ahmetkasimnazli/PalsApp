import CloudKit
import UIKit
import UserNotifications

/// CloudKit pushes for real circles (see `CloudStore.syncSubscriptions`):
///
/// - Silent pushes (a pal joined, finished, posted, added an activity) wake the app to refresh.
///   They need the Push Notifications capability and the "Remote notifications" background mode,
///   but no permission from the user.
/// - The prank push is a visible notification, so it needs the user's OK. We ask right after
///   they create or join their first real circle, when "get notified when a pal pranks you"
///   makes sense, never at launch.
enum PushNotifications {
    /// The home model to refresh when a push arrives (set while the main screen is up).
    static weak var model: HomeModel?

    /// Asks for notification permission once, if the user hasn't been asked yet.
    static func askPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Refreshes the circles for a CloudKit push. Returns whether this was one of ours.
    @discardableResult
    static func handle(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else { return false }
        await model?.refresh()
        return true
    }
}

/// Registers for pushes at launch (silent ones need no permission) and routes them to the model.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected in the Simulator without push, or before the capability is set up.
        PalsError.logOnly(error, context: "registering for remote notifications")
    }

    /// Silent pushes (and the content-available part of the prank push), in the foreground or background.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }
        Task {
            await PushNotifications.model?.refresh()
            completionHandler(.newData)
        }
    }

    /// A prank notification while Pals is open: don't show the banner, the prank plays in the app.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        if CKNotification(fromRemoteNotificationDictionary: userInfo) != nil {
            Task { await PushNotifications.handle(userInfo) }
            return []
        }
        // Our own local notifications (the daily reminder) still show.
        return [.banner, .sound]
    }

    /// Tapped a prank notification: refresh so the prank is ready to play.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        await PushNotifications.handle(response.notification.request.content.userInfo)
    }
}
