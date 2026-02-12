//
//  TemplatePickerView.swift
//  TomOS
//
//  Phase 2: Notes Feature - Template selection with direct-create flow
//

import SwiftUI

struct TemplatePickerView: View {
    @State private var templates: [NoteTemplate] = []
    @State private var categorizedTemplates: [String: [NoteTemplate]] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var toast: Toast?

    // Navigation
    @State private var presentedNote: Note?
    @State private var isEditingNewNote = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading templates...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    // Error state
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text("Failed to load templates")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            loadTemplates()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Template list
                    List {
                        ForEach(sortedCategories, id: \.self) { category in
                            Section(header: Text(category.capitalized).font(.headline)) {
                                ForEach(categorizedTemplates[category] ?? []) { template in
                                    TemplateRow(template: template) {
                                        createNoteFromTemplate(template)
                                    }
                                }
                            }
                        }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #else
                    .listStyle(.inset)
                    #endif
                }
            }
            .navigationTitle("Choose Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .toast($toast)
            .sheet(item: $presentedNote) { note in
                NavigationStack {
                    NoteDetailView(noteId: note.id)
                        .onAppear {
                            if isEditingNewNote {
                                // Automatically enter edit mode for new notes
                                isEditingNewNote = false
                            }
                        }
                }
            }
        }
        .onAppear {
            if templates.isEmpty {
                loadTemplates()
            }
        }
    }

    // MARK: - Sorted Categories

    private var sortedCategories: [String] {
        categorizedTemplates.keys.sorted()
    }

    // MARK: - Data Methods

    private func loadTemplates() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let templateData = try await APIService.shared.getNoteTemplates()

                await MainActor.run {
                    self.templates = templateData.templates
                    self.categorizedTemplates = templateData.categorized
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

    private func createNoteFromTemplate(_ template: NoteTemplate) {
        isLoading = true
        toast = nil

        Task {
            do {
                // Create with timestamped default title
                let defaultTitle = "\(template.name) - \(Date().formatted(date: .abbreviated, time: .omitted))"
                let note = try await APIService.shared.createNoteFromTemplate(
                    templateId: template.id,
                    title: defaultTitle
                )

                // Add to cache
                await TaskCache.shared.addNote(note)

                await MainActor.run {
                    // Navigate to note detail in edit mode
                    self.presentedNote = note
                    self.isEditingNewNote = true
                    self.isLoading = false

                    // Dismiss template picker after navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }

                    // Notify that note was created
                    NotificationCenter.default.post(name: .notesCreated, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.toast = .error("Failed to create note: \(error.localizedDescription)")
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Template Row Component

struct TemplateRow: View {
    let template: NoteTemplate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Text(template.icon)
                    .font(.title2)
                    .frame(width: 40)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(template.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Suggested tags preview (first 2)
                if !template.suggestedTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(template.suggestedTags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.brand.primary.opacity(0.1))
                                .foregroundStyle(DesignSystem.Colors.brand.primary)
                                .cornerRadius(4)
                        }

                        // More indicator
                        if template.suggestedTags.count > 2 {
                            Text("+\(template.suggestedTags.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    TemplatePickerView()
}
