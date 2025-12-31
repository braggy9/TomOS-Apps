import SwiftUI

struct QuickActionsView: View {
    @State private var isLoadingMorning = false
    @State private var isLoadingEOD = false
    @State private var showSuccess = false
    @State private var successMessage = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: sendMorningOverview) {
                        HStack {
                            Image(systemName: "sunrise.fill")
                                .foregroundColor(.orange)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Send Morning Overview")
                                    .font(.headline)

                                Text("Daily task overview and AI-powered advice")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if isLoadingMorning {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoadingMorning)

                    Button(action: sendEODSummary) {
                        HStack {
                            Image(systemName: "moon.fill")
                                .foregroundColor(.purple)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Send EOD Summary")
                                    .font(.headline)

                                Text("Reflect on today and preview tomorrow")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if isLoadingEOD {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoadingEOD)
                } header: {
                    Text("Notifications")
                }

                Section {
                    Button(action: { APIService.shared.openDashboard() }) {
                        HStack {
                            Image(systemName: "safari")
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Open Dashboard")
                                    .font(.headline)

                                Text("View all tasks in web interface")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Web Access")
                }

                Section {
                    Button(action: scheduleTestNotification) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.green)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Test Local Notification")
                                    .font(.headline)

                                Text("Fires in 2 minutes with action buttons")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }

                    Button(action: listScheduledNotifications) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundColor(.orange)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("List Scheduled Notifications")
                                    .font(.headline)

                                Text("Debug: prints to console")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }

                    Button(action: cancelAllNotifications) {
                        HStack {
                            Image(systemName: "bell.slash")
                                .foregroundColor(.red)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cancel All Notifications")
                                    .font(.headline)

                                Text("Clear all scheduled reminders")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                } header: {
                    Text("Developer Tools")
                } footer: {
                    Text("Test notifications use the TASK_NOTIFICATION category with Complete, Snooze, and View action buttons.")
                }

                Section {
                    HStack {
                        Text("API Endpoint")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("tomos-task-api.vercel.app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Notification Topic")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("tomos-tasks-*")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("System Info")
                }
            }
            .navigationTitle("Quick Actions")
            .alert("Success!", isPresented: $showSuccess) {
                Button("OK") { }
            } message: {
                Text(successMessage)
            }
        }
    }

    func sendMorningOverview() {
        isLoadingMorning = true

        Task {
            do {
                try await APIService.shared.sendMorningOverview()
                await MainActor.run {
                    isLoadingMorning = false
                    successMessage = "Morning overview sent! Check your phone 📱"
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoadingMorning = false
                    successMessage = "Failed to send morning overview"
                    showSuccess = true
                }
            }
        }
    }

    func sendEODSummary() {
        isLoadingEOD = true

        Task {
            do {
                try await APIService.shared.sendEODSummary()
                await MainActor.run {
                    isLoadingEOD = false
                    successMessage = "EOD summary sent! Check your phone 📱"
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoadingEOD = false
                    successMessage = "Failed to send EOD summary"
                    showSuccess = true
                }
            }
        }
    }

    // MARK: - Developer Tools

    /// Schedules a test notification that fires in 2 minutes
    func scheduleTestNotification() {
        // Schedule notification for 2 minutes (120 seconds) from now
        NotificationManager.shared.scheduleTestNotification(
            after: 120,  // 2 minutes
            title: "Review quarterly report"
        )

        successMessage = "Test notification scheduled!\nWill fire in 2 minutes.\nMinimize the app to see it."
        showSuccess = true
    }

    /// Lists all scheduled notifications to the console
    func listScheduledNotifications() {
        NotificationManager.shared.debugPrintScheduledNotifications()
        successMessage = "Check Xcode console for scheduled notifications list"
        showSuccess = true
    }

    /// Cancels all scheduled notifications
    func cancelAllNotifications() {
        NotificationManager.shared.cancelAllReminders()
        successMessage = "All scheduled notifications canceled"
        showSuccess = true
    }
}

#Preview {
    QuickActionsView()
}
