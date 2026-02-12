//
//  NotesView.swift
//  TomOS
//
//  Phase 2: Notes Feature - Main list view with filters and search
//

import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    static let notesCreated = Notification.Name("notesCreated")
    static let notesUpdated = Notification.Name("notesUpdated")
}

// MARK: - Notes View

struct NotesView: View {
    @State private var notes: [Note] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var toast: Toast?
    @State private var selectedFilter: NoteFilter = .all
    @State private var searchText = ""
    @State private var showingTemplateSheet = false
    @State private var showingCreateSheet = false

    var filteredNotes: [Note] {
        var filtered = notes.filter { note in
            switch selectedFilter {
            case .all:
                return true
            case .active:
                return note.status.lowercased() == "active"
            case .draft:
                return note.status.lowercased() == "draft"
            case .archived:
                return note.status.lowercased() == "archived"
            case .pinned:
                return note.isPinned
            case .confidential:
                return note.confidential
            }
        }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { note in
                note.title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                note.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }

        // Sort: Pinned first, then by updated date
        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading notes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    // Error state
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text("Failed to load notes")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            fetchNotes()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredNotes.isEmpty {
                    // Empty state
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: emptyStateIcon)
                            .font(.system(size: 60))
                            .foregroundStyle(DesignSystem.Colors.brand.gradient)
                        Text(emptyStateTitle)
                            .font(.headline)
                        Text(emptyStateMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button {
                                showingTemplateSheet = true
                            } label: {
                                Label("From Template", systemImage: "doc.text.image")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showingCreateSheet = true
                            } label: {
                                Label("Blank Note", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // List of notes
                    List {
                        ForEach(filteredNotes) { note in
                            NavigationLink(destination: NoteDetailView(noteId: note.id)) {
                                NotesListRow(note: note)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshNotes()
                    }
                }
            }
            .navigationTitle("Notes")
            .searchable(text: $searchText, prompt: "Search notes...")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    filterMenu
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingTemplateSheet = true
                        } label: {
                            Image(systemName: "doc.text.image")
                        }

                        Button {
                            showingCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                #else
                ToolbarItem(placement: .navigation) {
                    filterMenu
                }

                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 12) {
                        Button {
                            showingTemplateSheet = true
                        } label: {
                            Label("From Template", systemImage: "doc.text.image")
                        }

                        Button {
                            showingCreateSheet = true
                        } label: {
                            Label("New Note", systemImage: "plus")
                        }
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingTemplateSheet) {
                TemplatePickerView()
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateNoteView()
            }
            .toast($toast)
        }
        .onAppear {
            if notes.isEmpty {
                fetchNotes()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notesCreated)) { _ in
            fetchNotes()
        }
        .onReceive(NotificationCenter.default.publisher(for: .notesUpdated)) { _ in
            fetchNotes()
        }
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(NoteFilter.allCases) { filter in
                    Label(filter.rawValue, systemImage: filter.icon)
                        .tag(filter)
                }
            }
        } label: {
            Label(selectedFilter.rawValue, systemImage: selectedFilter.icon)
        }
    }

    // MARK: - Empty State

    private var emptyStateIcon: String {
        if !searchText.isEmpty {
            return "magnifyingglass"
        } else if selectedFilter != .all {
            return selectedFilter.icon
        } else {
            return "note.text"
        }
    }

    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No results found"
        } else if notes.isEmpty {
            return "No notes yet"
        } else {
            return "No \(selectedFilter.rawValue.lowercased()) notes"
        }
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try adjusting your search terms"
        } else if notes.isEmpty {
            return "Create your first note from a template or start from scratch"
        } else {
            return "Change filters to see other notes"
        }
    }

    // MARK: - Data Methods

    private func fetchNotes() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                print("📝 NotesView: Fetching notes from API...")
                // Use TaskCache for better performance
                let fetchedNotes = try await TaskCache.shared.getNotes()
                print("✅ NotesView: Loaded \(fetchedNotes.count) notes")
                await MainActor.run {
                    self.notes = fetchedNotes
                    self.isLoading = false
                }
            } catch {
                print("❌ NotesView: Fetch failed - \(error)")
                if let decodingError = error as? DecodingError {
                    print("🔍 Decoding error details: \(decodingError)")
                }
                await MainActor.run {
                    self.errorMessage = "Failed to load notes: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func refreshNotes() async {
        do {
            print("🔄 NotesView: Refreshing notes...")
            // Force refresh from API
            let fetchedNotes = try await TaskCache.shared.getNotes(forceRefresh: true)
            print("✅ NotesView: Refreshed \(fetchedNotes.count) notes")
            await MainActor.run {
                self.notes = fetchedNotes
                self.toast = .success("Notes refreshed")
            }
        } catch {
            print("❌ NotesView: Refresh failed - \(error)")
            await MainActor.run {
                self.toast = .error("Failed to refresh: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Note Filter Enum

enum NoteFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case draft = "Draft"
    case archived = "Archived"
    case pinned = "Pinned"
    case confidential = "Confidential"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "note.text"
        case .active: return "note.text.badge.plus"
        case .draft: return "doc.text"
        case .archived: return "archivebox"
        case .pinned: return "pin.fill"
        case .confidential: return "lock.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    NotesView()
}
