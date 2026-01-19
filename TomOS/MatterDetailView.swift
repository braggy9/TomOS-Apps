//
//  MatterDetailView.swift
//  TomOS
//
//  Detailed view of a legal matter with documents, events, and notes
//

import SwiftUI

struct MatterDetailView: View {
    let matterId: String

    @State private var matter: Matter?
    @State private var documents: [MatterDocument] = []
    @State private var events: [MatterEvent] = []
    @State private var notes: [MatterNote] = []

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var toast: Toast?
    @State private var selectedTab: DetailTab = .overview

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading matter...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Failed to load")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        loadMatterDetails()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let matter = matter {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: matter.typeIcon)
                                    .font(.title)
                                    .foregroundStyle(.purple.gradient)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(matter.title)
                                        .font(.title2.bold())
                                    Text(matter.client)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }

                            if let description = matter.description {
                                Text(description)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }

                            // Metadata
                            VStack(alignment: .leading, spacing: 8) {
                                MetadataRow(icon: "flag.fill", label: "Priority", value: matter.priority, color: priorityColor(matter.priority))
                                MetadataRow(icon: "circle.fill", label: "Status", value: matter.status.replacingOccurrences(of: "_", with: " "), color: .blue)

                                if let leadCounsel = matter.leadCounsel {
                                    MetadataRow(icon: "person.fill", label: "Lead Counsel", value: leadCounsel, color: .purple)
                                }

                                if let practiceArea = matter.practiceArea {
                                    MetadataRow(icon: "building.columns", label: "Practice Area", value: practiceArea, color: .blue)
                                }

                                if let jurisdiction = matter.jurisdiction {
                                    MetadataRow(icon: "map", label: "Jurisdiction", value: jurisdiction, color: .green)
                                }
                            }
                        }
                        .padding()
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Tabs
                        Picker("Section", selection: $selectedTab) {
                            ForEach(DetailTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // Tab Content
                        switch selectedTab {
                        case .overview:
                            OverviewSection(matter: matter)
                        case .documents:
                            DocumentsSection(documents: documents)
                        case .timeline:
                            TimelineSection(events: events)
                        case .notes:
                            NotesSection(notes: notes)
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Matter")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable {
                    await refreshMatter()
                }
            }
        }
        .toast($toast)
        .onAppear {
            if matter == nil {
                loadMatterDetails()
            }
        }
    }

    private func loadMatterDetails() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                async let matterResult = APIService.shared.getMatter(id: matterId)
                async let documentsResult = APIService.shared.getMatterDocuments(matterId: matterId)
                async let eventsResult = APIService.shared.getMatterEvents(matterId: matterId)
                async let notesResult = APIService.shared.getMatterNotes(matterId: matterId)

                let (matter, docs, evts, nts) = try await (matterResult, documentsResult, eventsResult, notesResult)

                await MainActor.run {
                    self.matter = matter
                    self.documents = docs
                    self.events = evts
                    self.notes = nts
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

    private func refreshMatter() async {
        do {
            async let matterResult = APIService.shared.getMatter(id: matterId)
            async let documentsResult = APIService.shared.getMatterDocuments(matterId: matterId)
            async let eventsResult = APIService.shared.getMatterEvents(matterId: matterId)
            async let notesResult = APIService.shared.getMatterNotes(matterId: matterId)

            let (matter, docs, evts, nts) = try await (matterResult, documentsResult, eventsResult, notesResult)

            await MainActor.run {
                self.matter = matter
                self.documents = docs
                self.events = evts
                self.notes = nts
            }
        } catch {
            await MainActor.run {
                toast = .error("Failed to refresh")
            }
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "urgent": return .red
        case "high": return .orange
        case "medium": return .blue
        case "low": return .gray
        default: return .blue
        }
    }
}

// MARK: - Metadata Row

struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
        }
    }
}

// MARK: - Overview Section

struct OverviewSection: View {
    let matter: Matter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let counts = matter.counts {
                HStack(spacing: 16) {
                    CountCard(icon: "checklist", count: counts.tasks, label: "Tasks", color: .purple)
                    CountCard(icon: "doc.fill", count: counts.documents, label: "Documents", color: .blue)
                    CountCard(icon: "clock.fill", count: counts.events, label: "Events", color: .orange)
                    CountCard(icon: "note.text", count: counts.notes, label: "Notes", color: .green)
                }
                .padding(.horizontal)
            }

            if !matter.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(matter.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundStyle(.purple)
                                    .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            Text("Last Activity: \(matter.formattedLastActivity)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }
}

struct CountCard: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color.gradient)

            Text("\(count)")
                .font(.title3.bold())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Documents Section

struct DocumentsSection: View {
    let documents: [MatterDocument]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if documents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray)
                    Text("No documents yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(documents) { document in
                    DocumentRow(document: document)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct DocumentRow: View {
    let document: MatterDocument

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.typeIcon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.body)
                Text(document.type.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let status = document.status {
                    Text(status.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(4)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Timeline Section

struct TimelineSection: View {
    let events: [MatterEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if events.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray)
                    Text("No events yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(events) { event in
                    EventRow(event: event)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct EventRow: View {
    let event: MatterEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.typeIcon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.body)

                if let description = event.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let actor = event.actor {
                    Text(actor)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Notes Section

struct NotesSection: View {
    let notes: [MatterNote]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if notes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray)
                    Text("No notes yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(notes) { note in
                    NoteRow(note: note)
                        .padding(.horizontal)
                }
            }
        }
    }
}

struct NoteRow: View {
    let note: MatterNote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = note.title {
                Text(title)
                    .font(.headline)
            }

            Text(note.content)
                .font(.body)
                .lineLimit(3)
                .foregroundStyle(.secondary)

            HStack {
                Text(note.type.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .cornerRadius(4)

                if let author = note.author {
                    Text("by \(author)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Detail Tab Enum

enum DetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case documents = "Documents"
    case timeline = "Timeline"
    case notes = "Notes"

    var id: String { rawValue }
}

#Preview {
    NavigationStack {
        MatterDetailView(matterId: "test-id")
    }
}
