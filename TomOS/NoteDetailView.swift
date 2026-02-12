//
//  NoteDetailView.swift
//  TomOS
//
//  Phase 2: Notes Feature - Detail view with read/edit modes and smart links
//

import SwiftUI

struct NoteDetailView: View {
    let noteId: String

    @State private var note: Note?
    @State private var backlinks: [Note] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var toast: Toast?

    // Edit mode
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var editedContent = ""
    @State private var editedTags: [String] = []
    @State private var editedPriority = "medium"
    @State private var editedStatus = "active"
    @State private var editedConfidential = false

    // Tabs
    @State private var selectedTab: NoteDetailTab = .content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading note...")
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
                    Text("Failed to load note")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        loadNoteDetails()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let note = note {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        noteHeader(note)

                        // Tabs (only if has links or backlinks)
                        if note.hasLinks || !backlinks.isEmpty {
                            Picker("Section", selection: $selectedTab) {
                                Text("Content").tag(NoteDetailTab.content)
                                if note.hasLinks {
                                    Text("Links (\(note.totalLinks))").tag(NoteDetailTab.links)
                                }
                                if !backlinks.isEmpty {
                                    Text("Backlinks (\(backlinks.count))").tag(NoteDetailTab.backlinks)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }

                        // Tab Content
                        switch selectedTab {
                        case .content:
                            contentSection(note)
                        case .links:
                            if note.hasLinks {
                                linksSection(note)
                            }
                        case .backlinks:
                            backlinksSection()
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle(isEditing ? "Edit Note" : "Note")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if isEditing {
                            Button("Cancel") {
                                cancelEditing()
                            }
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        if isEditing {
                            Button("Save") {
                                saveNote()
                            }
                            .disabled(!isFormValid)
                        } else {
                            HStack(spacing: 12) {
                                Button {
                                    startEditing(note)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                actionsMenu(note)
                            }
                        }
                    }
                }
            }
        }
        .toast($toast)
        .onAppear {
            if note == nil {
                loadNoteDetails()
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func noteHeader(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditing {
                // Edit mode - Title input
                TextField("Note title", text: $editedTitle)
                    .font(.title2.bold())
                    .textFieldStyle(.roundedBorder)
            } else {
                // Read mode - Title display
                Text(note.title)
                    .font(.title2.bold())
            }

            // Metadata badges
            HStack(spacing: 8) {
                // Priority badge
                HStack(spacing: 4) {
                    Image(systemName: note.priorityIcon)
                        .font(.caption2)
                    Text(note.priority.capitalized)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DesignSystem.Colors.priority.color(for: note.priority).opacity(0.2))
                .foregroundStyle(DesignSystem.Colors.priority.color(for: note.priority))
                .cornerRadius(6)

                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: note.statusIcon)
                        .font(.caption2)
                    Text(note.status.capitalized)
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(note.status).opacity(0.2))
                .foregroundStyle(statusColor(note.status))
                .cornerRadius(6)

                // Confidential badge
                if note.confidential {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Confidential")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.2))
                    .foregroundStyle(.red)
                    .cornerRadius(6)
                }

                // Pinned badge
                if note.isPinned {
                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                        Text("Pinned")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundStyle(.orange)
                    .cornerRadius(6)
                }
            }

            // Tags
            if !note.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(note.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.brand.primary.opacity(0.1))
                            .foregroundStyle(DesignSystem.Colors.brand.primary)
                            .cornerRadius(6)
                    }
                }
            }

