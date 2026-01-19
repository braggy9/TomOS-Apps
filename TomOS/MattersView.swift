//
//  MattersView.swift
//  TomOS
//
//  MatterOS - Legal matter management tab
//

import SwiftUI

struct MattersView: View {
    @State private var matters: [Matter] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var toast: Toast?
    @State private var selectedFilter: MatterFilter = .active
    @State private var showingCreateSheet = false

    var filteredMatters: [Matter] {
        matters.filter { matter in
            switch selectedFilter {
            case .all:
                return true
            case .active:
                return matter.status.lowercased() == "active"
            case .completed:
                return matter.status.lowercased() == "completed"
            case .onHold:
                return matter.status.lowercased() == "on_hold"
            case .urgent:
                return matter.priority.lowercased() == "urgent"
            case .high:
                return matter.priority.lowercased() == "high"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading matters...")
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
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            fetchMatters()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredMatters.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "briefcase")
                            .font(.system(size: 60))
                            .foregroundStyle(.purple.gradient)
                        Text(matters.isEmpty ? "No matters yet" : "No \(selectedFilter.rawValue.lowercased()) matters")
                            .font(.headline)
                        Text("Create your first legal matter to get started")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            showingCreateSheet = true
                        } label: {
                            Label("Create Matter", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredMatters) { matter in
                            NavigationLink(destination: MatterDetailView(matterId: matter.id)) {
                                MatterRow(matter: matter)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshMatters()
                    }
                }
            }
            .navigationTitle("Matters")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(MatterFilter.allCases) { filter in
                                Label(filter.rawValue, systemImage: filter.icon)
                                    .tag(filter)
                            }
                        }
                    } label: {
                        Label(selectedFilter.rawValue, systemImage: selectedFilter.icon)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .toast($toast)
        .sheet(isPresented: $showingCreateSheet) {
            CreateMatterView(onMatterCreated: { newMatter in
                matters.insert(newMatter, at: 0)
                toast = .success("Matter created!")
            })
        }
        .onAppear {
            if matters.isEmpty {
                fetchMatters()
            }
        }
    }

    private func fetchMatters() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let fetchedMatters = try await APIService.shared.getMatters()
                await MainActor.run {
                    self.matters = fetchedMatters
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

    private func refreshMatters() async {
        do {
            let fetchedMatters = try await APIService.shared.getMatters()
            await MainActor.run {
                self.matters = fetchedMatters
            }
        } catch {
            await MainActor.run {
                self.toast = .error("Failed to refresh")
            }
        }
    }
}

// MARK: - Matter Row Component

struct MatterRow: View {
    let matter: Matter

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: matter.typeIcon)
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(matter.title)
                    .font(.body)
                    .lineLimit(2)

                // Client
                Text(matter.client)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Metadata badges
                HStack(spacing: 8) {
                    // Priority
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                        Text(matter.priority)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(priorityColor(matter.priority))

                    // Status
                    HStack(spacing: 4) {
                        Image(systemName: matter.statusIcon)
                            .font(.caption2)
                        Text(matter.status.replacingOccurrences(of: "_", with: " "))
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)

                    // Counts
                    if let counts = matter.counts {
                        if counts.tasks > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "checklist")
                                    .font(.caption2)
                                Text("\(counts.tasks)")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }

                        if counts.documents > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "doc")
                                    .font(.caption2)
                                Text("\(counts.documents)")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // Last activity
                Text(matter.formattedLastActivity)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
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

// MARK: - Matter Filter Enum

enum MatterFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case completed = "Completed"
    case onHold = "On Hold"
    case urgent = "Urgent"
    case high = "High Priority"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .active: return "circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .onHold: return "pause.circle"
        case .urgent: return "exclamationmark.triangle.fill"
        case .high: return "flag.fill"
        }
    }
}

#Preview {
    MattersView()
}
