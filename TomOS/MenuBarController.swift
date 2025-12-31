#if os(macOS)
import SwiftUI
import AppKit

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
/// │ ➕ New Task...              │
/// │ 🧠 Brain Dump               │
/// │ 💭 What Should I Work On?   │
/// ├─────────────────────────────┤
/// │ 📊 Open Dashboard           │
/// │ ⚙️  Preferences             │
/// ├─────────────────────────────┤
/// │ ❌ Quit TomOS               │
/// └─────────────────────────────┘
///
/// ## Architecture:
/// - Uses NSStatusItem for the menu bar icon
/// - NSMenu with NSMenuItem for the dropdown
/// - Integrates with existing SwiftUI views via NSWindow
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

        // Quick Actions
        let newTaskItem = NSMenuItem(title: "➕ New Task...", action: #selector(openQuickEntry), keyEquivalent: "n")
        newTaskItem.keyEquivalentModifierMask = [.command]
        newTaskItem.target = self
        menu?.addItem(newTaskItem)

        let brainDumpItem = NSMenuItem(title: "🧠 Brain Dump", action: #selector(openBrainDump), keyEquivalent: "b")
        brainDumpItem.keyEquivalentModifierMask = [.command]
        brainDumpItem.target = self
        menu?.addItem(brainDumpItem)

        let smartSurfaceItem = NSMenuItem(title: "💭 What Should I Work On?", action: #selector(openSmartSurface), keyEquivalent: "w")
        smartSurfaceItem.keyEquivalentModifierMask = [.command]
        smartSurfaceItem.target = self
        menu?.addItem(smartSurfaceItem)

        menu?.addItem(NSMenuItem.separator())

        // Dashboard & Preferences
        let dashboardItem = NSMenuItem(title: "📊 Open Dashboard", action: #selector(openDashboard), keyEquivalent: "d")
        dashboardItem.keyEquivalentModifierMask = [.command]
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

        let quitItem = NSMenuItem(title: "❌ Quit TomOS", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
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
        print("🧠 MenuBarController: Opening brain dump...")
        showWindow(
            content: BrainDumpView(),
            title: "Brain Dump",
            size: NSSize(width: 500, height: 500),
            window: &brainDumpWindow
        )
    }

    @objc private func openSmartSurface() {
        print("💭 MenuBarController: Opening smart surface...")
        showWindow(
            content: SmartSurfaceView(),
            title: "What Should I Work On?",
            size: NSSize(width: 600, height: 700),
            window: &dashboardWindow
        )
    }

    @objc private func openDashboard() {
        print("📊 MenuBarController: Opening dashboard...")
        showWindow(
            content: ContentView(),
            title: "TomOS Dashboard",
            size: NSSize(width: 800, height: 600),
            window: &dashboardWindow
        )
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
        // TODO: Implement deep linking to specific task
        openDashboard()
    }

    @objc private func quitApp() {
        print("👋 MenuBarController: Quitting app...")
        NSApplication.shared.terminate(nil)
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
        window?.close()

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

    /// Removes the menu bar icon. Call when app is terminating.
    func cleanup() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        menu = nil
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

/// Placeholder preferences view for macOS
struct PreferencesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("TomOS Preferences")
                .font(.title2)

            Text("Preferences coming soon...")
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Text("API Endpoint")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("tomos-task-api.vercel.app")
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Platform")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("macOS")
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 250)
    }
}

#endif
