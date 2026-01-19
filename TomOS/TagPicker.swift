import SwiftUI

// MARK: - Tag Models

struct Tag: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let prefix: TagPrefix
    let description: String

    var displayName: String { name }
    var category: String {
        switch prefix {
        case .project: return "Project"
        case .area: return "Area"
        case .action: return "Action"
        case .topic: return "Topic"
        }
    }
}

enum TagPrefix: String, CaseIterable {
    case project = "proj:"
    case area = "area:"
    case action = "act:"
    case topic = "topic:"

    var icon: String {
        switch self {
        case .project: return "folder"
        case .area: return "square.grid.2x2"
        case .action: return "bolt"
        case .topic: return "tag"
        }
    }

    var color: Color {
        switch self {
        case .project: return .blue
        case .area: return .green
        case .action: return .orange
        case .topic: return .purple
        }
    }
}

// MARK: - Tag Service

class TagService: ObservableObject {
    @Published var allTags: [Tag] = []
    @Published var recentTags: [String] = []

    init() {
        loadPredefinedTags()
        loadRecentTags()
    }

    private func loadPredefinedTags() {
        allTags = [
            // Project Tags
            Tag(name: "proj:mixtape", prefix: .project, description: "MixTape Running Supply business"),
            Tag(name: "proj:explorers", prefix: .project, description: "Scouts/Explorers volunteer work"),
            Tag(name: "proj:tomos", prefix: .project, description: "TomOS system development"),
            Tag(name: "proj:legal-ops", prefix: .project, description: "Legal operations improvement"),
            Tag(name: "proj:bison", prefix: .project, description: "Bison Outside Build kit"),
            Tag(name: "proj:notorious-dad", prefix: .project, description: "Notorious D.A.D. family project"),

            // Area Tags
            Tag(name: "area:work", prefix: .area, description: "Professional employment"),
            Tag(name: "area:personal", prefix: .area, description: "Personal life"),
            Tag(name: "area:parenting", prefix: .area, description: "Parenting responsibilities"),
            Tag(name: "area:health", prefix: .area, description: "Physical/mental health"),
            Tag(name: "area:finance", prefix: .area, description: "Money, bills, investments"),
            Tag(name: "area:learning", prefix: .area, description: "Study, courses, skills"),

            // Action Tags
            Tag(name: "act:waiting-for", prefix: .action, description: "Blocked, waiting on someone"),
            Tag(name: "act:research", prefix: .action, description: "Investigation, learning"),
            Tag(name: "act:write", prefix: .action, description: "Writing content"),
            Tag(name: "act:call", prefix: .action, description: "Phone call required"),
            Tag(name: "act:review", prefix: .action, description: "Review/approve something"),
            Tag(name: "act:plan", prefix: .action, description: "Planning, strategizing"),
            Tag(name: "act:meeting", prefix: .action, description: "Meeting prep or follow-up"),
            Tag(name: "act:email", prefix: .action, description: "Email-specific task"),

            // Topic Tags
            Tag(name: "topic:contracts", prefix: .topic, description: "Contract work"),
            Tag(name: "topic:music", prefix: .topic, description: "Music, DJing"),
            Tag(name: "topic:adhd", prefix: .topic, description: "ADHD, productivity"),
            Tag(name: "topic:scouting", prefix: .topic, description: "Scouts activities"),
            Tag(name: "topic:running", prefix: .topic, description: "Running, training"),
            Tag(name: "topic:ai", prefix: .topic, description: "AI/automation projects"),
        ]
    }

    private func loadRecentTags() {
        // Load from UserDefaults
        recentTags = UserDefaults.standard.stringArray(forKey: "recentTags") ?? []
    }

    func addToRecent(_ tag: String) {
        // Remove if already exists
        recentTags.removeAll { $0 == tag }
        // Add to front
        recentTags.insert(tag, at: 0)
        // Keep only last 10
        if recentTags.count > 10 {
            recentTags = Array(recentTags.prefix(10))
        }
        // Save
        UserDefaults.standard.set(recentTags, forKey: "recentTags")
    }

