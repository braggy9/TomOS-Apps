import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    static let tasksCreated = Notification.Name("tasksCreated")
}

// MARK: - Shared Models (Cross-platform)

enum TaskFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case quickWins = "Quick Wins"
    case all = "All"
    case inbox = "Inbox"
    case todo = "To Do"
    case inProgress = "In Progress"
    case done = "Done"

    var id: String { rawValue }

    /// SF Symbol icon for filter
    var icon: String {
        switch self {
        case .today: return "calendar.badge.clock"
        case .quickWins: return "bolt.fill"
        case .all: return "list.bullet"
        case .inbox: return "tray"
        case .todo: return "circle"
        case .inProgress: return "arrow.clockwise"
        case .done: return "checkmark.circle.fill"
        }
    }

    /// Helper text for filter
    var helpText: String? {
        switch self {
        case .quickWins: return "Low priority or undated To Do tasks"
        case .today: return "Due today, overdue, or urgent"
        default: return nil
        }
    }
}

// TaskItem is now defined in APIService.swift

// MARK: - Tasks View (Cross-platform)

/// Main tasks list view showing all tasks from Notion
struct TasksView: View {
    @State private var tasks: [TaskItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: TaskFilter = .all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(TaskFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if isLoading {
                    SkeletonTaskList()
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text("Failed to load tasks")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            fetchTasks()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredTasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: emptyStateIcon)
                            .font(.system(size: 48))
                            .foregroundStyle(emptyStateColor)
                        Text(emptyStateTitle)
                            .font(.headline)
                        Text(emptyStateMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredTasks) { task in
                            NavigationLink(destination: TaskDetailView(task: task)) {
                                // Task content - no status circle (completion is via swipe)
                                TaskContentView(task: task)
                                    .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    completeTask(task)
                                } label: {
                                    Label("Complete", systemImage: "checkmark.circle.fill")
                                }
                                .tint(.green)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshTasks()
                    }
                }
            }
            .navigationTitle("My Tasks")
            .toolbar {
                ToolbarItem(placement: toolbarPlacement) {
                    Button {
                        fetchTasks()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            fetchTasks()  // Always fetch (TaskCache handles smart caching)
        }
        .onReceive(NotificationCenter.default.publisher(for: .tasksCreated)) { _ in
            Task {
                await refreshTasks()
            }
        }
    }

    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .automatic
        #endif
    }

    private var filteredTasks: [TaskItem] {
        tasks.filter { task in
            switch selectedFilter {
            case .today:
                // Show tasks due today or overdue (and not done)
                guard task.status != "Done" else { return false }
                if let dueDate = task.dueDate {
                    return isDueToday(dueDate) || isPastDue(dueDate)
                }
                // Also show urgent tasks without due dates
                return task.priority?.lowercased() == "urgent"
            case .quickWins:
                // Show quick, low-complexity tasks (not done)
                guard task.status != "Done" else { return false }
                // Quick wins are: Low priority tasks OR tasks in To Do status with no due date
                // These are typically quick, low-stakes actions
                if task.priority?.lowercased() == "low" || task.priority?.lowercased() == "someday" {
                    return true
                }
                if task.status == "To Do" && task.dueDate == nil {
                    return true
                }
                return false
            case .all:
                return task.status != "Done"
            case .inbox:
                return task.status == "Inbox"
            case .todo:
                return task.status == "To Do"
            case .inProgress:
                return task.status == "In Progress"
            case .done:
                return task.status == "Done"
            }
        }
    }

    private var emptyStateIcon: String {
        switch selectedFilter {
        case .today: return "sun.max.fill"
        case .quickWins: return "bolt.fill"
        default: return "checkmark.circle"
        }
    }

