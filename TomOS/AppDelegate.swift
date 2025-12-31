import UIKit
import UserNotifications

/// AppDelegate handles the APNs (Apple Push Notification service) lifecycle.
///
/// ## Push Notification Flow:
/// 1. App launches → requestNotificationPermission() asks user for permission
/// 2. If granted → registerForRemoteNotifications() tells iOS to contact APNs
/// 3. APNs returns a unique device token → didRegisterForRemoteNotificationsWithDeviceToken
/// 4. We send this token to our Vercel backend → backend stores it for sending pushes
/// 5. When backend wants to notify this device, it sends the token + payload to APNs
/// 6. APNs delivers the push to this specific device
///
/// ## Notification Lifecycle:
/// - **App in Foreground**: willPresent is called → we show banner/sound/badge
/// - **App in Background**: System shows notification → user taps → didReceive is called
/// - **App Terminated**: System shows notification → user taps → app launches → didReceive is called
/// - **Silent Push**: didReceiveRemoteNotification is called for background data updates
///
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Notification Category & Action Identifiers

    /// Category for task-related notifications (shows action buttons)
    static let taskNotificationCategory = "TASK_NOTIFICATION"

    /// Action identifiers for task notification buttons
    enum NotificationAction: String {
        case complete = "COMPLETE_ACTION"   // Mark task as complete
        case snooze = "SNOOZE_ACTION"       // Snooze for 1 hour
        case view = "VIEW_ACTION"           // Open task details

        var title: String {
            switch self {
            case .complete: return "Complete"
            case .snooze: return "Snooze 1h"
            case .view: return "View"
            }
        }
    }

    // MARK: - App Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("📱 TomOS: App launched, setting up push notifications...")

        // Set ourselves as the notification center delegate to handle foreground notifications
        UNUserNotificationCenter.current().delegate = self

        // Register notification categories with action buttons
        registerNotificationCategories()

        // Request permission and register for push notifications
        requestNotificationPermission(application: application)

        // Clear badge when app launches
        clearBadge()

        return true
    }

    /// Called when app returns to foreground - clear badge count
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("📱 TomOS: App became active, clearing badge")
        clearBadge()
    }

    // MARK: - Notification Categories & Actions

    /// Registers notification categories that define action buttons.
    /// Categories are templates that tell iOS what buttons to show for each notification type.
    ///
    /// When backend sends a push with: `"category": "TASK_NOTIFICATION"`
    /// iOS will automatically show our defined action buttons.
    private func registerNotificationCategories() {
        print("📋 TomOS: Registering notification categories...")

        // Define the "Complete" action button
        // - .foreground: Opens the app when tapped
        // - .destructive: Shows in red (indicates completing/removing the task)
        let completeAction = UNNotificationAction(
            identifier: NotificationAction.complete.rawValue,
            title: NotificationAction.complete.title,
            options: [.foreground, .destructive]
        )

        // Define the "Snooze 1h" action button
        // - .foreground: Opens the app when tapped (to confirm snooze)
        let snoozeAction = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: NotificationAction.snooze.title,
            options: [.foreground]
        )

        // Define the "View" action button
        // - .foreground: Opens the app and navigates to task details
        let viewAction = UNNotificationAction(
            identifier: NotificationAction.view.rawValue,
            title: NotificationAction.view.title,
            options: [.foreground]
        )

        // Create the task notification category with all actions
        // Actions appear in reverse order (last action appears first/leftmost)
        let taskCategory = UNNotificationCategory(
            identifier: AppDelegate.taskNotificationCategory,
            actions: [viewAction, snoozeAction, completeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]  // Notify us when user dismisses
        )

        // Register categories with the notification center
        UNUserNotificationCenter.current().setNotificationCategories([taskCategory])
        print("✅ TomOS: Notification categories registered")
    }

    // MARK: - Notification Permission

    /// Requests permission from the user to display notifications.
    /// This shows the system "Allow Notifications?" dialog on first launch.
    private func requestNotificationPermission(application: UIApplication) {
        let center = UNUserNotificationCenter.current()

        // Request authorization for alerts, sounds, and badges
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ TomOS: Notification permission error: \(error.localizedDescription)")
                return
            }

            if granted {
                print("✅ TomOS: Notification permission granted!")

                // Must register on main thread
                DispatchQueue.main.async {
                    // This tells iOS to contact APNs and get a device token
                    application.registerForRemoteNotifications()
                    print("📤 TomOS: Registering with APNs...")
                }
            } else {
                print("⚠️ TomOS: Notification permission denied by user")
                print("   Users can enable notifications later in Settings > TomOS > Notifications")
            }
        }
    }

    // MARK: - APNs Registration Callbacks

    /// Called when APNs successfully provides a device token.
    /// This token uniquely identifies this device for push notifications.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert the binary token data to a hex string
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        print("🎉 TomOS: APNs device token received!")
        print("📋 Token: \(tokenString)")
        print("   Token length: \(tokenString.count) characters")

        // Send the token to our backend so it can send us push notifications
        Task {
            await registerDeviceWithBackend(token: tokenString)
        }
    }

    /// Called when APNs registration fails.
    /// Common reasons: no internet, APNs servers unreachable, or running in Simulator without configuration.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ TomOS: Failed to register for remote notifications")
        print("   Error: \(error.localizedDescription)")

        // Provide helpful debugging info
        #if targetEnvironment(simulator)
        print("💡 TomOS: Note - Push notifications require additional setup on Simulator")
        print("   Consider testing on a physical device for full APNs functionality")
        #endif
    }

    // MARK: - Backend Registration

    /// Sends the device token to our Vercel backend for storage.
    /// The backend will use this token when sending push notifications via APNs.
    private func registerDeviceWithBackend(token: String) async {
        print("📤 TomOS: Sending device token to backend...")

        do {
            try await APIService.shared.registerDevice(token: token)
            print("✅ TomOS: Device successfully registered with backend!")
        } catch {
            print("❌ TomOS: Failed to register device with backend: \(error.localizedDescription)")
            // Note: Token is still valid, backend registration can be retried
        }
    }

    // MARK: - Foreground Notification Handling (UNUserNotificationCenterDelegate)

    /// Called when a notification arrives while the app is in the FOREGROUND.
    ///
    /// By default, iOS doesn't show notifications when the app is open.
    /// This delegate method allows us to:
    /// 1. Inspect the notification content
    /// 2. Decide whether to show it (banner, sound, badge)
    /// 3. Update app state based on the notification
    ///
    /// - Parameters:
    ///   - center: The notification center
    ///   - notification: The notification that was received
    ///   - completionHandler: Call with presentation options to show the notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let userInfo = content.userInfo

        print("📬 TomOS: Received notification in FOREGROUND:")
        print("   Title: \(content.title)")
        print("   Body: \(content.body)")
        print("   Category: \(content.categoryIdentifier)")
        print("   UserInfo: \(userInfo)")

        // Extract task_id from payload if present
        if let taskId = extractTaskId(from: userInfo) {
            print("   Task ID: \(taskId)")
        }

        // Update badge if specified in payload
        if let badgeCount = userInfo["badge"] as? Int {
            updateBadge(count: badgeCount)
        }

        // Show the notification even when app is in foreground
        // This creates a banner at the top of the screen with sound
        completionHandler([.banner, .sound, .badge, .list])
    }

    // MARK: - Notification Response Handling (UNUserNotificationCenterDelegate)

    /// Called when user interacts with a notification (tap or action button).
    ///
    /// This is called in several scenarios:
    /// 1. User taps the notification banner/alert
    /// 2. User taps an action button (Complete, Snooze, View)
    /// 3. User dismisses the notification (if .customDismissAction is set)
    ///
    /// The `response.actionIdentifier` tells us what action was taken:
    /// - `UNNotificationDefaultActionIdentifier`: User tapped the notification itself
    /// - `UNNotificationDismissActionIdentifier`: User dismissed/cleared the notification
    /// - Custom action ID: User tapped one of our action buttons
    ///
    /// - Parameters:
    ///   - center: The notification center
    ///   - response: Contains the notification and action taken
    ///   - completionHandler: Must be called when finished processing
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let userInfo = content.userInfo
        let actionIdentifier = response.actionIdentifier

        print("👆 TomOS: User interacted with notification:")
        print("   Title: \(content.title)")
        print("   Action: \(actionIdentifier)")
        print("   Category: \(content.categoryIdentifier)")

        // Extract task_id from the notification payload
        let taskId = extractTaskId(from: userInfo)

        // Handle different actions
        switch actionIdentifier {

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself (not an action button)
            print("   → User tapped notification body")
            if let taskId = taskId {
                handleViewTask(taskId: taskId)
            } else {
                print("   ⚠️ No task_id in payload, opening app to default view")
            }

        case UNNotificationDismissActionIdentifier:
            // User dismissed/cleared the notification
            print("   → User dismissed notification")
            // We could track this for analytics if desired

        case NotificationAction.complete.rawValue:
            // User tapped "Complete" action button
            print("   → User tapped COMPLETE action")
            if let taskId = taskId {
                handleCompleteTask(taskId: taskId)
            } else {
                print("   ⚠️ Cannot complete: No task_id in payload")
            }

        case NotificationAction.snooze.rawValue:
            // User tapped "Snooze 1h" action button
            print("   → User tapped SNOOZE action")
            if let taskId = taskId {
                handleSnoozeTask(taskId: taskId)
            } else {
                print("   ⚠️ Cannot snooze: No task_id in payload")
            }

        case NotificationAction.view.rawValue:
            // User tapped "View" action button
            print("   → User tapped VIEW action")
            if let taskId = taskId {
                handleViewTask(taskId: taskId)
            } else {
                print("   ⚠️ Cannot view: No task_id in payload")
            }

        default:
            // Unknown action - log for debugging
            print("   ⚠️ Unknown action identifier: \(actionIdentifier)")
        }

        // Clear badge when user interacts with notification
        clearBadge()

        // Must call completion handler when done
        completionHandler()
    }

    // MARK: - Background Notification Handling

    /// Called when a silent push notification arrives (content-available: 1).
    /// Used for background updates without showing a visible notification.
    ///
    /// Silent pushes can wake the app for up to 30 seconds to:
    /// - Fetch new data from server
    /// - Update local database
    /// - Prepare content for display
    ///
    /// - Parameters:
    ///   - application: The application
    ///   - userInfo: The notification payload
    ///   - completionHandler: Call with result (.newData, .noData, or .failed)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("🔔 TomOS: Received background/silent notification:")
        print("   Payload: \(userInfo)")

        // Extract relevant data from payload
        if let taskId = extractTaskId(from: userInfo) {
            print("   Task ID: \(taskId)")
        }

        // Update badge if specified
        if let badgeCount = userInfo["badge"] as? Int {
            updateBadge(count: badgeCount)
        }

        // TODO: Implement background data fetch if needed
        // For example: sync tasks, update local cache, etc.

        completionHandler(.newData)
    }

    // MARK: - Task Action Handlers

    /// Handles marking a task as complete from notification action.
    ///
    /// TODO: Implement API call to mark task complete
    /// - Parameter taskId: The Notion page ID of the task to complete
    private func handleCompleteTask(taskId: String) {
        print("✅ TomOS: Handling COMPLETE action for task: \(taskId)")

        // TODO: Implement API call to complete task
        // Task {
        //     do {
        //         try await APIService.shared.completeTask(taskId: taskId)
        //         print("✅ Task marked complete!")
        //     } catch {
        //         print("❌ Failed to complete task: \(error)")
        //     }
        // }

        // TODO: Show confirmation UI or haptic feedback
        // TODO: Post notification for UI to update if task list is visible
    }

    /// Handles snoozing a task for 1 hour from notification action.
    ///
    /// TODO: Implement API call to snooze task
    /// - Parameter taskId: The Notion page ID of the task to snooze
    private func handleSnoozeTask(taskId: String) {
        print("⏰ TomOS: Handling SNOOZE action for task: \(taskId)")

        // TODO: Implement API call to snooze task
        // Task {
        //     do {
        //         try await APIService.shared.snoozeTask(taskId: taskId, hours: 1)
        //         print("⏰ Task snoozed for 1 hour!")
        //     } catch {
        //         print("❌ Failed to snooze task: \(error)")
        //     }
        // }

        // TODO: Show confirmation UI or haptic feedback
        // TODO: Schedule local notification as backup reminder
    }

    /// Handles viewing task details from notification action.
    ///
    /// TODO: Implement deep linking to task detail view
    /// - Parameter taskId: The Notion page ID of the task to view
    private func handleViewTask(taskId: String) {
        print("👁️ TomOS: Handling VIEW action for task: \(taskId)")

        // TODO: Implement navigation to task detail view
        // This requires coordination with SwiftUI views:
        // 1. Post notification that UI can observe
        // 2. Or update shared state (e.g., @AppStorage, environment)
        // 3. Or use deep linking URL scheme

        // Example using NotificationCenter:
        // NotificationCenter.default.post(
        //     name: .showTaskDetail,
        //     object: nil,
        //     userInfo: ["taskId": taskId]
        // )

        // TODO: Navigate to the Smart Surface or specific task view
    }

    // MARK: - Badge Management

    /// Clears the app badge count.
    /// Called when app becomes active or user interacts with notification.
    private func clearBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("❌ TomOS: Failed to clear badge: \(error.localizedDescription)")
                } else {
                    print("🔢 TomOS: Badge cleared")
                }
            }
        }
    }

    /// Updates the app badge to a specific count.
    /// - Parameter count: The number to display on the app icon
    private func updateBadge(count: Int) {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
                if let error = error {
                    print("❌ TomOS: Failed to update badge: \(error.localizedDescription)")
                } else {
                    print("🔢 TomOS: Badge updated to \(count)")
                }
            }
        }
    }

    // MARK: - Payload Helpers

    /// Extracts the task_id from notification payload.
    ///
    /// The backend should send notifications with this structure:
    /// ```json
    /// {
    ///   "aps": { "alert": {...}, "badge": 1 },
    ///   "task_id": "notion-page-id-here",
    ///   "task_title": "Optional task title"
    /// }
    /// ```
    ///
    /// - Parameter userInfo: The notification payload dictionary
    /// - Returns: The task_id string if present, nil otherwise
    private func extractTaskId(from userInfo: [AnyHashable: Any]) -> String? {
        // Try common key variations
        if let taskId = userInfo["task_id"] as? String {
            return taskId
        }
        if let taskId = userInfo["taskId"] as? String {
            return taskId
        }
        if let taskId = userInfo["notionPageId"] as? String {
            return taskId
        }
        if let taskId = userInfo["page_id"] as? String {
            return taskId
        }

        // Log if we couldn't find a task ID
        print("   ⚠️ TomOS: No task_id found in notification payload")
        return nil
    }
}
