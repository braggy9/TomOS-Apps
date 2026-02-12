import SwiftUI

struct TaskDetailView: View {
    let taskItem: TaskItem
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var status: String
    @State private var priority: String
    @State private var selectedContext: Set<String>
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    @State private var selectedTags: Set<String>
    @State private var showTagPicker = false

    @State private var isSaving = false
    @State private var toast: Toast?
    @StateObject private var tagService = TagService()

    init(task: TaskItem) {
        self.taskItem = task
        _title = State(initialValue: task.title)
        _status = State(initialValue: task.status)
        _priority = State(initialValue: task.priority ?? "Someday")
        _selectedContext = State(initialValue: Set(task.context ?? []))

        // Parse due date if present
        if let dueDateString = task.dueDate {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dueDateString) {
                _dueDate = State(initialValue: date)
                _hasDueDate = State(initialValue: true)
            } else {
                _dueDate = State(initialValue: nil)
                _hasDueDate = State(initialValue: false)
            }
        } else {
            _dueDate = State(initialValue: nil)
            _hasDueDate = State(initialValue: false)
        }

        _selectedTags = State(initialValue: Set())
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title
                Section("Task") {
                    TextField("Title", text: $title)
                        .font(.body)
                }

                // Status
                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("Inbox").tag("Inbox")
                        Text("To Do").tag("To Do")
                        Text("In Progress").tag("In Progress")
                        Text("Done").tag("Done")
                    }
                    .pickerStyle(.segmented)
                }

                // Priority
                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        Text("Urgent").tag("Urgent")
                        Text("Important").tag("Important")
                        Text("Someday").tag("Someday")
                    }
                    .pickerStyle(.segmented)
                }

                // Context
                Section("Context") {
                    ForEach(["Work", "Client Projects", "Strategy", "Admin", "Legal Review"], id: \.self) { context in
                        Toggle(context, isOn: Binding(
                            get: { selectedContext.contains(context) },
                            set: { isSelected in
                                if isSelected {
                                    selectedContext.insert(context)
                                } else {
                                    selectedContext.remove(context)
                                }
                            }
                        ))
                    }
                }

                // Due Date
                Section("Due Date") {
                    Toggle("Has due date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker(
                            "Due",
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                // Tags
                Section("Tags") {
                    if !selectedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedTags), id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag)
                                            .font(.caption)
                                        Button {
                                            selectedTags.remove(tag)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(colorForTag(tag))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }

                    Button {
                        showTagPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "tag")
                            Text(selectedTags.isEmpty ? "Add Tags" : "Edit Tags (\(selectedTags.count))")
                        }
                    }
                }
            }
            .navigationTitle("Edit Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(isSaving || title.isEmpty)
                }
            }
            .toast($toast)
            .sheet(isPresented: $showTagPicker) {
                NavigationStack {
                    TagPickerView(
                        selectedTags: $selectedTags,
                        suggestedTags: tagService.suggestTags(for: title, context: nil)
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showTagPicker = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showTagPicker = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func saveTask() {
        isSaving = true

        Task {
            do {
                // Format due date if present
                let dueDateString: String? = if hasDueDate, let date = dueDate {
                    ISO8601DateFormatter().string(from: date)
                } else {
                    nil
                }

                try await APIService.shared.updateTask(
                    taskId: taskItem.id,
                    title: title != taskItem.title ? title : nil,
                    status: status != taskItem.status ? status : nil,
                    priority: priority != taskItem.priority ? priority : nil,
                    context: selectedContext.isEmpty ? nil : Array(selectedContext),
                    dueDate: dueDateString,
                    tags: selectedTags.isEmpty ? nil : Array(selectedTags)
                )

                await MainActor.run {
                    isSaving = false

                    #if os(iOS)
                    HapticManager.shared.taskAdded()
                    #endif

                    withAnimation {
                        toast = .success("Task updated!")
                    }

                    // Notify other views to refresh
                    NotificationCenter.default.post(name: .tasksCreated, object: nil)

                    // Dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false

                    #if os(iOS)
                    HapticManager.shared.error()
                    #endif

                    withAnimation {
                        toast = .error("Failed to update task")
                    }
                }
            }
        }
    }

    private func colorForTag(_ tag: String) -> Color {
        if tag.starts(with: "proj:") { return .blue }
        if tag.starts(with: "area:") { return .green }
        if tag.starts(with: "act:") { return .orange }
        if tag.starts(with: "topic:") { return .purple }
        return .gray
    }
}

#Preview {
    TaskDetailView(task: TaskItem(
        id: "123",
        title: "Sample Task",
        status: "To Do",
        priority: "Important",
        context: ["Work"],
        dueDate: nil
    ))
}
