#if os(macOS)
import SwiftUI
import AppKit
import Carbon.HIToolbox
import UserNotifications

/// GlobalShortcutManager handles system-wide keyboard shortcuts for TomOS.
///
/// ## Shortcut Pattern: ⌘⌥ (Command + Option)
///
/// | Shortcut | Action                      |
/// |----------|----------------------------|
/// | ⌘⌥T      | Quick Task Capture         |
/// | ⌘⌥E      | Email to Task (Outlook)    |
/// | ⌘⌥1      | Brain Dump                 |
/// | ⌘⌥2      | What Should I Work On?     |
/// | ⌘⌥3      | Send Morning Overview      |
/// | ⌘⌥4      | Send EOD Summary           |
/// | ⌘⌥5      | Open Dashboard             |
/// | ⌘⌥M      | Show Menu Bar Dropdown     |
/// | ⌘⌥Q      | Quit TomOS                 |
///
/// ## Implementation Notes:
/// - Uses NSEvent.addGlobalMonitorForEvents for system-wide hotkey detection
/// - Requires Accessibility permissions on macOS
/// - Hotkeys work even when app is in background
///
class GlobalShortcutManager {

    // MARK: - Singleton

    static let shared = GlobalShortcutManager()

    // MARK: - Properties

    /// Event monitor for global keyboard events
    private var eventMonitor: Any?

    /// Reference to the quick capture window controller
    private var quickCaptureWindowController: QuickCaptureWindowController?

    // MARK: - Initialization

    private init() {
        print("⌨️ GlobalShortcutManager: Initialized")
    }

    // MARK: - Setup

    /// Registers all global keyboard shortcuts.
    /// Call this from MenuBarController.setup() or TomOSApp.init()
    func registerShortcuts() {
        print("⌨️ GlobalShortcutManager: Registering global shortcuts...")

        // Remove existing monitor if any
        unregisterShortcuts()

        // Add global monitor for key down events
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKeyEvent(event)
        }

