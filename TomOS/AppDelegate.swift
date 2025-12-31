import UIKit
import UserNotifications

/// AppDelegate handles the APNs (Apple Push Notification service) lifecycle.
///
/// Push Notification Flow:
/// 1. App launches → requestNotificationPermission() asks user for permission
/// 2. If granted → registerForRemoteNotifications() tells iOS to contact APNs
/// 3. APNs returns a unique device token → didRegisterForRemoteNotificationsWithDeviceToken
/// 4. We send this token to our Vercel backend → backend stores it for sending pushes
/// 5. When backend wants to notify this device, it sends the token + payload to APNs
/// 6. APNs delivers the push to this specific device
///
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - App Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("📱 TomOS: App launched, setting up push notifications...")

        // Set ourselves as the notification center delegate to handle foreground notifications
        UNUserNotificationCenter.current().delegate = self

        // Request permission and register for push notifications
        requestNotificationPermission(application: application)

        return true
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

    // MARK: - Foreground Notification Handling

    /// Called when a notification arrives while the app is in the foreground.
    /// By default, iOS doesn't show notifications when the app is open - this enables it.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        print("📬 TomOS: Received notification in foreground:")
        print("   Title: \(content.title)")
        print("   Body: \(content.body)")

        // Show the notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when user taps on a notification to open the app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        print("👆 TomOS: User tapped notification:")
        print("   Title: \(content.title)")
        print("   Action: \(response.actionIdentifier)")

        // Handle the notification tap (e.g., navigate to specific view)
        // For now, just log it - we can add deep linking later

        completionHandler()
    }

    // MARK: - Background Notification Handling

    /// Called when a silent push notification arrives (content-available: 1).
    /// Used for background updates without showing a visible notification.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("🔔 TomOS: Received background notification:")
        print("   Payload: \(userInfo)")

        // Process the notification payload
        // For now, just acknowledge receipt
        completionHandler(.newData)
    }
}
