import SwiftUI

struct BrainDumpView: View {
    @State private var tasksText = ""
    @State private var isLoading = false
    @State private var toast: Toast?
    @FocusState private var isTextEditorFocused: Bool

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
        }
    }

    func submitTasks() {
        isLoading = true
        isTextEditorFocused = false // Dismiss keyboard

        Task {
            do {
                let response = try await APIService.shared.batchImport(tasks: tasksText)
                await MainActor.run {
                    isLoading = false

                    // Show success toast
                    let count = response.taskCount
                    withAnimation {
                        toast = .success("Created \(count) task\(count == 1 ? "" : "s")!")
                    }

                    // Clear text field
                    tasksText = ""

                    // Haptic feedback on success
                    #if os(iOS)
                    HapticManager.shared.taskAdded()
                    #endif
                }
            } catch {
                await MainActor.run {
                    isLoading = false

                    // Show error toast
                    withAnimation {
                        toast = .error("Failed to create tasks")
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
