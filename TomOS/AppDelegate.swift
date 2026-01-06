#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import UserNotifications

/// AppDelegate handles the APNs (Apple Push Notification service) lifecycle.
///
/// ## Platform Support:
/// - iOS: Uses UIApplicationDelegate for full APNs support
/// - macOS: Uses NSApplicationDelegate for APNs support
///
/// ## Push Notification Flow:
/// 1. App launches → requestNotificationPermission() asks user for permission
/// 2. If granted → registerForRemoteNotifications() tells OS to contact APNs
/// 3. APNs returns a unique device token → didRegisterForRemoteNotificationsWithDeviceToken
/// 4. We send this token to our Vercel backend → backend stores it for sending pushes
/// 5. When backend wants to notify this device, it sends the token + payload to APNs
/// 6. APNs delivers the push to this specific device
///
/// ## Notification Lifecycle:
/// - **App in Foreground**: willPresent is called → we show banner/sound/badge
/// - **App in Background**: System shows notification → user taps → didReceive is called
/// - **App Terminated**: System shows notification → user taps → app launches → didReceive is called
///

// MARK: - Shared Constants

/// Notification category and action identifiers shared across platforms
enum TomOSNotification {
    /// Category for task-related notifications (shows action buttons)
    static let taskCategory = "TASK_NOTIFICATION"

    /// Action identifiers for task notification buttons
    enum Action: String {
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
}

// MARK: - iOS AppDelegate

#if os(iOS)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Legacy Compatibility

    /// Category identifier for backward compatibility
    static let taskNotificationCategory = TomOSNotification.taskCategory

    /// Action enum for backward compatibility
    typealias NotificationAction = TomOSNotification.Action

    // MARK: - App Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("📱 TomOS iOS: App launched, setting up push notifications...")

        // Set ourselves as the notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // Register notification categories with action buttons
        registerNotificationCategories()

        // Request permission and register for push notifications
        requestNotificationPermission(application: application)

        // Clear badge when app launches
        clearBadge()

        // Setup Quick Actions (app icon long-press menu)
        setupQuickActions(for: application)