    private var emptyStateColor: Color {
        switch selectedFilter {
        case .today: return .orange
        case .quickWins: return .yellow
        default: return .green
        }
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .today: return "Nothing due today!"
        case .quickWins: return "No quick wins available"
        default: return "No tasks"
        }
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .today:
            return "Great job! Check back later or switch to 'All' to see your full task list."
        case .quickWins:
            return "No quick wins available. These are low priority or undated To Do tasks - perfect for building momentum!"
        case .all:
            return "You're all caught up!"
        default:
            return "No \(selectedFilter.rawValue.lowercased()) tasks"
        }
    }

    private func fetchTasks() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Use TaskCache for better performance
                let fetchedTasks = try await TaskCache.shared.getTasks()
                await MainActor.run {
                    self.tasks = fetchedTasks
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func refreshTasks() async {
        do {
            // Force refresh from API
            let fetchedTasks = try await TaskCache.shared.getTasks(forceRefresh: true)
            await MainActor.run {
                self.tasks = fetchedTasks
            }
        } catch {
            print("❌ Failed to refresh tasks: \(error)")
        }
    }

    private func completeTask(_ task: TaskItem) {
        Task {
            do {
                // Optimistic update: remove from local cache immediately
                await TaskCache.shared.removeTask(id: task.id)
                await MainActor.run {
                    tasks.removeAll { $0.id == task.id }
                }

                #if os(iOS)
                HapticManager.shared.taskCompleted()
                #endif

                // Complete task on backend
                try await APIService.shared.completeTask(taskId: task.id)

                // Notify other views to refresh
                await MainActor.run {
                    NotificationCenter.default.post(name: .tasksCreated, object: nil)
                }
            } catch {
                print("❌ Failed to complete task: \(error)")
                // Show error feedback to user
                await MainActor.run {
                    withAnimation {
                        toast = .error("Failed to complete task")
                    }
                }
                // Revert optimistic update on error
                await refreshTasks()
            }
        }
    }

    private func isDueToday(_ dateString: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            // Fallback without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else { return false }
            return Calendar.current.isDateInToday(date)
        }

        return Calendar.current.isDateInToday(date)
    }

    private func isPastDue(_ dateString: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Task Content View

/// Task details view (used inside NavigationLink)
struct TaskContentView: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            Text(task.title)
                .font(.body)
                .strikethrough(task.status == "Done")
                .foregroundStyle(task.status == "Done" ? .secondary : .primary)

            // Metadata
            HStack(spacing: 8) {
                if let priority = task.priority, priority != "Someday" {
                    Label(priority, systemImage: priorityIcon(priority))
                        .font(.caption)
                        .foregroundStyle(priorityColor(priority))
                }

                if let context = task.context?.first {
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let dueDate = task.dueDate {
                    Text(formatDate(dueDate))
                        .font(.caption)
                        .foregroundStyle(isPastDue(dueDate) ? .red : .secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func priorityIcon(_ priority: String) -> String {
        DesignSystem.Colors.priority.icon(for: priority)
    }

    private func priorityColor(_ priority: String) -> Color {
        DesignSystem.Colors.priority.color(for: priority)
    }

    private func formatDate(_ dateString: String) -> String {
        // Configure ISO8601 formatter to handle milliseconds and timezone
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            // Fallback: try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatDateComponents(date)
        }

        return formatDateComponents(date)
    }

    private func formatDateComponents(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short // "2:00 PM"

        // Check for relative dates
        if calendar.isDateInToday(date) {
            return "Today \(timeFormatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(timeFormatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday \(timeFormatter.string(from: date))"
        }

        // Check if it's within this week
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let weekAhead = calendar.date(byAdding: .day, value: 7, to: now)!

        if date > weekAgo && date < weekAhead {
            // Show weekday + time (e.g., "Mon 2:00 PM")
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEE"
            return "\(weekdayFormatter.string(from: date)) \(timeFormatter.string(from: date))"
        }

        // Show date + time (e.g., "Dec 17, 2:00 PM")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        return "\(dateFormatter.string(from: date)), \(timeFormatter.string(from: date))"
    }

    private func isPastDue(_ dateString: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            // Fallback without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else { return false }
            return date < Calendar.current.startOfDay(for: Date())
        }

        return date < Calendar.current.startOfDay(for: Date())
    }
}

#Preview {
    TasksView()
}
