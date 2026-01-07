#if os(macOS)
import SwiftUI
import AppKit
import UserNotifications

/// MenuBarController manages the macOS menu bar interface for TomOS.
///
/// ## Menu Bar Structure:
/// ┌─────────────────────────────┐
/// │ 🔵 TomOS                    │
/// ├─────────────────────────────┤
/// │ 🔴 [Urgent Task 1]          │
/// │ 🔴 [Urgent Task 2]          │
/// │ 🟡 [Important Task 1]       │
/// ├─────────────────────────────┤
/// │ ➕ New Task...         ⌘⌥T  │
/// │ 🧠 Brain Dump          ⌘⌥1  │
/// │ 💭 What Should I Work On? ⌘⌥2│
/// ├─────────────────────────────┤
/// │ 📨 Morning Overview    ⌘⌥3  │
/// │ 📨 EOD Summary         ⌘⌥4  │
/// ├─────────────────────────────┤
/// │ 📊 Open Dashboard      ⌘⌥5  │
/// │ ⚙️  Preferences              │
/// ├─────────────────────────────┤
/// │ ❌ Quit TomOS          ⌘⌥Q  │
/// └─────────────────────────────┘
///
/// ## Global Shortcuts (⌘⌥ pattern):
/// - ⌘⌥T - Quick Task Capture
/// - ⌘⌥1 - Brain Dump
/// - ⌘⌥2 - What Should I Work On?
/// - ⌘⌥3 - Send Morning Overview
/// - ⌘⌥4 - Send EOD Summary
/// - ⌘⌥5 - Open Dashboard
/// - ⌘⌥M - Show Menu Dropdown
/// - ⌘⌥Q - Quit TomOS
///
/// ## Architecture:
/// - Uses NSStatusItem for the menu bar icon
/// - NSMenu with NSMenuItem for the dropdown
/// - Integrates with existing SwiftUI views via NSWindow
/// - GlobalShortcutManager handles system-wide hotkeys
///
class MenuBarController: ObservableObject {

    // MARK: - Singleton

    static let shared = MenuBarController()

    // MARK: - Properties

    /// The status item that appears in the menu bar
    private var statusItem: NSStatusItem?

    /// The main menu shown when clicking the status item
    private var menu: NSMenu?

    /// Window for the main dashboard
    private var dashboardWindow: NSWindow?

    /// Window for brain dump quick entry
    private var brainDumpWindow: NSWindow?

    /// Window for smart surface (What Should I Work On?)
    private var smartSurfaceWindow: NSWindow?

    /// Window for quick task entry
    private var quickEntryWindow: NSWindow?

    /// Current priority tasks for display in menu
    @Published var priorityTasks: [MenuBarTask] = []

    /// Badge count for urgent tasks
    @Published var urgentCount: Int = 0

    // MARK: - Initialization

    private init() {
        print("🖥️ MenuBarController: Initialized")
    }

    // MARK: - Setup

    /// Sets up the menu bar icon and menu. Call this from the App's init.
    func setup() {
        print("🖥️ MenuBarController: Setting up menu bar...")

        // Create the status item in the system menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Configure the button (the clickable area in the menu bar)
        if let button = statusItem?.button {
            // Use SF Symbol for the icon
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "TomOS")
            button.image?.isTemplate = true  // Adapts to light/dark mode

            // Add badge if there are urgent tasks
            updateBadge()
        }

        // Build and attach the menu
        buildMenu()
        statusItem?.menu = menu

        // Register global keyboard shortcuts
        GlobalShortcutManager.shared.registerShortcuts()

        // Fetch initial tasks
        refreshTasks()