        return true
    }

    // MARK: - Quick Actions (Home Screen Shortcuts)

    private func setupQuickActions(for application: UIApplication) {
        let addTaskAction = UIApplicationShortcutItem(
            type: "com.tomos.app.quickadd",
            localizedTitle: "Add Task",
            localizedSubtitle: "Quick capture a task",
            icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill"),
            userInfo: nil
        )

        let brainDumpAction = UIApplicationShortcutItem(
            type: "com.tomos.app.braindump",
            localizedTitle: "Brain Dump",
            localizedSubtitle: "Batch add multiple tasks",
            icon: UIApplicationShortcutIcon(systemImageName: "brain.head.profile"),
            userInfo: nil
        )

        let whatNextAction = UIApplicationShortcutItem(
            type: "com.tomos.app.whatnext",
            localizedTitle: "What's Next?",
            localizedSubtitle: "AI-powered recommendations",
            icon: UIApplicationShortcutIcon(systemImageName: "target"),
            userInfo: nil
        )

        let morningAction = UIApplicationShortcutItem(
            type: "com.tomos.app.morning",
            localizedTitle: "Morning Overview",
            localizedSubtitle: "Start your day",
            icon: UIApplicationShortcutIcon(systemImageName: "sun.max.fill"),
            userInfo: nil
        )

        application.shortcutItems = [addTaskAction, brainDumpAction, whatNextAction, morningAction]
        print("📱 TomOS: Quick Actions registered")
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let handled = handleQuickAction(shortcutItem)
        completionHandler(handled)
    }

    private func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        print("📱 TomOS: Quick Action triggered: \(shortcutItem.type)")

        switch shortcutItem.type {
        case "com.tomos.app.quickadd":
            NotificationCenter.default.post(name: .openQuickAdd, object: nil)
            return true
        case "com.tomos.app.braindump":
            NotificationCenter.default.post(name: .openBrainDump, object: nil)
            return true
        case "com.tomos.app.whatnext":
            NotificationCenter.default.post(name: .openSmartSurface, object: nil)
            return true
        case "com.tomos.app.morning":
            Task {
                try? await APIService.shared.sendMorningOverview()
            }
            return true
        default:
            return false
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        print("📱 TomOS iOS: App became active, clearing badge")
        clearBadge()
    }

    // MARK: - Notification Categories

    private func registerNotificationCategories() {
        print("📋 TomOS: Registering notification categories...")

        let completeAction = UNNotificationAction(
            identifier: TomOSNotification.Action.complete.rawValue,
            title: TomOSNotification.Action.complete.title,
            options: [.foreground, .destructive]
        )

        let snoozeAction = UNNotificationAction(
            identifier: TomOSNotification.Action.snooze.rawValue,
            title: TomOSNotification.Action.snooze.title,
            options: [.foreground]
        )

        let viewAction = UNNotificationAction(
            identifier: TomOSNotification.Action.view.rawValue,
            title: TomOSNotification.Action.view.title,
            options: [.foreground]
        )

        let taskCategory = UNNotificationCategory(
            identifier: TomOSNotification.taskCategory,
            actions: [viewAction, snoozeAction, completeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([taskCategory])
        print("✅ TomOS: Notification categories registered")
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission(application: UIApplication) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ TomOS: Notification permission error: \(error.localizedDescription)")
                return
            }

            if granted {
                print("✅ TomOS: Notification permission granted!")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                    print("📤 TomOS: Registering with APNs...")
                }
            } else {
                print("⚠️ TomOS: Notification permission denied by user")
            }
        }
    }

    // MARK: - APNs Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("🎉 TomOS iOS: APNs device token received!")
        print("📋 Token: \(tokenString)")

        // Save token locally for status verification
        UserDefaults.standard.set(tokenString, forKey: "apns_device_token")

        Task {
            await registerDeviceWithBackend(token: tokenString)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ TomOS iOS: Failed to register for remote notifications")
        print("   Error: \(error.localizedDescription)")

        // Clear any stale token
        UserDefaults.standard.removeObject(forKey: "apns_device_token")

        #if targetEnvironment(simulator)
        print("💡 TomOS: Push notifications require additional setup on Simulator")
        #endif
    }

    // MARK: - Backend Registration

    private func registerDeviceWithBackend(token: String) async {
        print("📤 TomOS: Sending device token to backend...")

        do {
            try await APIService.shared.registerDevice(token: token)
            print("✅ TomOS: Device successfully registered with backend!")
        } catch {
            print("❌ TomOS: Failed to register device: \(error.localizedDescription)")
        }
    }

    // MARK: - Foreground Notification (UNUserNotificationCenterDelegate)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        print("📬 TomOS: Received notification in FOREGROUND:")
        print("   Title: \(content.title)")
        print("   Body: \(content.body)")

        if let badgeCount = content.userInfo["badge"] as? Int {
            updateBadge(count: badgeCount)
        }

        completionHandler([.banner, .sound, .badge, .list])
    }

    // MARK: - Notification Response (UNUserNotificationCenterDelegate)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let actionIdentifier = response.actionIdentifier

        print("👆 TomOS: User interacted with notification:")
        print("   Title: \(content.title)")
        print("   Action: \(actionIdentifier)")

        let taskId = extractTaskId(from: content.userInfo)

        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            if let taskId = taskId { handleViewTask(taskId: taskId) }
        case UNNotificationDismissActionIdentifier:
            print("   → User dismissed notification")
        case TomOSNotification.Action.complete.rawValue:
            if let taskId = taskId { handleCompleteTask(taskId: taskId) }
        case TomOSNotification.Action.snooze.rawValue:
            if let taskId = taskId { handleSnoozeTask(taskId: taskId) }
        case TomOSNotification.Action.view.rawValue:
            if let taskId = taskId { handleViewTask(taskId: taskId) }
        default:
            print("   ⚠️ Unknown action: \(actionIdentifier)")
        }

        clearBadge()
        completionHandler()
    }

    // MARK: - Background Notification

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("🔔 TomOS: Received background notification")

        if let badgeCount = userInfo["badge"] as? Int {
            updateBadge(count: badgeCount)
        }

        completionHandler(.newData)
    }

    // MARK: - Task Handlers

    private func handleCompleteTask(taskId: String) {
        print("✅ TomOS: Handling COMPLETE for task: \(taskId)")

        Task {
            do {
                try await APIService.shared.completeTask(taskId: taskId)
                print("✅ TomOS: Task completed successfully")

                // Show success feedback
                await MainActor.run {
                    #if os(iOS)
                    // iOS haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    #endif
                }
            } catch {
                print("❌ TomOS: Failed to complete task: \(error)")
            }
        }
    }

    private func handleSnoozeTask(taskId: String) {
        print("⏰ TomOS: Handling SNOOZE for task: \(taskId)")

        Task {
            do {
                try await APIService.shared.snoozeTask(taskId: taskId, duration: 30)
                print("⏰ TomOS: Task snoozed for 30 minutes")

                // Show success feedback
                await MainActor.run {
                    #if os(iOS)
                    // iOS haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    #endif
                }
            } catch {
                print("❌ TomOS: Failed to snooze task: \(error)")
            }
        }
    }

    private func handleViewTask(taskId: String) {
        print("👁️ TomOS: Handling VIEW for task: \(taskId)")

        // Open dashboard in browser to view task details
        APIService.shared.openDashboard()
    }

    // MARK: - Badge Management

    private func clearBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("❌ TomOS: Failed to clear badge: \(error)")
                }
            }
        }
    }

    private func updateBadge(count: Int) {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
                if let error = error {
                    print("❌ TomOS: Failed to update badge: \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func extractTaskId(from userInfo: [AnyHashable: Any]) -> String? {
        if let taskId = userInfo["task_id"] as? String { return taskId }
        if let taskId = userInfo["taskId"] as? String { return taskId }
        if let taskId = userInfo["notionPageId"] as? String { return taskId }
        return nil
    }
}

#endif

// MARK: - macOS AppDelegate

#if os(macOS)

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Legacy Compatibility

    /// Category identifier for backward compatibility
    static let taskNotificationCategory = TomOSNotification.taskCategory

    /// Action enum for backward compatibility
    typealias NotificationAction = TomOSNotification.Action

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🖥️ TomOS macOS: App launched, setting up notifications...")
        print("🖥️ TomOS macOS: Bundle ID = \(Bundle.main.bundleIdentifier ?? "unknown")")

        // Set ourselves as the notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // Register notification categories
        registerNotificationCategories()

        // Check current notification settings first
        checkCurrentNotificationStatus()

        // Request permission and register for push notifications
        requestNotificationPermission()

        // Clear badge when app launches
        clearBadge()
    }

    private func checkCurrentNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔍 TomOS macOS: Current notification settings:")
            print("   Authorization Status: \(self.authStatusString(settings.authorizationStatus))")
            print("   Alert Setting: \(self.settingString(settings.alertSetting))")
            print("   Badge Setting: \(self.settingString(settings.badgeSetting))")
            print("   Sound Setting: \(self.settingString(settings.soundSetting))")

            // If already authorized, try to register immediately
            if settings.authorizationStatus == .authorized {
                print("✅ TomOS macOS: Already authorized, registering with APNs...")
                DispatchQueue.main.async {
                    NSApplication.shared.registerForRemoteNotifications()
                }
            } else if settings.authorizationStatus == .denied {
                print("❌ TomOS macOS: Notifications DENIED - user must enable in System Settings")
            } else if settings.authorizationStatus == .notDetermined {
                print("⚠️ TomOS macOS: Notification permission not yet requested")
            }
        }
    }

    private func authStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Determined"
        case .denied: return "DENIED"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private func settingString(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: return "Not Supported"
        case .disabled: return "Disabled"
        case .enabled: return "Enabled"
        @unknown default: return "Unknown"
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        print("🖥️ TomOS macOS: App became active, clearing badge")
        clearBadge()
    }

    // MARK: - Notification Categories

    private func registerNotificationCategories() {
        print("📋 TomOS: Registering notification categories...")

        let completeAction = UNNotificationAction(
            identifier: TomOSNotification.Action.complete.rawValue,
            title: TomOSNotification.Action.complete.title,
            options: [.foreground, .destructive]
        )

        let snoozeAction = UNNotificationAction(
            identifier: TomOSNotification.Action.snooze.rawValue,
            title: TomOSNotification.Action.snooze.title,
            options: [.foreground]
        )

        let viewAction = UNNotificationAction(
            identifier: TomOSNotification.Action.view.rawValue,
            title: TomOSNotification.Action.view.title,
            options: [.foreground]
        )

        let taskCategory = UNNotificationCategory(
            identifier: TomOSNotification.taskCategory,
            actions: [viewAction, snoozeAction, completeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([taskCategory])
        print("✅ TomOS: Notification categories registered")
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ TomOS: Notification permission error: \(error.localizedDescription)")
                return
            }

            if granted {
                print("✅ TomOS: Notification permission granted!")
                DispatchQueue.main.async {
                    NSApplication.shared.registerForRemoteNotifications()
                    print("📤 TomOS: Registering with APNs...")
                }
            } else {
                print("⚠️ TomOS: Notification permission denied by user")
            }
        }
    }

    // MARK: - APNs Registration

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("🎉 TomOS macOS: APNs device token received!")
        print("📋 Token: \(tokenString)")

        // Save token locally for status verification
        UserDefaults.standard.set(tokenString, forKey: "apns_device_token_macos")

        Task {
            await registerDeviceWithBackend(token: tokenString)
        }
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ TomOS macOS: Failed to register for remote notifications")
        print("   Error: \(error.localizedDescription)")
        print("   Full error: \(error)")
        print("   Error domain: \((error as NSError).domain)")
        print("   Error code: \((error as NSError).code)")
        if let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
            print("   Underlying error: \(underlyingError)")
        }
        print("💡 TomOS macOS: Check that:")
        print("   1. Push Notifications capability is enabled in Xcode Signing & Capabilities")
        print("   2. App is signed with a provisioning profile that has Push Notifications")
        print("   3. aps-environment entitlement is set in TomOS.macOS.entitlements")

        // Clear any stale token
        UserDefaults.standard.removeObject(forKey: "apns_device_token_macos")
    }

    // MARK: - Backend Registration

    private func registerDeviceWithBackend(token: String) async {
        print("📤 TomOS: Sending device token to backend...")

        do {
            try await APIService.shared.registerDevice(token: token)
            print("✅ TomOS: Device successfully registered with backend!")
        } catch {
            print("❌ TomOS: Failed to register device: \(error.localizedDescription)")
        }
    }

    // MARK: - Foreground Notification (UNUserNotificationCenterDelegate)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        print("📬 TomOS: Received notification in FOREGROUND:")
        print("   Title: \(content.title)")
        print("   Body: \(content.body)")

        completionHandler([.banner, .sound, .badge, .list])
    }

    // MARK: - Notification Response (UNUserNotificationCenterDelegate)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let actionIdentifier = response.actionIdentifier

        print("👆 TomOS: User interacted with notification:")
        print("   Title: \(content.title)")
        print("   Action: \(actionIdentifier)")

        let taskId = extractTaskId(from: content.userInfo)

        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            if let taskId = taskId { handleViewTask(taskId: taskId) }
        case UNNotificationDismissActionIdentifier:
            print("   → User dismissed notification")
        case TomOSNotification.Action.complete.rawValue:
            if let taskId = taskId { handleCompleteTask(taskId: taskId) }
        case TomOSNotification.Action.snooze.rawValue:
            if let taskId = taskId { handleSnoozeTask(taskId: taskId) }
        case TomOSNotification.Action.view.rawValue:
            if let taskId = taskId { handleViewTask(taskId: taskId) }
        default:
            print("   ⚠️ Unknown action: \(actionIdentifier)")
        }

        clearBadge()
        completionHandler()
    }

    // MARK: - Task Handlers

    private func handleCompleteTask(taskId: String) {
        print("✅ TomOS: Handling COMPLETE for task: \(taskId)")

        Task {
            do {
                try await APIService.shared.completeTask(taskId: taskId)
                print("✅ TomOS: Task completed successfully")

                // Show success feedback
                await MainActor.run {
                    #if os(iOS)
                    // iOS haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    #endif
                }
            } catch {
                print("❌ TomOS: Failed to complete task: \(error)")
            }
        }
    }

    private func handleSnoozeTask(taskId: String) {
        print("⏰ TomOS: Handling SNOOZE for task: \(taskId)")

        Task {
            do {
                try await APIService.shared.snoozeTask(taskId: taskId, duration: 30)
                print("⏰ TomOS: Task snoozed for 30 minutes")

                // Show success feedback
                await MainActor.run {
                    #if os(iOS)
                    // iOS haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    #endif
                }
            } catch {
                print("❌ TomOS: Failed to snooze task: \(error)")
            }
        }
    }

    private func handleViewTask(taskId: String) {
        print("👁️ TomOS: Handling VIEW for task: \(taskId)")

        // Open dashboard in browser to view task details
        APIService.shared.openDashboard()
    }

    // MARK: - Badge Management

    private func clearBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("❌ TomOS: Failed to clear badge: \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func extractTaskId(from userInfo: [AnyHashable: Any]) -> String? {
        if let taskId = userInfo["task_id"] as? String { return taskId }
        if let taskId = userInfo["taskId"] as? String { return taskId }
        if let taskId = userInfo["notionPageId"] as? String { return taskId }
        return nil
    }
}

#endif
