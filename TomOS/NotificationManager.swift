import Foundation
import UserNotifications

/// NotificationManager handles scheduling and managing local notifications for task reminders.
///
/// ## How Local Notifications Work:
/// Unlike push notifications (sent from a server), local notifications are scheduled
/// entirely on-device. The app tells iOS "show this notification at this time" and
/// iOS handles the rest - even if the app is closed or the device is locked.
///
/// ## Notification Flow:
/// 1. App schedules notification with `UNUserNotificationCenter.add()`
/// 2. iOS stores the request and waits until trigger time
/// 3. At trigger time, iOS shows the notification (banner, sound, badge)
/// 4. User interacts → AppDelegate.didReceive is called (same as push notifications!)
///
/// ## Key Concepts:
/// - **UNNotificationRequest**: The notification to be delivered (content + trigger)
/// - **UNNotificationContent**: What to show (title, body, sound, badge, userInfo)
/// - **UNNotificationTrigger**: When to show it (time interval, calendar date, or location)
/// - **Identifier**: Unique string to track/cancel specific notifications
///
/// ## Usage Example:
/// ```swift
/// // Schedule a reminder for a task
/// NotificationManager.shared.scheduleTaskReminder(
///     taskId: "notion-page-123",
///     title: "Review contract",
///     dueDate: Date().addingTimeInterval(3600), // 1 hour from now
///     priority: "urgent"
/// )
///
/// // Cancel when task is completed
/// NotificationManager.shared.cancelTaskReminder(taskId: "notion-page-123")
/// ```
///
class NotificationManager {

    // MARK: - Singleton

    /// Shared instance for app-wide notification management
    static let shared = NotificationManager()

    private init() {
        print("📅 NotificationManager: Initialized")
    }

    // MARK: - Constants

    /// Timezone for all date calculations (Sydney, Australia)
    private let timezone = TimeZone(identifier: "Australia/Sydney")!

    /// Prefix for notification identifiers to easily identify our notifications
    private let notificationPrefix = "tomos-task-"

    /// How many minutes before due time to send the reminder
    private let reminderMinutesBefore: TimeInterval = 60 // 1 hour = 60 minutes

    // MARK: - Schedule Task Reminder

    /// Schedules a local notification to remind the user about a task.
    ///
    /// The notification is scheduled for 1 hour before the task's due time.
    /// It uses the TASK_NOTIFICATION category which provides action buttons
    /// (Complete, Snooze, View) defined in AppDelegate.
    ///
    /// - Parameters:
    ///   - taskId: The Notion page ID (used to cancel/update later)
    ///   - title: The task title to display
    ///   - dueDate: When the task is due (notification fires 1 hour before)
    ///   - priority: Task priority ("urgent", "important", "low", etc.)
    /// - Returns: True if scheduled successfully, false otherwise
    @discardableResult
    func scheduleTaskReminder(
        taskId: String,
        title: String,
        dueDate: Date,
        priority: String? = nil
    ) -> Bool {
        // Calculate reminder time (1 hour before due)
        let reminderDate = dueDate.addingTimeInterval(-reminderMinutesBefore * 60)

        // Don't schedule if reminder time is in the past
        guard reminderDate > Date() else {
            print("⚠️ NotificationManager: Skipping reminder for '\(title)' - reminder time is in the past")
            print("   Due: \(formatDate(dueDate)), Reminder would be: \(formatDate(reminderDate))")
            return false
        }

        print("📅 NotificationManager: Scheduling reminder for task '\(title)'")
        print("   Task ID: \(taskId)")
        print("   Due Date: \(formatDate(dueDate))")
        print("   Reminder: \(formatDate(reminderDate))")
        print("   Priority: \(priority ?? "none")")

        // Build notification content
        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: priority)
        content.body = title
        content.sound = .default
        content.categoryIdentifier = AppDelegate.taskNotificationCategory

        // Attach task data to the notification
        // This is retrieved in AppDelegate.didReceive when user interacts
        content.userInfo = [
            "task_id": taskId,
            "task_title": title,
            "priority": priority ?? "",
            "type": "reminder",
            "due_date": ISO8601DateFormatter().string(from: dueDate)
        ]

        // Set badge to increment (we'll manage this more precisely later)
        // Note: iOS doesn't support "increment by 1" directly, so we set a value
        // In production, we'd track pending notifications and set badge accordingly
        content.badge = 1

