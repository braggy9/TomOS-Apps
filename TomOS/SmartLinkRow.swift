//
//  SmartLinkRow.swift
//  TomOS
//
//  Phase 2: Notes Feature - Reusable component for displaying smart links
//

import SwiftUI

enum SmartLinkType {
    case task
    case matter
    case project
    case note
}

struct SmartLinkRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let type: SmartLinkType

    init(title: String, subtitle: String? = nil, icon: String, type: SmartLinkType) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.type = type
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        #if os(iOS)
        .background(Color(uiColor: .systemBackground))
        #else
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
        .cornerRadius(8)
    }

    // MARK: - Computed Properties

    private var iconColor: Color {
        switch type {
        case .task:
            return .blue
        case .matter:
            return DesignSystem.Colors.brand.primary
        case .project:
            return .orange
        case .note:
            return .purple
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        SmartLinkRow(
            title: "Complete legal research",
            subtitle: nil,
            icon: "checkmark.circle",
            type: .task
        )

        SmartLinkRow(
            title: "Smith v Johnson Litigation",
            subtitle: "Acme Corp",
            icon: "briefcase",
            type: .matter
        )

        SmartLinkRow(
            title: "Q1 Contract Review",
            subtitle: nil,
            icon: "folder",
            type: .project
        )

        SmartLinkRow(
            title: "Meeting notes from client call",
            subtitle: nil,
            icon: "note.text",
            type: .note
        )
    }
    .padding()
    #if os(iOS)
    .background(Color(uiColor: .systemGroupedBackground))
    #else
    .background(Color(nsColor: .windowBackgroundColor))
    #endif
}
