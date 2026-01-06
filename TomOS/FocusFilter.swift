import AppIntents
import SwiftUI

// MARK: - Focus Filter Configuration

@available(iOS 16.0, *)
struct TomOSFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "TomOS Focus Filter"
    static var description: IntentDescription? = IntentDescription("Show tasks matching your current focus")

    // User-configurable parameter
    @Parameter(title: "Context", description: "Which task context to show")
    var context: TaskContext?

    @Parameter(title: "Show Only Urgent", description: "Only show urgent tasks")
    var showOnlyUrgent: Bool?

    // Display representation for Settings
    var displayRepresentation: DisplayRepresentation {
        if let context = context {
            return DisplayRepresentation(stringLiteral: "Show \(context.rawValue) tasks")
        }
        return DisplayRepresentation(stringLiteral: "Show all tasks")
    }

    // Apply the filter when Focus activates
    func perform() async throws -> some IntentResult {
        // Store the active filter in UserDefaults for the app to read
        if let context = context {
            UserDefaults.standard.set(context.rawValue, forKey: "activeFocusContext")
        } else {
            UserDefaults.standard.removeObject(forKey: "activeFocusContext")
        }

        UserDefaults.standard.set(showOnlyUrgent ?? false, forKey: "focusShowOnlyUrgent")

        // Post notification so app can update UI
        NotificationCenter.default.post(name: .focusFilterChanged, object: nil)

        return .result()
    }
}

// MARK: - Task Context Enum

@available(iOS 16.0, *)
enum TaskContext: String, AppEnum, CaseIterable {
    case work = "Work"
    case personal = "Personal"
    case clientProjects = "Client Projects"
    case strategy = "Strategy"
    case admin = "Admin"
    case legalReview = "Legal Review"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Task Context"

    static var caseDisplayRepresentations: [TaskContext: DisplayRepresentation] = [
        .work: DisplayRepresentation(title: "Work", subtitle: "Work-related tasks"),
        .personal: DisplayRepresentation(title: "Personal", subtitle: "Personal tasks"),
        .clientProjects: DisplayRepresentation(title: "Client Projects", subtitle: "Client project tasks"),
        .strategy: DisplayRepresentation(title: "Strategy", subtitle: "Strategy & planning"),
        .admin: DisplayRepresentation(title: "Admin", subtitle: "Administrative tasks"),
        .legalReview: DisplayRepresentation(title: "Legal Review", subtitle: "Legal review tasks")
    ]
}

// MARK: - Notification Extension

extension Notification.Name {
    static let focusFilterChanged = Notification.Name("focusFilterChanged")
}

// MARK: - Focus Filter Manager

@available(iOS 16.0, *)
class FocusFilterManager: ObservableObject {
    static let shared = FocusFilterManager()

    @Published var activeContext: String?
    @Published var showOnlyUrgent: Bool = false

    private init() {
        loadCurrentFilter()
        setupObservers()
    }

    private func loadCurrentFilter() {
        activeContext = UserDefaults.standard.string(forKey: "activeFocusContext")
        showOnlyUrgent = UserDefaults.standard.bool(forKey: "focusShowOnlyUrgent")
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(filterChanged),
            name: .focusFilterChanged,
            object: nil
        )
    }

    @objc private func filterChanged() {
        loadCurrentFilter()
    }

    // Build API query parameters based on active filter
    func queryParameters() -> [String: String] {
        var params: [String: String] = [:]

        if let context = activeContext {
            params["context"] = context
        }

        if showOnlyUrgent {
            params["urgent"] = "true"
        }

        return params
    }
}
