import SwiftUI

// MARK: - Shared Models (Cross-platform)

enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case inbox = "Inbox"
    case todo = "To Do"
    case inProgress = "In Progress"
    case done = "Done"

    var id: String { rawValue }
}

struct TaskItem: Identifiable, Codable {
    let id: String
    let title: String
    let status: String
    let priority: String?
    let context: [String]?
    let dueDate: String?
}

// MARK: - iOS-Only Views

#if os(iOS)

/// Main tasks list view showing all tasks from Notion (iOS only)
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
                    ProgressView("Loading tasks...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("No tasks")
                            .font(.headline)
                        Text(selectedFilter == .all ? "You're all caught up!" : "No \(selectedFilter.rawValue.lowercased()) tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredTasks) { task in
                            TaskRow(task: task, onComplete: {
                                completeTask(task)
                            })
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        fetchTasks()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            if tasks.isEmpty {
                fetchTasks()
            }
        }
    }

    private var filteredTasks: [TaskItem] {
        tasks.filter { task in
            switch selectedFilter {
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

    private func fetchTasks() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let fetchedTasks = try await APIService.shared.getTasks()
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
            let fetchedTasks = try await APIService.shared.getTasks()
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
                try await APIService.shared.completeTask(taskId: task.id)

                #if os(iOS)
                HapticManager.shared.taskCompleted()
                #endif

                // Remove from list or refetch
                await MainActor.run {
                    tasks.removeAll { $0.id == task.id }
                }
            } catch {
                print("❌ Failed to complete task: \(error)")
            }
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: TaskItem
    let onComplete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Complete button
            Button {
                onComplete()
            } label: {
                Image(systemName: task.status == "Done" ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.status == "Done" ? .green : .gray)
            }
            .buttonStyle(.borderless)

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

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func priorityIcon(_ priority: String) -> String {
        switch priority {
        case "Urgent": return "exclamationmark.3"
        case "Important": return "exclamationmark.2"
        default: return "circle"
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "Urgent": return .red
        case "Important": return .orange
        default: return .secondary
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            return displayFormatter.string(from: date)
        }
    }

    private func isPastDue(_ dateString: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return false }
        return date < Date()
    }
}

#Preview {
    TasksView()
}
#endif
