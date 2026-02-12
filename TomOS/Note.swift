//
//  Note.swift
//  TomOS
//
//  Phase 2: Notes Feature - Data Models
//

import Foundation

// MARK: - Note Models

struct Note: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let content: String
    let excerpt: String?
    let tags: [String]
    let isPinned: Bool
    let priority: String      // "low", "medium", "high", "urgent"
    let status: String        // "draft", "active", "archived"
    let reviewDate: String?   // ISO 8601 date
    let confidential: Bool
    let links: NoteLinks?
    let taskId: String?
    let matterId: String?
    let projectId: String?
    let createdAt: String
    let updatedAt: String
}

struct NoteLinks: Codable, Hashable {
    let tasks: [LinkedTask]
    let matters: [LinkedMatter]
    let projects: [LinkedProject]
    let notes: [LinkedNote]
}

struct LinkedTask: Codable, Identifiable, Hashable {
    let id: String
    let title: String
}

struct LinkedMatter: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let client: String?
}

struct LinkedProject: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct LinkedNote: Codable, Identifiable, Hashable {
    let id: String
    let title: String
}

struct NoteTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: String
    let template: String
    let suggestedTags: [String]
}

// MARK: - API Response Wrappers

struct NotesResponse: Codable {
    let success: Bool
    let data: [Note]
    let pagination: Pagination?
}

struct NoteResponse: Codable {
    let success: Bool
    let data: Note
}

struct TemplatesResponse: Codable {
    let success: Bool
    let data: TemplateData
}

struct TemplateData: Codable {
    let templates: [NoteTemplate]
    let categorized: [String: [NoteTemplate]]
}

struct BacklinksResponse: Codable {
    let success: Bool
    let data: [Note]
}

// MARK: - Note Action Request

struct NoteActionRequest: Codable {
    let action: String
    let parameters: [String: String]?
}

// MARK: - Helper Extensions

extension Note {
    var priorityColor: String {
        switch priority.lowercased() {
        case "urgent": return "red"
        case "high": return "orange"
        case "medium": return "blue"
        case "low": return "gray"
        default: return "blue"
        }
    }

    var priorityIcon: String {
        switch priority.lowercased() {
        case "urgent": return "exclamationmark.triangle.fill"
        case "high": return "arrow.up.circle.fill"
        case "medium": return "circle.fill"
        case "low": return "arrow.down.circle.fill"
        default: return "circle"
        }
    }

    var statusIcon: String {
        switch status.lowercased() {
        case "active": return "note.text.badge.plus"
        case "draft": return "doc.text"
        case "archived": return "archivebox"
        default: return "note.text"
        }
    }

    var statusColor: String {
        switch status.lowercased() {
        case "active": return "green"
        case "draft": return "yellow"
        case "archived": return "gray"
        default: return "blue"
        }
    }

    var hasLinks: Bool {
        guard let links = links else { return false }
        return !links.tasks.isEmpty || !links.matters.isEmpty || !links.projects.isEmpty || !links.notes.isEmpty
    }

    var totalLinks: Int {
        guard let links = links else { return 0 }
        return links.tasks.count + links.matters.count + links.projects.count + links.notes.count
    }

    var formattedReviewDate: String? {
        guard let reviewDate = reviewDate,
              let date = ISO8601DateFormatter().date(from: reviewDate) else {
            return nil
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var isReviewOverdue: Bool {
        guard let reviewDate = reviewDate,
              let date = ISO8601DateFormatter().date(from: reviewDate) else {
            return false
        }
        return date < Date()
    }
}

extension NoteTemplate {
    var displayCategory: String {
        // Capitalize category for display
        return category.prefix(1).uppercased() + category.dropFirst()
    }
}
