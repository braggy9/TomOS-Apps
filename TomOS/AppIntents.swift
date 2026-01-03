import AppIntents
import SwiftUI

// MARK: - Add Task Intent

/// Siri Intent: "Add task [something] to TomOS"
/// Examples:
/// - "Hey Siri, add task buy milk to TomOS"
/// - "Hey Siri, TomOS add task call dentist tomorrow"
/// - "Hey Siri, add to TomOS review contract urgent"
@available(iOS 16.0, macOS 13.0, *)
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task to TomOS"
    static var description = IntentDescription("Quickly add a task to TomOS using natural language")

    /// The task text from Siri
    @Parameter(title: "Task", description: "What needs to be done?")
    var taskText: String

    /// Open app after creating task
    static var openAppWhenRun: Bool = false

    /// Siri phrases that trigger this intent
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$taskText) to TomOS")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard !taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .result(dialog: "Please tell me what task to add.")
        }

        do {
            let response = try await APIService.shared.batchImport(tasks: taskText)

            if response.success {
                return .result(dialog: "Added '\(taskText)' to TomOS")
            } else {
                return .result(dialog: "Couldn't add the task. Please try again.")
            }
        } catch {
            return .result(dialog: "Failed to add task: \(error.localizedDescription)")
        }
    }
}

// MARK: - Brain Dump Intent

/// Siri Intent: "Brain dump in TomOS" - Opens the brain dump view
@available(iOS 16.0, macOS 13.0, *)
struct OpenBrainDumpIntent: AppIntent {
    static var title: LocalizedStringResource = "Brain Dump"
    static var description = IntentDescription("Open TomOS Brain Dump to capture multiple tasks")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Post notification to open brain dump tab
        await MainActor.run {
            NotificationCenter.default.post(name: .openBrainDump, object: nil)
        }
        return .result()
    }
}

// MARK: - What Should I Work On Intent

/// Siri Intent: "What should I work on?" - Opens smart surface with AI recommendations
@available(iOS 16.0, macOS 13.0, *)
struct WhatShouldIWorkOnIntent: AppIntent {
    static var title: LocalizedStringResource = "What Should I Work On?"
    static var description = IntentDescription("Get AI-powered task recommendations from TomOS")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Post notification to open smart surface tab
        await MainActor.run {
            NotificationCenter.default.post(name: .openSmartSurface, object: nil)
        }
        return .result()
    }
}

// MARK: - Send Morning Overview Intent

/// Siri Intent: "Send morning overview" - Triggers the morning summary notification
@available(iOS 16.0, macOS 13.0, *)
struct SendMorningOverviewIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Morning Overview"
    static var description = IntentDescription("Send your TomOS morning task overview")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await APIService.shared.sendMorningOverview()
            return .result(dialog: "Morning overview sent! Check your notifications.")
        } catch {
            return .result(dialog: "Failed to send morning overview.")
        }
    }
}

// MARK: - Send EOD Summary Intent

/// Siri Intent: "Send end of day summary" - Triggers the EOD summary notification
@available(iOS 16.0, macOS 13.0, *)
struct SendEODSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Send EOD Summary"
    static var description = IntentDescription("Send your TomOS end of day summary")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await APIService.shared.sendEODSummary()
            return .result(dialog: "End of day summary sent! Check your notifications.")
        } catch {
            return .result(dialog: "Failed to send EOD summary.")
        }
    }
}

// MARK: - App Shortcuts Provider

/// Defines the shortcuts that appear in the Shortcuts app and Siri suggestions
@available(iOS 16.0, macOS 13.0, *)
struct TomOSShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Note: AddTaskIntent uses a String parameter which requires the user to speak the task
        // Siri will prompt for the task text if not provided
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task to \(.applicationName)",
                "Create task in \(.applicationName)",
                "New task in \(.applicationName)",
                "Quick add to \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: OpenBrainDumpIntent(),
            phrases: [
                "Brain dump in \(.applicationName)",
                "Open brain dump in \(.applicationName)",
                "Batch add tasks to \(.applicationName)"
            ],
            shortTitle: "Brain Dump",
            systemImageName: "brain.head.profile"
        )

        AppShortcut(
            intent: WhatShouldIWorkOnIntent(),
            phrases: [
                "What should I work on in \(.applicationName)",
                "Show priorities in \(.applicationName)",
                "What's next in \(.applicationName)"
            ],
            shortTitle: "What Should I Work On?",
            systemImageName: "target"
        )

        AppShortcut(
            intent: SendMorningOverviewIntent(),
            phrases: [
                "Send morning overview from \(.applicationName)",
                "Morning summary from \(.applicationName)"
            ],
            shortTitle: "Morning Overview",
            systemImageName: "sun.max.fill"
        )

        AppShortcut(
            intent: SendEODSummaryIntent(),
            phrases: [
                "Send end of day summary from \(.applicationName)",
                "EOD summary from \(.applicationName)"
            ],
            shortTitle: "EOD Summary",
            systemImageName: "moon.fill"
        )
    }
}