        print("✅ MenuBarController: Menu bar setup complete")
    }

    // MARK: - Menu Building

    /// Builds the dropdown menu with all menu items
    private func buildMenu() {
        menu = NSMenu()
        menu?.autoenablesItems = false

        // Header
        let headerItem = NSMenuItem(title: "🔵 TomOS", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu?.addItem(headerItem)

        menu?.addItem(NSMenuItem.separator())

        // Priority Tasks Section (will be populated by refreshTasks)
        let tasksPlaceholder = NSMenuItem(title: "Loading tasks...", action: nil, keyEquivalent: "")
        tasksPlaceholder.isEnabled = false
        tasksPlaceholder.tag = 100  // Tag to identify for replacement
        menu?.addItem(tasksPlaceholder)

        menu?.addItem(NSMenuItem.separator())

        // Quick Actions with global shortcuts shown
        let newTaskItem = NSMenuItem(title: "➕ Quick Capture                ⌘⌥T", action: #selector(openQuickEntry), keyEquivalent: "")
        newTaskItem.target = self
        menu?.addItem(newTaskItem)

        let brainDumpItem = NSMenuItem(title: "🧠 Brain Dump                   ⌘⌥1", action: #selector(openBrainDump), keyEquivalent: "")
        brainDumpItem.target = self
        menu?.addItem(brainDumpItem)

        let smartSurfaceItem = NSMenuItem(title: "💭 What Should I Work On?       ⌘⌥2", action: #selector(openSmartSurface), keyEquivalent: "")
        smartSurfaceItem.target = self
        menu?.addItem(smartSurfaceItem)

        menu?.addItem(NSMenuItem.separator())

        // Notification Actions
        let morningItem = NSMenuItem(title: "📨 Send Morning Overview        ⌘⌥3", action: #selector(sendMorningOverviewAction), keyEquivalent: "")
        morningItem.target = self
        menu?.addItem(morningItem)

        let eodItem = NSMenuItem(title: "📨 Send EOD Summary             ⌘⌥4", action: #selector(sendEODSummaryAction), keyEquivalent: "")
        eodItem.target = self
        menu?.addItem(eodItem)

        menu?.addItem(NSMenuItem.separator())

        // View All Tasks in Notion
        let viewTasksItem = NSMenuItem(title: "📋 View All Tasks in Notion", action: #selector(openNotionTasks), keyEquivalent: "")
        viewTasksItem.target = self
        menu?.addItem(viewTasksItem)

        menu?.addItem(NSMenuItem.separator())

        // Dashboard & Preferences
        let dashboardItem = NSMenuItem(title: "📊 Open Dashboard               ⌘⌥5", action: #selector(openDashboard), keyEquivalent: "")
        dashboardItem.target = self
        menu?.addItem(dashboardItem)

        let preferencesItem = NSMenuItem(title: "⚙️ Preferences", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.keyEquivalentModifierMask = [.command]
        preferencesItem.target = self
        menu?.addItem(preferencesItem)

        menu?.addItem(NSMenuItem.separator())

        // Refresh & Quit
        let refreshItem = NSMenuItem(title: "🔄 Refresh Tasks", action: #selector(refreshTasksAction), keyEquivalent: "r")
        refreshItem.keyEquivalentModifierMask = [.command]
        refreshItem.target = self
        menu?.addItem(refreshItem)

        let quitItem = NSMenuItem(title: "❌ Quit TomOS                   ⌘⌥Q", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu?.addItem(quitItem)
    }

    /// Updates the tasks section of the menu
    private func updateTasksInMenu() {
        guard let menu = menu else { return }

        // Find and remove existing task items (between first separator and second separator)
        var tasksStartIndex: Int?
        var tasksEndIndex: Int?
        var separatorCount = 0

        for (index, item) in menu.items.enumerated() {
            if item.isSeparatorItem {
                separatorCount += 1
                if separatorCount == 1 {
                    tasksStartIndex = index + 1
                } else if separatorCount == 2 {
                    tasksEndIndex = index
                    break
                }
            }
        }

        guard let startIndex = tasksStartIndex, let endIndex = tasksEndIndex else { return }

        // Remove existing task items
        for _ in startIndex..<endIndex {
            menu.removeItem(at: startIndex)
        }

        // Add new task items
        if priorityTasks.isEmpty {
            let noTasksItem = NSMenuItem(title: "No priority tasks", action: nil, keyEquivalent: "")
            noTasksItem.isEnabled = false
            menu.insertItem(noTasksItem, at: startIndex)
        } else {
            for (index, task) in priorityTasks.prefix(5).enumerated() {
                let icon = task.priorityIcon
                let taskItem = NSMenuItem(
                    title: "\(icon) \(task.title)",
                    action: #selector(openTaskDetail(_:)),
                    keyEquivalent: ""
                )
                taskItem.target = self
                taskItem.representedObject = task
                taskItem.toolTip = task.reason
                menu.insertItem(taskItem, at: startIndex + index)
            }
        }
    }

    // MARK: - Badge Management

    /// Updates the badge count on the menu bar icon
    func updateBadge() {
        guard let button = statusItem?.button else { return }

        if urgentCount > 0 {
            // Create badge by adding text to button title
            button.title = " \(urgentCount)"
            button.imagePosition = .imageLeft
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    /// Flashes the menu bar icon briefly to provide visual feedback
    func flashMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        // Store original state
        let originalImage = button.image

        // Flash to a highlighted version
        button.image = NSImage(systemSymbolName: "brain.head.profile.fill", accessibilityDescription: "TomOS Active")
        button.image?.isTemplate = true

        // Restore after a brief moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            button.image = originalImage
            button.image?.isTemplate = true
        }
    }

    // MARK: - Task Fetching

    /// Fetches priority tasks from the API
    func refreshTasks() {
        print("🔄 MenuBarController: Refreshing tasks...")

        Task {
            do {
                let response = try await APIService.shared.getSmartSurface()

                await MainActor.run {
                    // Convert recommendations to MenuBarTasks
                    self.priorityTasks = response.recommendations.map { rec in
                        MenuBarTask(
                            id: UUID().uuidString,
                            title: rec.title,
                            priority: rec.priority ?? "normal",
                            reason: rec.reason
                        )
                    }

                    // Count urgent tasks
                    self.urgentCount = self.priorityTasks.filter { $0.priority.lowercased() == "urgent" }.count

                    // Update the menu
                    self.updateTasksInMenu()
                    self.updateBadge()

                    print("✅ MenuBarController: Loaded \(self.priorityTasks.count) tasks")
                }
            } catch {
                print("❌ MenuBarController: Failed to fetch tasks: \(error)")

                await MainActor.run {
                    self.priorityTasks = []
                    self.updateTasksInMenu()
                }
            }
        }
    }

    // MARK: - Menu Actions

    @objc private func refreshTasksAction() {
        refreshTasks()
    }

    @objc private func openQuickEntry() {
        print("📝 MenuBarController: Opening quick entry...")
        showWindow(
            content: QuickEntryView(),
            title: "New Task",
            size: NSSize(width: 400, height: 200),
            window: &quickEntryWindow
        )
    }

    @objc private func openBrainDump() {
        showBrainDump()
    }

    @objc private func openSmartSurface() {
        showSmartSurface()
    }

    @objc private func openDashboard() {
        showDashboard()
    }

    @objc private func openNotionTasks() {
        print("📋 MenuBarController: Opening Notion Tasks...")
        // Opens Notion app with the Tasks database
        // Using Notion's URL scheme - the Tasks database will open
        if let url = URL(string: "notion://www.notion.so") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openPreferences() {
        print("⚙️ MenuBarController: Opening preferences...")
        showWindow(
            content: PreferencesView(),
            title: "TomOS Preferences",
            size: NSSize(width: 450, height: 300),
            window: &quickEntryWindow
        )
    }

    @objc private func openTaskDetail(_ sender: NSMenuItem) {
        guard let task = sender.representedObject as? MenuBarTask else { return }
        print("📋 MenuBarController: Opening task: \(task.title)")

        // For now, open the dashboard to the task
        showDashboard()
    }

    @objc private func quitApp() {
        print("👋 MenuBarController: Quitting app...")
        GlobalShortcutManager.shared.unregisterShortcuts()
        NSApplication.shared.terminate(nil)
    }

    @objc private func sendMorningOverviewAction() {
        sendMorningOverview()
    }

    @objc private func sendEODSummaryAction() {
        sendEODSummary()
    }

    // MARK: - Public API for Global Shortcuts

    /// Shows the Brain Dump window (called by GlobalShortcutManager)
    func showBrainDump() {
        print("🧠 MenuBarController: Opening brain dump...")
        showWindow(
            content: BrainDumpView(),
            title: "Brain Dump",
            size: NSSize(width: 500, height: 500),
            window: &brainDumpWindow
        )
    }

    /// Shows the Smart Surface window (called by GlobalShortcutManager)
    func showSmartSurface() {
        print("💭 MenuBarController: Opening smart surface...")
        showWindow(
            content: SmartSurfaceView(),
            title: "What Should I Work On?",
            size: NSSize(width: 600, height: 700),
            window: &smartSurfaceWindow
        )
    }

    /// Shows the Dashboard window (called by GlobalShortcutManager)
    func showDashboard() {
        print("📊 MenuBarController: Opening dashboard...")
        showWindow(
            content: ContentView(),
            title: "TomOS Dashboard",
            size: NSSize(width: 800, height: 600),
            window: &dashboardWindow
        )
    }

    /// Programmatically shows the menu bar dropdown (called by GlobalShortcutManager)
    func showMenuDropdown() {
        print("📋 MenuBarController: Showing menu dropdown...")
        guard let button = statusItem?.button else {
            print("❌ MenuBarController: No status item button available")
            return
        }

        // Perform click on the status item button to show menu
        button.performClick(nil)
    }

    /// Sends the morning overview notification
    func sendMorningOverview() {
        print("📨 MenuBarController: Sending morning overview...")

        Task {
            do {
                try await APIService.shared.sendMorningOverview()
                await MainActor.run {
                    self.showNotification(title: "Morning Overview", body: "Check your notifications!")
                }
                print("✅ MenuBarController: Morning overview sent")
            } catch {
                print("❌ MenuBarController: Failed to send morning overview: \(error)")
                await MainActor.run {
                    self.showNotification(title: "Error", body: "Failed to send morning overview")
                }
            }
        }
    }

    /// Sends the EOD summary notification
    func sendEODSummary() {
        print("📨 MenuBarController: Sending EOD summary...")

        Task {
            do {
                try await APIService.shared.sendEODSummary()
                await MainActor.run {
                    self.showNotification(title: "EOD Summary", body: "Check your notifications!")
                }
                print("✅ MenuBarController: EOD summary sent")
            } catch {
                print("❌ MenuBarController: Failed to send EOD summary: \(error)")
                await MainActor.run {
                    self.showNotification(title: "Error", body: "Failed to send EOD summary")
                }
            }
        }
    }

    /// Shows a local notification
    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ MenuBarController: Failed to show notification: \(error)")
            }
        }
    }

    // MARK: - Window Management

    /// Shows a SwiftUI view in a new or existing window
    private func showWindow<Content: View>(
        content: Content,
        title: String,
        size: NSSize,
        window: inout NSWindow?
    ) {
        // Close existing window if different content
        // Stop any animations before closing to prevent use-after-free crashes
        if let existingWindow = window {
            existingWindow.animator().alphaValue = existingWindow.alphaValue // Cancel animations
            existingWindow.close()
        }

        // Create hosting controller for SwiftUI view
        let hostingController = NSHostingController(rootView: content)

        // Create window
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        newWindow.title = title
        newWindow.contentViewController = hostingController
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)

        // Activate the app to bring window to front
        NSApplication.shared.activate(ignoringOtherApps: true)

        window = newWindow
    }

    // MARK: - Cleanup

    /// Removes the menu bar icon and unregisters shortcuts. Call when app is terminating.
    func cleanup() {
        // Unregister global shortcuts
        GlobalShortcutManager.shared.unregisterShortcuts()

        // Remove status item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        menu = nil

        print("🧹 MenuBarController: Cleanup complete")
    }
}

// MARK: - Menu Bar Task Model

/// Represents a task shown in the menu bar dropdown
struct MenuBarTask {
    let id: String
    let title: String
    let priority: String
    let reason: String

    /// Returns the appropriate emoji icon for the priority
    var priorityIcon: String {
        switch priority.lowercased() {
        case "urgent": return "🔴"
        case "important": return "🟡"
        case "high": return "🟠"
        case "low": return "🔵"
        default: return "⚪"
        }
    }
}

// MARK: - Quick Entry View

/// A minimal view for quick task entry from the menu bar
struct QuickEntryView: View {
    @State private var taskText = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Quick Task Entry")
                .font(.headline)

            TextField("Enter task...", text: $taskText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    submitTask()
                }

            HStack {
                Button("Cancel") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(action: submitTask) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Create Task")
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(taskText.isEmpty || isLoading)
            }
        }
        .padding()
        .frame(minWidth: 350)
        .alert("Task Created!", isPresented: $showSuccess) {
            Button("OK") {
                taskText = ""
                NSApplication.shared.keyWindow?.close()
            }
        }
    }

    private func submitTask() {
        guard !taskText.isEmpty else { return }
        isLoading = true

        Task {
            do {
                _ = try await APIService.shared.batchImport(tasks: taskText)
                await MainActor.run {
                    isLoading = false
                    showSuccess = true
                    MenuBarController.shared.refreshTasks()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ Failed to create task: \(error)")
                }
            }
        }
    }
}

// MARK: - Preferences View

/// Preferences view for macOS showing system status
struct PreferencesView: View {
    @State private var apnsStatus: APNsStatus = .checking
    @State private var notificationStatus: String = "Checking..."

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.purple)
                Text("TomOS Preferences")
                    .font(.title2.bold())
            }

            Divider()

            // APNs Status Section
            GroupBox("Push Notifications (APNs)") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Circle()
                            .fill(apnsStatus.color)
                            .frame(width: 10, height: 10)
                        Text("Device Registration")
                            .fontWeight(.medium)
                        Spacer()
                        Text(apnsStatus.description)
                            .foregroundStyle(apnsStatus == .registered ? .green : .secondary)
                    }

                    HStack {
                        Circle()
                            .fill(notificationStatus == "Authorized" ? .green : .orange)
                            .frame(width: 10, height: 10)
                        Text("Notification Permission")
                            .fontWeight(.medium)
                        Spacer()
                        Text(notificationStatus)
                            .foregroundStyle(notificationStatus == "Authorized" ? .green : .orange)
                    }

                    if apnsStatus == .notRegistered {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Device not registered. Restart app to retry.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if apnsStatus == .registered {
                        if let token = UserDefaults.standard.string(forKey: "apns_device_token_macos") {
                            HStack {
                                Text("Token:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(token.prefix(16)) + "...")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // System Info
            GroupBox("System Information") {
                VStack(spacing: 8) {
                    HStack {
                        Text("API Endpoint")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("tomos-task-api.vercel.app")
                            .font(.system(.caption, design: .monospaced))
                    }

                    HStack {
                        Text("Platform")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("macOS")
                    }

                    HStack {
                        Text("Build Version")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
                    }

                    HStack {
                        Text("App Version")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()

            // Keyboard Shortcuts Reference
            GroupBox("Keyboard Shortcuts") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Use ⌘⌥ (Command+Option) + key:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("T: Quick Capture  •  1: Brain Dump  •  2: What Next?")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("3: Morning  •  4: EOD  •  5: Dashboard  •  Q: Quit")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(minWidth: 450, minHeight: 380)
        .onAppear {
            checkAPNsStatus()
            checkNotificationPermission()
        }
    }

    private func checkAPNsStatus() {
        if let token = UserDefaults.standard.string(forKey: "apns_device_token_macos"), !token.isEmpty {
            apnsStatus = .registered
        } else {
            apnsStatus = .notRegistered
        }
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    notificationStatus = "Authorized"
                case .denied:
                    notificationStatus = "Denied"
                case .notDetermined:
                    notificationStatus = "Not Requested"
                case .provisional:
                    notificationStatus = "Provisional"
                case .ephemeral:
                    notificationStatus = "Ephemeral"
                @unknown default:
                    notificationStatus = "Unknown"
                }
            }
        }
    }
}

enum APNsStatus {
    case checking
    case registered
    case notRegistered

    var description: String {
        switch self {
        case .checking: return "Checking..."
        case .registered: return "Registered"
        case .notRegistered: return "Not Registered"
        }
    }

    var color: Color {
        switch self {
        case .checking: return .gray
        case .registered: return .green
        case .notRegistered: return .orange
        }
    }
}

#endif