        // Create calendar-based trigger using Sydney timezone
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let dateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminderDate
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )

        // Create the notification request with unique identifier
        let identifier = notificationIdentifier(for: taskId)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        // Schedule with the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ NotificationManager: Failed to schedule notification")
                print("   Error: \(error.localizedDescription)")
            } else {
                print("✅ NotificationManager: Notification scheduled successfully")
                print("   Identifier: \(identifier)")
            }
        }

        return true
    }

    // MARK: - Schedule Immediate Test Notification

    /// Schedules a test notification for debugging purposes.
    /// Fires after the specified number of seconds.
    ///
    /// - Parameters:
    ///   - seconds: How many seconds until the notification fires
    ///   - title: Optional custom title
    /// - Returns: The notification identifier
    @discardableResult
    func scheduleTestNotification(after seconds: TimeInterval = 5, title: String = "Test Task") -> String {
        let testTaskId = "test-\(UUID().uuidString.prefix(8))"

        print("🧪 NotificationManager: Scheduling TEST notification")
        print("   Fires in: \(Int(seconds)) seconds")

        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Reminder"
        content.body = title
        content.sound = .default
        content.categoryIdentifier = AppDelegate.taskNotificationCategory
        content.badge = 1

        content.userInfo = [
            "task_id": testTaskId,
            "task_title": title,
            "type": "test",
            "priority": "normal"
        ]

        // Use time interval trigger for testing
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: seconds,
            repeats: false
        )

        let identifier = notificationIdentifier(for: testTaskId)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ NotificationManager: Failed to schedule test notification")
                print("   Error: \(error.localizedDescription)")
            } else {
                print("✅ NotificationManager: Test notification scheduled!")
                print("   Identifier: \(identifier)")
                print("   Will fire at: \(self.formatDate(Date().addingTimeInterval(seconds)))")
            }
        }

        return identifier
    }

    // MARK: - Cancel Notifications

    /// Cancels a scheduled notification for a specific task.
    /// Call this when a task is completed or deleted.
    ///
    /// - Parameter taskId: The Notion page ID of the task
    func cancelTaskReminder(taskId: String) {
        let identifier = notificationIdentifier(for: taskId)

        print("🗑️ NotificationManager: Canceling notification for task: \(taskId)")
        print("   Identifier: \(identifier)")

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )

        // Also remove from delivered notifications (in case it's showing)
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [identifier]
        )

        print("✅ NotificationManager: Notification canceled")
    }

    /// Cancels all scheduled task reminders.
    /// Useful for "clear all" functionality or logout.
    func cancelAllReminders() {
        print("🗑️ NotificationManager: Canceling ALL scheduled notifications")

        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            // Filter to only our notifications (those with our prefix)
            let ourIdentifiers = requests
                .filter { $0.identifier.hasPrefix(self.notificationPrefix) }
                .map { $0.identifier }

            print("   Found \(ourIdentifiers.count) TomOS notifications to cancel")

            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ourIdentifiers
            )

            // Also clear delivered
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: ourIdentifiers
            )

            print("✅ NotificationManager: All notifications canceled")
        }
    }

    // MARK: - List Scheduled Notifications

    /// Lists all pending (scheduled but not yet delivered) notifications.
    /// Useful for debugging and displaying scheduled reminders in the UI.
    ///
    /// - Parameter completion: Called with array of pending notification info
    func listScheduledNotifications(completion: @escaping ([ScheduledNotificationInfo]) -> Void) {
        print("📋 NotificationManager: Listing scheduled notifications...")

        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let notifications = requests.compactMap { request -> ScheduledNotificationInfo? in
                // Only include our notifications
                guard request.identifier.hasPrefix(self.notificationPrefix) else {
                    return nil
                }

                // Extract trigger date
                var fireDate: Date? = nil
                if let calendarTrigger = request.trigger as? UNCalendarNotificationTrigger {
                    fireDate = calendarTrigger.nextTriggerDate()
                } else if let intervalTrigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    fireDate = intervalTrigger.nextTriggerDate()
                }

                return ScheduledNotificationInfo(
                    identifier: request.identifier,
                    taskId: request.content.userInfo["task_id"] as? String ?? "unknown",
                    title: request.content.body,
                    fireDate: fireDate,
                    priority: request.content.userInfo["priority"] as? String
                )
            }

            print("   Found \(notifications.count) scheduled notifications:")
            for notification in notifications {
                print("   - \(notification.title) → \(notification.fireDate.map { self.formatDate($0) } ?? "unknown")")
            }

            DispatchQueue.main.async {
                completion(notifications)
            }
        }
    }

    /// Prints all scheduled notifications to console (for debugging)
    func debugPrintScheduledNotifications() {
        listScheduledNotifications { notifications in
            print("\n📋 === SCHEDULED NOTIFICATIONS ===")
            if notifications.isEmpty {
                print("   (none)")
            } else {
                for (index, notification) in notifications.enumerated() {
                    print("   \(index + 1). \(notification.title)")
                    print("      ID: \(notification.identifier)")
                    print("      Task: \(notification.taskId)")
                    print("      Fire: \(notification.fireDate.map { self.formatDate($0) } ?? "unknown")")
                    print("      Priority: \(notification.priority ?? "none")")
                }
            }
            print("=================================\n")
        }
    }

    // MARK: - Update Notification

    /// Updates an existing notification with new details.
    /// This cancels the old notification and schedules a new one.
    ///
    /// - Parameters:
    ///   - taskId: The task to update
    ///   - title: New task title
    ///   - dueDate: New due date
    ///   - priority: New priority
    func updateTaskReminder(
        taskId: String,
        title: String,
        dueDate: Date,
        priority: String? = nil
    ) {
        print("🔄 NotificationManager: Updating notification for task: \(taskId)")

        // Cancel existing notification
        cancelTaskReminder(taskId: taskId)

        // Schedule new one with updated details
        scheduleTaskReminder(
            taskId: taskId,
            title: title,
            dueDate: dueDate,
            priority: priority
        )
    }

    // MARK: - Permission Check

    /// Checks if the app has notification permissions.
    /// - Parameter completion: Called with true if notifications are authorized
    func checkNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authorized = settings.authorizationStatus == .authorized
            print("🔐 NotificationManager: Notification permission: \(authorized ? "granted" : "denied")")
            DispatchQueue.main.async {
                completion(authorized)
            }
        }
    }

    // MARK: - Helper Functions

    /// Generates a unique notification identifier for a task.
    private func notificationIdentifier(for taskId: String) -> String {
        return "\(notificationPrefix)\(taskId)"
    }

    /// Returns the appropriate notification title based on priority.
    private func notificationTitle(for priority: String?) -> String {
        guard let priority = priority?.lowercased() else {
            return "📋 Task Reminder"
        }

        switch priority {
        case "urgent":
            return "🔴 Urgent Task"
        case "important":
            return "🟡 Important Task"
        case "high":
            return "🟠 High Priority"
        case "low":
            return "🔵 Task Reminder"
        default:
            return "📋 Task Reminder"
        }
    }

    /// Formats a date for logging using Sydney timezone.
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = timezone
        return formatter.string(from: date) + " AEDT"
    }
}

