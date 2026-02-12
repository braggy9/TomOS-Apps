//
//  CreateNoteView.swift
//  TomOS
//
//  Phase 2: Notes Feature - Quick blank note creation form
//

import SwiftUI

struct CreateNoteView: View {
    @State private var title = ""
    @State private var content = ""
    @State private var tags: [String] = []
    @State private var priority = "medium"
    @State private var confidential = false
    @State private var isCreating = false
    @State private var toast: Toast?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Basic section
                Section("Basic Information") {
                    TextField("Title", text: $title)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $content)
                            .frame(minHeight: 150)
                            #if os(iOS)
                            .scrollContentBackground(.hidden)
                            #endif

                        Text("Markdown supported")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Properties section
                Section("Properties") {
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                        Text("Urgent").tag("urgent")
                    }

                    Toggle("Confidential", isOn: $confidential)
                }

                // TODO: Add tags section with proper TagPicker component
            }
            .navigationTitle("New Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Create") {
                        createNote()
                    }
                    .disabled(!isFormValid || isCreating)
                }
            }
            .toast($toast)
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Create Method

    private func createNote() {
        isCreating = true

        Task {
            do {
                let note = try await APIService.shared.createNote(
                    title: title,
                    content: content,
                    tags: tags,
                    priority: priority,
                    confidential: confidential
                )

                // Add to cache
                await TaskCache.shared.addNote(note)

                await MainActor.run {
                    self.isCreating = false
                    NotificationCenter.default.post(name: .notesCreated, object: nil)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.toast = .error("Failed to create note: \(error.localizedDescription)")
                    self.isCreating = false
                }
            }
        }
    }
}

// MARK: - Tag Chip Component

struct NoteTagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DesignSystem.Colors.brand.primary.opacity(0.1))
        .foregroundStyle(DesignSystem.Colors.brand.primary)
        .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    CreateNoteView()
}