            // Last updated
            Text("Last updated \(formatRelativeDate(note.updatedAt))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Content Section

    @ViewBuilder
    private func contentSection(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if isEditing {
                // Edit mode - TextEditor
                Text("Content")
                    .font(.headline)
                    .padding(.horizontal)

                TextEditor(text: $editedContent)
                    .font(.body)
                    .frame(minHeight: 300)
                    .padding(8)
                    #if os(iOS)
                    .background(Color(uiColor: .systemGray6))
                    #else
                    .background(Color(nsColor: .controlBackgroundColor))
                    #endif
                    .cornerRadius(8)
                    .padding(.horizontal)

                Text("Markdown supported: **bold**, *italic*, `code`, [link](url)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                // Read mode - Markdown rendering
                VStack(alignment: .leading, spacing: 12) {
                    if let attributedString = try? AttributedString(markdown: note.content) {
                        Text(attributedString)
                            .font(.body)
                            .textSelection(.enabled)
                    } else {
                        Text(note.content)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                #if os(iOS)
                .background(Color(uiColor: .systemBackground))
                #else
                .background(Color(nsColor: .controlBackgroundColor))
                #endif
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Links Section

    @ViewBuilder
    private func linksSection(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let links = note.links {
                // Linked Tasks
                if !links.tasks.isEmpty {
                    sectionHeader("Linked Tasks", icon: "checkmark.circle", count: links.tasks.count)
                    ForEach(links.tasks) { task in
                        SmartLinkRow(title: task.title, icon: "checkmark.circle", type: .task)
                            .padding(.horizontal)
                    }
                }

                // Linked Matters
                if !links.matters.isEmpty {
                    sectionHeader("Linked Matters", icon: "briefcase", count: links.matters.count)
                    ForEach(links.matters) { matter in
                        SmartLinkRow(
                            title: matter.title,
                            subtitle: matter.client,
                            icon: "briefcase",
                            type: .matter
                        )
                        .padding(.horizontal)
                    }
                }

                // Linked Projects
                if !links.projects.isEmpty {
                    sectionHeader("Linked Projects", icon: "folder", count: links.projects.count)
                    ForEach(links.projects) { project in
                        SmartLinkRow(title: project.name, icon: "folder", type: .project)
                            .padding(.horizontal)
                    }
                }

                // Linked Notes
                if !links.notes.isEmpty {
                    sectionHeader("Linked Notes", icon: "note.text", count: links.notes.count)
                    ForEach(links.notes) { linkedNote in
                        NavigationLink(destination: NoteDetailView(noteId: linkedNote.id)) {
                            SmartLinkRow(title: linkedNote.title, icon: "note.text", type: .note)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Backlinks Section

    @ViewBuilder
    private func backlinksSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Notes linking here", icon: "link", count: backlinks.count)

            ForEach(backlinks) { backlinkNote in
                NavigationLink(destination: NoteDetailView(noteId: backlinkNote.id)) {
                    NotesListRow(note: backlinkNote)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Actions Menu

    @ViewBuilder
    private func actionsMenu(_ note: Note) -> some View {
        Menu {
            Section {
                Button(action: { togglePin(note) }) {
                    Label(note.isPinned ? "Unpin" : "Pin", systemImage: "pin")
                }

                Button(action: { toggleConfidential(note) }) {
                    Label(note.confidential ? "Mark Public" : "Mark Confidential", systemImage: "lock")
                }
            }

            Section {
                Button(action: { duplicateNote(note) }) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }

                Button(action: { convertToTask(note) }) {
                    Label("Convert to Task", systemImage: "checkmark.circle")
                }
            }

            Section {
                Button(role: .destructive, action: { archiveNote(note) }) {
                    Label("Archive", systemImage: "archivebox")
                }

                Button(role: .destructive, action: { deleteNote(note) }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String, count: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(title) (\(count))")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Data Methods

    private func loadNoteDetails() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                async let noteResult = APIService.shared.getNote(id: noteId)
                async let backlinksResult = APIService.shared.getNoteBacklinks(id: noteId)

                let (fetchedNote, fetchedBacklinks) = try await (noteResult, backlinksResult)

                await MainActor.run {
                    self.note = fetchedNote
                    self.backlinks = fetchedBacklinks
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

    // MARK: - Edit Methods

    private func startEditing(_ note: Note) {
        editedTitle = note.title
        editedContent = note.content
        editedTags = note.tags
        editedPriority = note.priority
        editedStatus = note.status
        editedConfidential = note.confidential
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
    }

    private func saveNote() {
        guard let note = note else { return }

        Task {
            do {
                let updatedNote = try await APIService.shared.updateNote(
                    id: note.id,
                    title: editedTitle,
                    content: editedContent,
                    tags: editedTags,
                    priority: editedPriority,
                    status: editedStatus
                )

                await TaskCache.shared.updateNote(updatedNote)

                await MainActor.run {
                    self.note = updatedNote
                    self.isEditing = false
                    self.toast = .success("Note updated")
                    NotificationCenter.default.post(name: .notesUpdated, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.toast = .error("Failed to save: \(error.localizedDescription)")
                }
            }
        }
    }

    private var isFormValid: Bool {
        !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Action Methods

    private func togglePin(_ note: Note) {
        Task {
            do {
                let updatedNote = try await APIService.shared.updateNote(
                    id: note.id,
                    title: nil,
                    content: nil,
                    tags: nil,
                    priority: nil,
                    status: nil
                )
                await TaskCache.shared.updateNote(updatedNote)
                await MainActor.run {
                    self.note = updatedNote
                    self.toast = .success(updatedNote.isPinned ? "Note pinned" : "Note unpinned")
                }
            } catch {
                await MainActor.run {
                    self.toast = .error("Failed to update")
                }
            }
        }
    }

    private func toggleConfidential(_ note: Note) {
        // Similar to togglePin
        toast = .info("Confidential toggle not yet implemented")
    }

    private func duplicateNote(_ note: Note) {
        Task {
            do {
                let response = try await APIService.shared.performNoteAction(
                    id: note.id,
                    action: "duplicate"
                )
                await TaskCache.shared.addNote(response.data)
                await MainActor.run {
                    self.toast = .success("Note duplicated")
                    NotificationCenter.default.post(name: .notesCreated, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.toast = .error("Failed to duplicate")
                }
            }
        }
    }

    private func convertToTask(_ note: Note) {
        Task {
            do {
                _ = try await APIService.shared.performNoteAction(
                    id: note.id,
                    action: "convert-to-task"
                )
                await MainActor.run {
                    self.toast = .success("Converted to task")
                }
            } catch {
                await MainActor.run {
                    self.toast = .error("Failed to convert")
                }
            }
        }
    }

    private func archiveNote(_ note: Note) {
        Task {
            do {
                let updatedNote = try await APIService.shared.updateNote(
                    id: note.id,
                    status: "archived"
                )
                await TaskCache.shared.updateNote(updatedNote)
                await MainActor.run {
                    self.toast = .success("Note archived")
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.toast = .error("Failed to archive")
                }
            }
        }
    }

    private func deleteNote(_ note: Note) {
        Task {
            do {
                try await APIService.shared.deleteNote(id: note.id)
                await TaskCache.shared.removeNote(id: note.id)
                await MainActor.run {
                    self.toast = .success("Note deleted")
                    NotificationCenter.default.post(name: .notesUpdated, object: nil)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.toast = .error("Failed to delete")
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "active": return .green
        case "draft": return .yellow
        case "archived": return .gray
        default: return .blue
        }
    }

    private func formatRelativeDate(_ isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else {
            return "recently"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Note Detail Tab Enum

enum NoteDetailTab: String, CaseIterable, Identifiable {
    case content = "Content"
    case links = "Links"
    case backlinks = "Backlinks"

    var id: String { rawValue }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
            self.positions = positions
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NoteDetailView(noteId: "preview-note-id")
    }
}
