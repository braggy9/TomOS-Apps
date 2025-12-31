import SwiftUI

@main
struct TomOSApp: App {
    // Connect our AppDelegate to handle push notifications and other UIKit lifecycle events.
    // SwiftUI apps use @UIApplicationDelegateAdaptor to bridge to UIKit's AppDelegate pattern.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
