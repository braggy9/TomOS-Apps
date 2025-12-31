import SwiftUI

/// TomOS App Entry Point
///
/// ## Platform Behavior:
/// - **iOS/iPadOS**: Full app with tab interface (existing)
/// - **macOS**: Menu bar app + dashboard window on demand
///
/// ## Architecture:
/// Both platforms share:
/// - All SwiftUI views (ContentView, BrainDumpView, etc.)
/// - APIService for backend communication
/// - NotificationManager for local notifications
/// - AppDelegate for push notification handling
///
/// macOS additionally uses:
/// - MenuBarController for the menu bar icon and dropdown
/// - NSWindow for presenting views as standalone windows
///
@main
struct TomOSApp: App {

    // MARK: - Platform-Specific Delegates

    #if os(iOS)
    /// Connect AppDelegate for iOS push notifications and lifecycle events.
    /// SwiftUI apps use @UIApplicationDelegateAdaptor to bridge to UIKit's AppDelegate pattern.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    /// Connect AppDelegate for macOS push notifications and lifecycle events.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    // MARK: - Initialization

    init() {
        #if os(macOS)
        // Set up the menu bar controller on macOS
        // This creates the menu bar icon and dropdown menu
        MenuBarController.shared.setup()
        #endif
    }

    // MARK: - App Body

    var body: some Scene {
        #if os(iOS)
        // iOS: Standard WindowGroup with ContentView (tab interface)
        WindowGroup {
            ContentView()
        }

        #elseif os(macOS)
        // macOS: Menu bar app behavior
        // The app primarily lives in the menu bar
        // WindowGroup provides the dashboard window when opened

        // Settings window (accessible from menu bar → Preferences)
        Settings {
            PreferencesView()
        }

        // Note: The menu bar is managed by MenuBarController
        // Windows are created on-demand when menu items are clicked
        // This WindowGroup is hidden by default (menu bar app style)

        WindowGroup("TomOS Dashboard", id: "dashboard") {
            ContentView()
                .frame(minWidth: 700, minHeight: 500)
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            // Add custom menu bar commands
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    MenuBarController.shared.refreshTasks()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            CommandGroup(after: .appInfo) {
                Button("Refresh Tasks") {
                    MenuBarController.shared.refreshTasks()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        #endif
    }
}

// MARK: - Cross-Platform Color Extensions

/// Provides cross-platform color definitions that work on both iOS and macOS.
/// SwiftUI's Color type is cross-platform, but some system colors need abstraction.
extension Color {

    /// A cross-platform secondary background color.
    /// - iOS: Uses systemGray6 (light gray background)
    /// - macOS: Uses windowBackgroundColor
    static var secondarySystemBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemGray6)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// A cross-platform tertiary background color.
    /// - iOS: Uses systemGray5
    /// - macOS: Uses controlBackgroundColor
    static var tertiarySystemBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemGray5)
        #elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// A cross-platform text field background color.
    static var textFieldBackground: Color {
        #if os(iOS)
        return Color(uiColor: .systemGray6)
        #elseif os(macOS)
        return Color(nsColor: .textBackgroundColor)
        #endif
    }
}