// MARK: - Scheduled Notification Info

/// Information about a scheduled notification (for listing/debugging)
struct ScheduledNotificationInfo {
    let identifier: String
    let taskId: String
    let title: String
    let fireDate: Date?
    let priority: String?
}

// MARK: - Convenience Extensions

extension NotificationManager {

    /// Schedules a reminder from task data received from the API.
    ///
    /// Example usage in BrainDumpView after creating a task:
    /// ```swift
    /// // After successfully creating a task
    /// if let dueDate = parsedTask.dueDate {
    ///     NotificationManager.shared.scheduleFromAPIResponse(
    ///         taskId: response.notionPageId,
    ///         title: parsedTask.title,
    ///         dueDateString: dueDate,
    ///         priority: parsedTask.priority
    ///     )
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - taskId: The Notion page ID from API response
    ///   - title: Task title
    ///   - dueDateString: Due date as ISO8601 string or "YYYY-MM-DD" format
    ///   - priority: Task priority
    func scheduleFromAPIResponse(
        taskId: String,
        title: String,
        dueDateString: String?,
        priority: String?
    ) {
        guard let dueDateString = dueDateString else {
            print("📅 NotificationManager: No due date provided, skipping reminder")
            return
        }

        // Try parsing as ISO8601 first
        if let date = ISO8601DateFormatter().date(from: dueDateString) {
            scheduleTaskReminder(taskId: taskId, title: title, dueDate: date, priority: priority)
            return
        }

        // Try parsing as simple date (YYYY-MM-DD)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timezone

        if let date = formatter.date(from: dueDateString) {
            // Set default time to 9:00 AM Sydney time if only date is provided
            var calendar = Calendar.current
            calendar.timeZone = timezone

            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 9
            components.minute = 0

            if let dateWithTime = calendar.date(from: components) {
                scheduleTaskReminder(taskId: taskId, title: title, dueDate: dateWithTime, priority: priority)
            }
            return
        }

        print("⚠️ NotificationManager: Could not parse due date: \(dueDateString)")
    }
}
