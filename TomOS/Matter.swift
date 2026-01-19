//
//  Matter.swift
//  TomOS
//
//  MatterOS data models for legal matter management
//

import Foundation

// MARK: - Matter Models

struct Matter: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    let client: String
    let matterNumber: String?
    let type: String
    let status: String
    let priority: String
    let createdAt: String
    let updatedAt: String
    let dueDate: String?
    let completedAt: String?
    let lastActivityAt: String
    let budget: Decimal?
    let actualSpend: Decimal?
    let billingStatus: String?
    let clientContact: String?
    let leadCounsel: String?
    let teamMembers: [String]
    let externalCounsel: [String]
    let practiceArea: String?
    let jurisdiction: String?
    let tags: [String]
    let counts: MatterCounts?

    enum CodingKeys: String, CodingKey {
        case id, title, description, client, matterNumber, type, status, priority
        case createdAt, updatedAt, dueDate, completedAt, lastActivityAt
        case budget, actualSpend, billingStatus, clientContact, leadCounsel
        case teamMembers, externalCounsel, practiceArea, jurisdiction, tags
        case counts = "_count"
    }
}

struct MatterCounts: Codable {
    let documents: Int
    let events: Int
    let notes: Int
    let tasks: Int
}

struct MatterDocument: Identifiable, Codable {
    let id: String
    let matterId: String
    let title: String
    let type: String
    let description: String?
    let fileUrl: String?
    let localPath: String?
    let version: String?
    let status: String?
    let author: String?
    let reviewedBy: String?
    let createdAt: String
    let updatedAt: String
    let signedAt: String?
    let expiresAt: String?
}

struct MatterEvent: Identifiable, Codable {
    let id: String
    let matterId: String
    let type: String
    let title: String
    let description: String?
    let actor: String?
    let createdAt: String
}

struct MatterNote: Identifiable, Codable {
    let id: String
    let matterId: String
    let title: String?
    let content: String
    let type: String
    let author: String?
    let tags: [String]
    let createdAt: String
    let updatedAt: String
}

// MARK: - API Response Wrappers

struct MattersResponse: Codable {
    let success: Bool
    let data: [Matter]
    let pagination: Pagination?
}

struct MatterResponse: Codable {
    let success: Bool
    let data: Matter
}

struct MatterDocumentsResponse: Codable {
    let success: Bool
    let data: [MatterDocument]
    let pagination: Pagination?
}

struct MatterEventsResponse: Codable {
    let success: Bool
    let data: [MatterEvent]
    let pagination: Pagination?
}

struct MatterNotesResponse: Codable {
    let success: Bool
    let data: [MatterNote]
    let pagination: Pagination?
}

struct Pagination: Codable {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

// MARK: - Helper Extensions

extension Matter {
    var priorityColor: String {
        switch priority.lowercased() {
        case "urgent": return "red"
        case "high": return "orange"
        case "medium": return "blue"
        case "low": return "gray"
        default: return "blue"
        }
    }

    var typeIcon: String {
        switch type.lowercased() {
        case "contract": return "doc.text"
        case "dispute": return "hammer"
        case "compliance": return "checkmark.shield"
        case "advisory": return "lightbulb"
        case "employment": return "person.2"
        case "ip": return "sparkles"
        case "regulatory": return "list.clipboard"
        default: return "briefcase"
        }
    }

    var statusIcon: String {
        switch status.lowercased() {
        case "active": return "circle.fill"
        case "on_hold": return "pause.circle"
        case "completed": return "checkmark.circle.fill"
        case "archived": return "archivebox"
        default: return "circle"
        }
    }

    var formattedLastActivity: String {
        guard let date = ISO8601DateFormatter().date(from: lastActivityAt) else {
            return "Recently"
        }
        return date.formatted(.relative(presentation: .named))
    }
}

extension MatterDocument {
    var typeIcon: String {
        switch type.lowercased() {
        case "contract": return "doc.text"
        case "email": return "envelope"
        case "memo": return "note.text"
        case "correspondence": return "text.bubble"
        case "court_filing": return "building.columns"
        case "research": return "book"
        default: return "doc"
        }
    }
}

extension MatterEvent {
    var typeIcon: String {
        switch type.lowercased() {
        case "status_change": return "arrow.triangle.2.circlepath"
        case "document_added": return "doc.badge.plus"
        case "task_completed": return "checkmark.circle"
        case "note_added": return "note.text.badge.plus"
        case "meeting": return "calendar"
        case "deadline": return "clock.badge.exclamationmark"
        default: return "circle"
        }
    }
}