    func suggestTags(for taskText: String, context: String?) -> [Tag] {
        let text = taskText.lowercased()
        var scores: [Tag: Int] = [:]

        for tag in allTags {
            var score = 0

            // Score based on tag name keywords
            let keywords = getKeywords(for: tag.name)
            for keyword in keywords {
                if text.contains(keyword) {
                    score += 2
                }
            }

            // Boost based on context
            if let context = context {
                score += contextBoost(for: tag, context: context)
            }

            if score > 0 {
                scores[tag] = score
            }
        }

        // Return top 5 suggestions
        return scores.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

    private func getKeywords(for tagName: String) -> [String] {
        // Extract keywords from tag name
        let parts = tagName.components(separatedBy: ":")
        guard parts.count == 2 else { return [] }

        let name = parts[1]
        return [name] + name.components(separatedBy: "-")
    }

    private func contextBoost(for tag: Tag, context: String) -> Int {
        let contextLower = context.lowercased()

        switch contextLower {
        case "work":
            return tag.name == "area:work" ? 3 : 0
        case "personal":
            return tag.name == "area:personal" ? 3 : 0
        case "parenting":
            return tag.name == "area:parenting" ? 3 : 0
        case "mixtape":
            return tag.name == "proj:mixtape" ? 3 : 0
        case "explorers":
            return tag.name == "proj:explorers" ? 3 : 0
        default:
            return 0
        }
    }
}

// MARK: - Tag Picker View

struct TagPickerView: View {
    @StateObject private var tagService = TagService()
    @Binding var selectedTags: Set<String>
    @State private var searchText = ""
    @State private var selectedPrefix: TagPrefix? = nil

    var suggestedTags: [Tag]

    var filteredTags: [Tag] {
        var tags = tagService.allTags

        // Filter by prefix
        if let prefix = selectedPrefix {
            tags = tags.filter { $0.prefix == prefix }
        }

        // Filter by search text
        if !searchText.isEmpty {
            tags = tags.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        return tags
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search tags or type prefix (p:/proj:, a:/area:, act:, t:/topic:)", text: $searchText)
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
                    .disableAutocorrection(true)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(white: 0.95))

            // Prefix filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button {
                        selectedPrefix = nil
                    } label: {
                        Text("All")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedPrefix == nil ? Color.blue : Color(white: 0.92))
                            .foregroundColor(selectedPrefix == nil ? .white : .primary)
                            .cornerRadius(20)
                    }

                    ForEach(TagPrefix.allCases, id: \.self) { prefix in
                        Button {
                            selectedPrefix = prefix == selectedPrefix ? nil : prefix
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: prefix.icon)
                                Text(prefix.rawValue)
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedPrefix == prefix ? prefix.color : Color(white: 0.92))
                            .foregroundColor(selectedPrefix == prefix ? .white : .primary)
                            .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)

            Divider()

            // Suggested tags section
            if !suggestedTags.isEmpty && searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.orange)
                        Text("Suggested for this task")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestedTags) { tag in
                                TagChip(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag.name),
                                    action: { toggleTag(tag.name) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                }

                Divider()
            }

            // Tag list
            List {
                ForEach(filteredTags.grouped(by: \.category).sorted(by: { $0.key < $1.key }), id: \.key) { category, tags in
                    Section(category) {
                        ForEach(tags) { tag in
                            TagRow(
                                tag: tag,
                                isSelected: selectedTags.contains(tag.name),
                                action: { toggleTag(tag.name) }
                            )
                        }
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
        }
        .navigationTitle("Select Tags")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func toggleTag(_ tagName: String) {
        if selectedTags.contains(tagName) {
            selectedTags.remove(tagName)
        } else {
            selectedTags.insert(tagName)
            tagService.addToRecent(tagName)
        }
    }
}

// MARK: - Tag Row

struct TagRow: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: tag.prefix.icon)
                    .foregroundColor(tag.prefix.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(tag.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: tag.prefix.icon)
                    .font(.caption)
                Text(tag.name)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? tag.prefix.color : Color(white: 0.92))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Tag Display (for selected tags)

struct SelectedTagsView: View {
    @Binding var selectedTags: Set<String>

    var body: some View {
        if !selectedTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(selectedTags), id: \.self) { tagName in
                        HStack(spacing: 4) {
                            Text(tagName)
                                .font(.caption)
                            Button {
                                selectedTags.remove(tagName)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(colorForTag(tagName))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }

    private func colorForTag(_ tag: String) -> Color {
        if tag.starts(with: "proj:") { return .blue }
        if tag.starts(with: "area:") { return .green }
        if tag.starts(with: "act:") { return .orange }
        if tag.starts(with: "topic:") { return .purple }
        return .gray
    }
}

// MARK: - Helper Extension

extension Array {
    func grouped<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Key: [Element]] {
        return Dictionary(grouping: self, by: { $0[keyPath: keyPath] })
    }
}
