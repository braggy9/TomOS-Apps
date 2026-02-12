//
//  NoteRow.swift
//  TomOS
//
//  Phase 2: Notes Feature - List row component
//

import SwiftUI

struct NotesListRow: View {
    let note: Note

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon (confidential lock or priority indicator)
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(note.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                // Excerpt
                if let excerpt = note.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Badges row
                HStack(spacing: 8) {
                    // Priority badge (only if not medium)
                    if note.priority.lowercased() != "medium" {
                        HStack(spacing: 4) {
                            Image(systemName: note.priorityIcon)
                                .font(.caption2)
                            Text(note.priority.capitalized)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(DesignSystem.Colors.priority.color(for: note.priority))
                    }

                    // Status badge
                    HStack(spacing: 4) {
                        Image(systemName: note.statusIcon)
                            .font(.caption2)
                        Text(note.status.capitalized)
                            .font(.caption2)
                    }
                    .foregroundStyle(statusColor)

                    // Tags preview (first 2)
                    if !note.tags.isEmpty {
                        ForEach(note.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.brand.primary.opacity(0.1))
                                .foregroundStyle(DesignSystem.Colors.brand.primary)
                                .cornerRadius(4)
                        }

                        // More tags indicator
                        if note.tags.count > 2 {
                            Text("+\(note.tags.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Links count
                    if note.hasLinks {
                        HStack(spacing: 2) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text("\(note.totalLinks)")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // Review date (if overdue, show in red)
                    if let reviewDate = note.formattedReviewDate {
                        HStack(spacing: 2) {
                            Image(systemName: note.isReviewOverdue ? "calendar.badge.exclamationmark" : "calendar")
                                .font(.caption2)
                            Text(reviewDate)
                                .font(.caption2)
                        }
                        .foregroundStyle(note.isReviewOverdue ? .red : .secondary)
                    }
                }

                // Last updated
                Text(formatRelativeDate(note.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Pin indicator
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Computed Properties

    private var iconName: String {
        if note.confidential {
            return "lock.fill"
        } else {
            return note.priorityIcon
        }
    }

    private var iconColor: Color {
        if note.confidential {
            return .red
        } else {
            return DesignSystem.Colors.priority.color(for: note.priority)
        }
    }

    private var statusColor: Color {
        switch note.status.lowercased() {
        case "active":
            return .green
        case "draft":
            return .yellow
        case "archived":
            return .gray
        default:
            return .blue
        }
    }

    // MARK: - Helper Methods

    private func formatRelativeDate(_ isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else {
            return "Recently"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    List {
        NotesListRow(note: Note(
            id: "1",
            title: "Legal Research: Contract Formation",
            content: "Research on contract formation requirements...",
            excerpt: "Key findings on offer, acceptance, and consideration in Australian contract law",
            tags: ["legal", "research", "contracts"],
            isPinned: true,
            priority: "high",
            status: "active",
            reviewDate: nil,
            confidential: false,
            links: NoteLinks(
                tasks: [LinkedTask(id: "t1", title: "Complete review")],
                matters: [],
                projects: [],
                notes: []
            ),
            taskId: nil,
            matterId: nil,
            projectId: nil,
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
            updatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
        ))

        NotesListRow(note: Note(
            id: "2",
            title: "Meeting Notes - Client Call",
            content: "Discussion about upcoming litigation...",
            excerpt: "Client expressed concerns about timeline and costs",
            tags: ["meeting", "client"],
            isPinned: false,
            priority: "medium",
            status: "draft",
            reviewDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)), // Yesterday (overdue)
            confidential: true,
            links: nil,
            taskId: nil,
            matterId: "m1",
            projectId: nil,
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200)),
            updatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800))
        ))

        NotesListRow(note: Note(
            id: "3",
            title: "Quick Thought",
            content: "Remember to follow up on...",
            excerpt: nil,
            tags: [],
            isPinned: false,
            priority: "low",
            status: "archived",
            reviewDate: nil,
            confidential: false,
            links: nil,
            taskId: nil,
            matterId: nil,
            projectId: nil,
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-172800)),
            updatedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-172800))
        ))
    }
    .listStyle(.plain)
}
