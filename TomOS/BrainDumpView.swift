import SwiftUI

struct BrainDumpView: View {
    @State private var tasksText = ""
    @State private var selectedTags: Set<String> = []
    @State private var showTagPicker = false
    @State private var isLoading = false
    @State private var toast: Toast?
    @FocusState private var isTextEditorFocused: Bool
    @StateObject private var tagService = TagService()

    var suggestedTags: [Tag] {
        guard !tasksText.isEmpty else { return [] }
        return tagService.suggestTags(for: tasksText, context: nil)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple.gradient)

                    Text("Brain Dump")
                        .font(.title.bold())

                    Text("Dump all your tasks - I'll parse them into organized Notion tasks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // Examples
                VStack(alignment: .leading, spacing: 8) {
                    Text("Examples:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Text("• call dentist tomorrow\n• review contract #urgent @john\n• prep slides friday")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Text Editor
                ZStack(alignment: .topLeading) {
                    if tasksText.isEmpty {
                        Text("dentist tomorrow 2pm\nreview contract #urgent\nprep slides friday...")
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                    }

                    TextEditor(text: $tasksText)
                        .frame(minHeight: 200)
                        .padding(4)
                        .background(Color.secondarySystemBackground)
                        .cornerRadius(8)
                        .focused($isTextEditorFocused)
                }
                .padding(.horizontal)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isTextEditorFocused = false
                        }
                        .fontWeight(.semibold)
                    }
                }

                // Selected Tags Display
                if !selectedTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        SelectedTagsView(selectedTags: $selectedTags)
                            .padding(.horizontal)
                    }
                }

                // Tag Picker Button
                Button {
                    showTagPicker = true
                } label: {
                    HStack {
                        Image(systemName: "tag")
                        Text(selectedTags.isEmpty ? "Add Tags" : "Edit Tags (\(selectedTags.count))")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                // Submit Button
                Button(action: submitTasks) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                            Text("Create Tasks")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tasksText.isEmpty ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(tasksText.isEmpty || isLoading)
                .padding(.horizontal)

                Spacer()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toast($toast)
            .sheet(isPresented: $showTagPicker) {
                NavigationStack {
                    TagPickerView(
                        selectedTags: $selectedTags,
                        suggestedTags: suggestedTags
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

    func submitTasks() {
        isLoading = true
        isTextEditorFocused = false // Dismiss keyboard

        Task {
            do {
                // Parse tasks from text (split by newlines)
                let taskLines = tasksText
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                var successCount = 0

                // Create each task with selected tags
                for taskLine in taskLines {
                    _ = try await APIService.shared.createTask(
                        task: taskLine,
                        tags: Array(selectedTags),
                        context: nil
                    )
                    successCount += 1
                }

                await MainActor.run {
                    isLoading = false

                    // Show success toast
                    withAnimation {
                        toast = .success("Created \(successCount) task\(successCount == 1 ? "" : "s")!")
                    }

                    // Clear text and tags
                    tasksText = ""
                    selectedTags = []

                    // Notify Tasks View to refresh
                    NotificationCenter.default.post(name: .tasksCreated, object: nil)

                    // Haptic feedback on success
                    #if os(iOS)
                    HapticManager.shared.taskAdded()
                    #endif
                }
            } catch {
                print("❌ BrainDump: Task creation failed with error: \(error)")
                print("   Error details: \(String(describing: error))")

                await MainActor.run {
                    isLoading = false

                    // Show error toast with details
                    let errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
                    withAnimation {
                        toast = .error("Failed to create tasks: \(errorMessage)")
                    }

                    // Error haptic
                    #if os(iOS)
                    HapticManager.shared.error()
                    #endif
                }
            }
        }
    }
}

#Preview {
    BrainDumpView()
}