        // Also add local monitor for when app is focused
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleGlobalKeyEvent(event) == true {
                return nil  // Consume the event
            }
            return event
        }

        print("✅ GlobalShortcutManager: Shortcuts registered")
        print("   ⌘⌥T - Quick Task Capture")
        print("   ⌘⌥E - Email to Task (Outlook)")
        print("   ⌘⌥1 - Brain Dump")
        print("   ⌘⌥2 - What Should I Work On?")
        print("   ⌘⌥3 - Send Morning Overview")
        print("   ⌘⌥4 - Send EOD Summary")
        print("   ⌘⌥5 - Open Dashboard")
        print("   ⌘⌥M - Show Menu Bar Dropdown")
        print("   ⌘⌥Q - Quit TomOS")
    }

    /// Unregisters all global keyboard shortcuts.
    /// Call this when app is terminating.
    func unregisterShortcuts() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            print("⌨️ GlobalShortcutManager: Shortcuts unregistered")
        }
    }

    // MARK: - Event Handling

    /// Handles a global key event and triggers appropriate action.
    /// - Parameter event: The keyboard event
    /// - Returns: true if the event was handled, false otherwise
    @discardableResult
    private func handleGlobalKeyEvent(_ event: NSEvent) -> Bool {
        // Check for ⌘⌥ modifier combination (Command + Option)
        let requiredModifiers: NSEvent.ModifierFlags = [.command, .option]

        // Ensure exactly ⌘⌥ is pressed (not additional modifiers like Shift)
        let modifiersMatch = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == requiredModifiers

        guard modifiersMatch else { return false }

        // Get the key code
        let keyCode = event.keyCode

        // Handle shortcuts based on key
        switch keyCode {
        case kVK_ANSI_T:  // ⌘⌥T - Quick Task Capture
            print("⌨️ Shortcut: ⌘⌥T - Quick Task Capture")
            showQuickCapture()
            return true

        case kVK_ANSI_E:  // ⌘⌥E - Email to Task (Outlook)
            print("⌨️ Shortcut: ⌘⌥E - Email to Task (Outlook)")
            captureEmailAsTask()
            return true

        case kVK_ANSI_1:  // ⌘⌥1 - Brain Dump
            print("⌨️ Shortcut: ⌘⌥1 - Brain Dump")
            openBrainDump()
            return true

        case kVK_ANSI_2:  // ⌘⌥2 - What Should I Work On?
            print("⌨️ Shortcut: ⌘⌥2 - What Should I Work On?")
            openSmartSurface()
            return true

        case kVK_ANSI_3:  // ⌘⌥3 - Send Morning Overview
            print("⌨️ Shortcut: ⌘⌥3 - Send Morning Overview")
            sendMorningOverview()
            return true

        case kVK_ANSI_4:  // ⌘⌥4 - Send EOD Summary
            print("⌨️ Shortcut: ⌘⌥4 - Send EOD Summary")
            sendEODSummary()
            return true

        case kVK_ANSI_5:  // ⌘⌥5 - Open Dashboard
            print("⌨️ Shortcut: ⌘⌥5 - Open Dashboard")
            openDashboard()
            return true

        case kVK_ANSI_M:  // ⌘⌥M - Show Menu Bar Dropdown
            print("⌨️ Shortcut: ⌘⌥M - Show Menu Bar Dropdown")
            showMenuBarDropdown()
            return true

        case kVK_ANSI_Q:  // ⌘⌥Q - Quit TomOS
            print("⌨️ Shortcut: ⌘⌥Q - Quit TomOS")
            quitApp()
            return true

        default:
            return false
        }
    }

    // MARK: - Public API for URL Scheme

    /// Triggers Quick Capture from URL scheme (tomos://capture)
    func triggerQuickCapture() {
        showQuickCapture()
    }

    /// Triggers Email Capture from URL scheme (tomos://email)
    func triggerEmailCapture() {
        captureEmailAsTask()
    }

    // MARK: - Shortcut Actions

    /// Shows the quick task capture floating window (⌘⌥T)
    /// - Parameter prefillText: Optional text to pre-fill the text field
    private func showQuickCapture(prefillText: String? = nil) {
        DispatchQueue.main.async {
            if self.quickCaptureWindowController == nil {
                self.quickCaptureWindowController = QuickCaptureWindowController()
            }
            self.quickCaptureWindowController?.showWindow(prefillText: prefillText)
            self.showVisualFeedback("Quick Capture")
        }
    }

    /// Captures the selected email subject from Outlook and opens Quick Capture (⌘⌥E)
    private func captureEmailAsTask() {
        DispatchQueue.main.async {
            // AppleScript to get selected email subject from Microsoft Outlook
            let script = """
            tell application "Microsoft Outlook"
                try
                    set selectedMessages to selected objects
                    if (count of selectedMessages) > 0 then
                        set theMessage to item 1 of selectedMessages
                        set theSubject to subject of theMessage
                        return theSubject
                    else
                        return ""
                    end if
                on error
                    return ""
                end try
            end tell
            """

            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&error)

                if let emailSubject = result.stringValue, !emailSubject.isEmpty {
                    print("📧 Got email subject: \(emailSubject)")
                    self.showQuickCapture(prefillText: emailSubject)
                } else if let error = error {
                    print("❌ AppleScript error: \(error)")
                    // Still show quick capture, but empty
                    self.showQuickCapture()
                    self.showNotification(
                        title: "Outlook Not Available",
                        body: "Select an email in Outlook and try again"
                    )
                } else {
                    print("⚠️ No email selected in Outlook")
                    self.showQuickCapture()
                    self.showNotification(
                        title: "No Email Selected",
                        body: "Select an email in Outlook first"
                    )
                }
            } else {
                print("❌ Failed to create AppleScript")
                self.showQuickCapture()
            }

            self.showVisualFeedback("Email to Task")
        }
    }

    /// Opens the Brain Dump view (⌘⌥1)
    private func openBrainDump() {
        DispatchQueue.main.async {
            MenuBarController.shared.showBrainDump()
            self.showVisualFeedback("Brain Dump")
        }
    }

    /// Opens the Smart Surface view (⌘⌥2)
    private func openSmartSurface() {
        DispatchQueue.main.async {
            MenuBarController.shared.showSmartSurface()
            self.showVisualFeedback("What Should I Work On?")
        }
    }

    /// Sends the morning overview notification (⌘⌥3)
    private func sendMorningOverview() {
        showVisualFeedback("Sending Morning Overview...")

        Task {
            do {
                try await APIService.shared.sendMorningOverview()
                await MainActor.run {
                    self.showNotification(title: "Morning Overview Sent", body: "Check your notifications!")
                }
            } catch {
                print("❌ Failed to send morning overview: \(error)")
                await MainActor.run {
                    self.showNotification(title: "Error", body: "Failed to send morning overview")
                }
            }
        }
    }

    /// Sends the EOD summary notification (⌘⌥4)
    private func sendEODSummary() {
        showVisualFeedback("Sending EOD Summary...")

        Task {
            do {
                try await APIService.shared.sendEODSummary()
                await MainActor.run {
                    self.showNotification(title: "EOD Summary Sent", body: "Check your notifications!")
                }
            } catch {
                print("❌ Failed to send EOD summary: \(error)")
                await MainActor.run {
                    self.showNotification(title: "Error", body: "Failed to send EOD summary")
                }
            }
        }
    }

    /// Opens the main dashboard (⌘⌥5)
    private func openDashboard() {
        DispatchQueue.main.async {
            MenuBarController.shared.showDashboard()
            self.showVisualFeedback("Dashboard")
        }
    }

    /// Shows the menu bar dropdown (⌘⌥M)
    private func showMenuBarDropdown() {
        DispatchQueue.main.async {
            MenuBarController.shared.showMenuDropdown()
            self.showVisualFeedback("Menu")
        }
    }

    /// Quits the application (⌘⌥Q)
    private func quitApp() {
        DispatchQueue.main.async {
            print("👋 GlobalShortcutManager: Quitting app via ⌘⌥Q")
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Visual Feedback

    /// Shows brief visual feedback when a shortcut is triggered
    private func showVisualFeedback(_ action: String) {
        // Log the action for debugging
        print("🔔 Visual feedback: \(action)")

        // Flash the menu bar icon briefly to provide visual feedback
        DispatchQueue.main.async {
            // Brief visual indication in menu bar
            MenuBarController.shared.flashMenuBarIcon()
        }
    }

    /// Shows a system notification
    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show notification: \(error)")
            }
        }
    }
}

// MARK: - Key Code Constants

/// Virtual key codes for macOS keyboard
/// These match the values from Carbon.HIToolbox
private let kVK_ANSI_T: UInt16 = 0x11
private let kVK_ANSI_E: UInt16 = 0x0E
private let kVK_ANSI_1: UInt16 = 0x12
private let kVK_ANSI_2: UInt16 = 0x13
private let kVK_ANSI_3: UInt16 = 0x14
private let kVK_ANSI_4: UInt16 = 0x15
private let kVK_ANSI_5: UInt16 = 0x17
private let kVK_ANSI_M: UInt16 = 0x2E
private let kVK_ANSI_Q: UInt16 = 0x0C

#endif
