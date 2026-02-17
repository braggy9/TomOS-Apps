import SwiftUI
import TomOSShared

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
                .onOpenURL { url in
                    handleURL(url)
                }
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
                .onOpenURL { url in
                    handleURL(url)
                }
        }
        .defaultSize(width: 800, height: 600)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
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

    // MARK: - URL Scheme Handling

    /// Handles incoming URLs with the `tomos://` scheme.
    ///
    /// ## Supported URLs:
    /// - `tomos://capture` - Open Quick Capture window
    /// - `tomos://braindump` - Open Brain Dump view
    /// - `tomos://smartsurface` - Open What Should I Work On?
    /// - `tomos://morning` - Send Morning Overview
    /// - `tomos://eod` - Send EOD Summary
    /// - `tomos://tasks` - Open TomOS web dashboard
    ///
    /// ## Usage from Raycast/Alfred:
    /// ```bash
    /// open "tomos://capture"
    /// ```
    private func handleURL(_ url: URL) {
        guard url.scheme == "tomos" else { return }

        let action = url.host ?? ""
        print("🔗 TomOS URL: \(url) → action: \(action)")

        #if os(macOS)
        switch action {
        case "capture":
            // Open Quick Capture window
            GlobalShortcutManager.shared.triggerQuickCapture()

        case "email":
            // Capture from Outlook email
            GlobalShortcutManager.shared.triggerEmailCapture()

        case "braindump":
            MenuBarController.shared.showBrainDump()

        case "smartsurface", "whatnext":
            MenuBarController.shared.showSmartSurface()

        case "morning":
            MenuBarController.shared.sendMorningOverview()

        case "eod":
            MenuBarController.shared.sendEODSummary()

        case "dashboard":
            MenuBarController.shared.showDashboard()

        case "tasks":
            // Open TomOS web dashboard (Notion integration removed — backend is PostgreSQL)
            MenuBarController.shared.showDashboard()

        default:
            print("⚠️ Unknown URL action: \(action)")
        }

        #elseif os(iOS)
        switch action {
        case "capture", "braindump", "quick-add":
            // Widget uses "quick-add", Brain Dump is the quick capture view
            NotificationCenter.default.post(name: .openBrainDump, object: nil)

        case "smartsurface", "whatnext":
            NotificationCenter.default.post(name: .openSmartSurface, object: nil)

        case "open":
            // Widget "open" just opens the app (no specific navigation needed)
            // The app will show last viewed tab automatically
            break

        default:
            print("⚠️ Unknown URL action: \(action)")
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
