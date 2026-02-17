import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Response Models

public struct TaskResponse: Codable {
    public let success: Bool
    public let taskId: String
    public let parsedTask: ParsedTaskDetails
    public let message: String
    public let source: String?

    // Support old Notion format for backwards compatibility
    enum CodingKeys: String, CodingKey {
        case success
        case taskId
        case notionPageId
        case parsedTask
        case message
        case source
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)

        // Try new format (taskId) first, fallback to old format (notionPageId)
        if let newId = try? container.decode(String.self, forKey: .taskId) {
            taskId = newId
        } else {
            taskId = try container.decode(String.self, forKey: .notionPageId)
        }

        parsedTask = try container.decode(ParsedTaskDetails.self, forKey: .parsedTask)
        message = try container.decode(String.self, forKey: .message)
        source = try? container.decode(String.self, forKey: .source)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(taskId, forKey: .taskId)
        try container.encode(parsedTask, forKey: .parsedTask)
        try container.encode(message, forKey: .message)
        try? container.encode(source, forKey: .source)
    }
}

public struct ParsedTaskDetails: Codable {
    public let title: String
    public let priority: String
    public let context: String
    public let energy: String
    public let time: String
    public let dueDate: String?
    public let subtasks: [String]
    public let tags: [String]
    public let mentions: [String]
}

public struct TaskItem: Identifiable, Codable {
    public let id: String
    public let title: String
    public let status: String
    public let priority: String?
    public let context: [String]?
    public let dueDate: String?

    public init(id: String, title: String, status: String, priority: String? = nil, context: [String]? = nil, dueDate: String? = nil) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.context = context
        self.dueDate = dueDate
    }
}

public struct BatchResponse: Codable {
    public let success: Bool
    public let taskCount: Int
    public let tasks: [BatchTask]
    public let message: String
}

public struct BatchTask: Codable {
    public let pageId: String
    public let title: String
    public let priority: String
    public let dueDate: String?
}

public struct SmartSurfaceResponse: Codable {
    public let recommendations: [Recommendation]
    public let overallAdvice: String
}

public struct Recommendation: Codable, Identifiable {
    public let id = UUID()
    public let taskId: String?   // real backend task ID (from JSON "id" field)
    public let index: Int
    public let title: String
    public let reason: String
    public let priority: String?
    public let context: String?

    enum CodingKeys: String, CodingKey {
        case taskId = "id"
        case index, title, reason, priority, context
    }
}

// MARK: - API Service

/// Cross-platform API service for TomOS.
/// Works on both iOS and macOS with platform-specific URL handling.
public class APIService {
    public static let shared = APIService()
    private let baseURL = "https://tomos-task-api.vercel.app"

    // MARK: - Task Creation

    /// Creates a single task with tag support
    /// - Parameters:
    ///   - task: Task title/description
    ///   - tags: Array of tag names (e.g., ["proj:mixtape", "area:work"])
    ///   - context: Optional context override (e.g., "Work", "Personal")
    /// - Returns: Task creation response with suggested tags
    public func createTask(task: String, tags: [String], context: String? = nil) async throws -> TaskResponse {
        let url = URL(string: "\(baseURL)/api/task")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "task": task,
            "tags": tags,
            "suggest_tags": true
        ]

        if let context = context {
            body["context"] = context
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(TaskResponse.self, from: data)
    }

    // MARK: - Brain Dump
    public func batchImport(tasks: String, tags: [String] = []) async throws -> BatchResponse {
        // Split tasks by newline or comma
        let taskLines = tasks
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        print("📝 Processing \(taskLines.count) tasks with tags: \(tags)")

        var createdTasks: [BatchTask] = []

        // Create each task individually using the working /api/task endpoint
        for (index, taskLine) in taskLines.enumerated() {
            print("📤 Creating task \(index + 1)/\(taskLines.count): \(taskLine)")

            let url = URL(string: "\(baseURL)/api/task")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "task": taskLine,
                "source": "TomOS iOS App",
                "tags": tags
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
            }

            // Decode single task response (handles both old and new format)
            struct SingleTaskResponse: Codable {
                let success: Bool
                let taskId: String
                let parsedTask: ParsedTaskInfo

                enum CodingKeys: String, CodingKey {
                    case success, taskId, notionPageId, parsedTask
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    success = try container.decode(Bool.self, forKey: .success)

                    // Try new format (taskId) first, fallback to old format (notionPageId)
                    if let newId = try? container.decode(String.self, forKey: .taskId) {
                        taskId = newId
                    } else {
                        taskId = try container.decode(String.self, forKey: .notionPageId)
                    }

                    parsedTask = try container.decode(ParsedTaskInfo.self, forKey: .parsedTask)
                }

                public func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(success, forKey: .success)
                    try container.encode(taskId, forKey: .taskId)
                    try container.encode(parsedTask, forKey: .parsedTask)
                }
            }

            struct ParsedTaskInfo: Codable {
                let title: String
                let priority: String
                let dueDate: String?
            }

            let taskResponse = try JSONDecoder().decode(SingleTaskResponse.self, from: data)

            createdTasks.append(BatchTask(
                pageId: taskResponse.taskId,
                title: taskResponse.parsedTask.title,
                priority: taskResponse.parsedTask.priority,
                dueDate: taskResponse.parsedTask.dueDate
            ))

            print("✅ Created: \(taskResponse.parsedTask.title)")
        }

        // Return batch response format
        return BatchResponse(
            success: true,
            taskCount: createdTasks.count,
            tasks: createdTasks,
            message: "Successfully created \(createdTasks.count) tasks"
        )
    }

    // MARK: - Smart Surface
    public func getSmartSurface() async throws -> SmartSurfaceResponse {
        let url = URL(string: "\(baseURL)/api/task/smart-surface")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SmartSurfaceResponse.self, from: data)
    }

    // MARK: - Notifications
    public func sendMorningOverview() async throws {
        let url = URL(string: "\(baseURL)/api/notifications/morning-overview")!
        _ = try await URLSession.shared.data(from: url)
    }

    public func sendEODSummary() async throws {
        let url = URL(string: "\(baseURL)/api/notifications/eod-summary")!
        _ = try await URLSession.shared.data(from: url)
    }

    // MARK: - Task Actions

    /// Updates a task in Notion
    /// - Parameters:
    ///   - taskId: The Notion page ID of the task
    ///   - title: Optional new title
    ///   - status: Optional new status
    ///   - priority: Optional new priority
    ///   - context: Optional new context array
    ///   - dueDate: Optional new due date (ISO 8601 string)
    ///   - tags: Optional new tags array
    public func updateTask(
        taskId: String,
        title: String? = nil,
        status: String? = nil,
        priority: String? = nil,
        context: [String]? = nil,
        dueDate: String? = nil,
        tags: [String]? = nil
    ) async throws {
        let url = URL(string: "\(baseURL)/api/task/\(taskId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [:]

        if let title = title { body["title"] = title }
        if let status = status { body["status"] = status }
        if let priority = priority { body["priority"] = priority }
        if let context = context { body["context"] = context }
        if let dueDate = dueDate { body["dueDate"] = dueDate }
        if let tags = tags { body["tags"] = tags }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.taskActionFailed(action: "update", statusCode: httpResponse.statusCode)
        }
    }

    /// Marks a task as completed in PostgreSQL
    /// - Parameter taskId: The task ID
    public func completeTask(taskId: String) async throws {
        // PostgreSQL endpoint: PATCH /api/task/[id]/complete
        let url = URL(string: "\(baseURL)/api/task/\(taskId)/complete")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.taskActionFailed(action: "complete", statusCode: httpResponse.statusCode)
        }

        print("✅ APIService: Task \(taskId) marked as complete")
    }

    /// Snoozes a task for a specified duration
    /// - Parameters:
    ///   - taskId: The Notion page ID of the task
    ///   - duration: Snooze duration in minutes (default: 30)
    public func snoozeTask(taskId: String, duration: Int = 30) async throws {
        let url = URL(string: "\(baseURL)/api/task/snooze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "taskId": taskId,
            "duration": duration
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.taskActionFailed(action: "snooze", statusCode: httpResponse.statusCode)
        }
    }

    /// Deletes a task (soft delete/archive)
    /// - Parameter taskId: The task ID to delete
    public func deleteTask(taskId: String) async throws {
        let url = URL(string: "\(baseURL)/api/task/\(taskId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.taskActionFailed(action: "delete", statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        print("✅ APIService: Task \(taskId) deleted")
    }

    // MARK: - Dashboard

    /// Opens the TomOS web dashboard in the default browser.
    /// Uses platform-specific URL opening: UIKit on iOS, AppKit on macOS.
    public func openDashboard() {
        guard let url = URL(string: baseURL) else { return }

        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    // MARK: - Device Registration (APNs)

    /// Registers this device's APNs token with the backend.
    /// The backend stores this token and uses it to send push notifications via APNs.
    ///
    /// - Parameter token: The APNs device token as a hex string
    /// - Throws: Network or decoding errors
    public func registerDevice(token: String) async throws {
        let url = URL(string: "\(baseURL)/api/register-device")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build registration payload with platform detection
        #if os(iOS)
        let platform = "ios"
        #elseif os(macOS)
        let platform = "macos"
        #endif

        let body: [String: Any] = [
            "device_token": token,
            "platform": platform,
            "bundle_id": Bundle.main.bundleIdentifier ?? "com.tomos.app",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("📡 APIService: Registering device token with backend...")
        print("   Endpoint: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            print("📡 APIService: Registration response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                // Try to decode success response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ APIService: Device registered successfully")
                    if let message = json["message"] as? String {
                        print("   Server message: \(message)")
                    }
                }
            } else {
                // Log error response
                let errorBody = String(data: data, encoding: .utf8) ?? "No response body"
                print("❌ APIService: Registration failed with status \(httpResponse.statusCode)")
                print("   Response: \(errorBody)")
                throw APIError.registrationFailed(statusCode: httpResponse.statusCode)
            }
        }
    }

    // MARK: - Tasks List

    /// Fetches tasks from database with optional pagination
    /// - Parameters:
    ///   - offset: Number of tasks to skip (default: 0)
    ///   - limit: Maximum number of tasks to return (default: 100)
    /// - Returns: Array of tasks
    public func getTasks(offset: Int = 0, limit: Int = 100) async throws -> [TaskItem] {
        var urlComponents = URLComponents(string: "\(baseURL)/api/all-tasks")!
        urlComponents.queryItems = [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = urlComponents.url else {
            throw APIError.networkError(statusCode: 0)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        struct TasksResponse: Codable {
            let success: Bool
            let count: Int
            let tasks: [TaskItem]
            let pagination: PaginationInfo?

            struct PaginationInfo: Codable {
                let offset: Int
                let limit: Int
                let total: Int
                let hasMore: Bool
            }
        }

        let tasksResponse = try JSONDecoder().decode(TasksResponse.self, from: data)
        return tasksResponse.tasks
    }

    // MARK: - MatterOS API

    /// Fetches all matters from the backend
    public func getMatters(status: String? = nil, priority: String? = nil, limit: Int = 50) async throws -> [Matter] {
        var components = URLComponents(string: "\(baseURL)/api/matters")!
        var queryItems: [URLQueryItem] = []

        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let priority = priority {
            queryItems.append(URLQueryItem(name: "priority", value: priority))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let mattersResponse = try JSONDecoder().decode(MattersResponse.self, from: data)
        return mattersResponse.data
    }

    /// Fetches a single matter with all related data
    public func getMatter(id: String) async throws -> Matter {
        let url = URL(string: "\(baseURL)/api/matters/\(id)")!

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let matterResponse = try JSONDecoder().decode(MatterResponse.self, from: data)
        return matterResponse.data
    }

    /// Creates a new matter
    public func createMatter(
        title: String,
        client: String,
        type: String,
        description: String? = nil,
        priority: String? = nil,
        leadCounsel: String? = nil,
        practiceArea: String? = nil,
        jurisdiction: String? = nil
    ) async throws -> Matter {
        let url = URL(string: "\(baseURL)/api/matters")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "title": title,
            "client": client,
            "type": type
        ]

        if let description = description { body["description"] = description }
        if let priority = priority { body["priority"] = priority }
        if let leadCounsel = leadCounsel { body["leadCounsel"] = leadCounsel }
        if let practiceArea = practiceArea { body["practiceArea"] = practiceArea }
        if let jurisdiction = jurisdiction { body["jurisdiction"] = jurisdiction }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let matterResponse = try JSONDecoder().decode(MatterResponse.self, from: data)
        return matterResponse.data
    }

    /// Updates an existing matter
    public func updateMatter(
        id: String,
        title: String? = nil,
        description: String? = nil,
        status: String? = nil,
        priority: String? = nil
    ) async throws -> Matter {
        let url = URL(string: "\(baseURL)/api/matters/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [:]
        if let title = title { body["title"] = title }
        if let description = description { body["description"] = description }
        if let status = status { body["status"] = status }
        if let priority = priority { body["priority"] = priority }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.taskActionFailed(action: "update matter", statusCode: httpResponse.statusCode)
        }

        let matterResponse = try JSONDecoder().decode(MatterResponse.self, from: data)
        return matterResponse.data
    }

    /// Deletes a matter (soft delete/archive)
    /// - Parameter matterId: The matter ID to delete
    public func deleteMatter(matterId: String) async throws {
        let url = URL(string: "\(baseURL)/api/matters/\(matterId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.networkError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        print("✅ APIService: Matter \(matterId) deleted")
    }

    /// Fetches documents for a matter
    public func getMatterDocuments(matterId: String) async throws -> [MatterDocument] {
        let url = URL(string: "\(baseURL)/api/matters/\(matterId)/documents")!

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let documentsResponse = try JSONDecoder().decode(MatterDocumentsResponse.self, from: data)
        return documentsResponse.data
    }

    /// Fetches events (activity timeline) for a matter
    public func getMatterEvents(matterId: String) async throws -> [MatterEvent] {
        let url = URL(string: "\(baseURL)/api/matters/\(matterId)/events")!

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let eventsResponse = try JSONDecoder().decode(MatterEventsResponse.self, from: data)
        return eventsResponse.data
    }

    /// Fetches notes for a matter
    public func getMatterNotes(matterId: String) async throws -> [MatterNote] {
        let url = URL(string: "\(baseURL)/api/matters/\(matterId)/notes")!

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let notesResponse = try JSONDecoder().decode(MatterNotesResponse.self, from: data)
        return notesResponse.data
    }

    // MARK: - FitnessOS API (Commented out - not used, user has no Apple Watch)

    /*
    /// Fetches gym sessions with optional filtering
    public func getGymSessions(type: String? = nil, limit: Int = 20) async throws -> [GymSession] {
        var components = URLComponents(string: "\(baseURL)/api/gym/sessions")!
        var queryItems: [URLQueryItem] = []

        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let sessionsResponse = try JSONDecoder().decode(GymSessionsResponse.self, from: data)
        return sessionsResponse.data
    }

    /// Fetches a single gym session by ID
    public func getGymSession(id: String) async throws -> GymSession {
        let url = URL(string: "\(baseURL)/api/gym/sessions/\(id)")!

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let sessionResponse = try JSONDecoder().decode(GymSessionResponse.self, from: data)
        return sessionResponse.data
    }

    /// Fetches all exercises with optional filtering
    public func getExercises(category: String? = nil, search: String? = nil) async throws -> [ExerciseInfo] {
        var components = URLComponents(string: "\(baseURL)/api/gym/exercises")!
        var queryItems: [URLQueryItem] = []

        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let exercisesResponse = try JSONDecoder().decode(ExercisesResponse.self, from: data)
        return exercisesResponse.data
    }
    */

    // MARK: - Fitness API (Commented out - not used, user has no Apple Watch)

    /*
    /// Gets session suggestion with exercise-level weight recommendations
    public func getSessionSuggestion(weekType: String? = nil) async throws -> SessionSuggestion {
        var components = URLComponents(string: "\(baseURL)/api/gym/suggest")!

        if let weekType = weekType {
            components.queryItems = [URLQueryItem(name: "weekType", value: weekType)]
        }

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let suggestionResponse = try JSONDecoder().decode(SuggestionResponse.self, from: data)
        return suggestionResponse.data
    }

    /// Quick log a gym session by exercise name
    public func quickLogSession(
        sessionType: String,
        exercises: [QuickLogExerciseInput],
        weekType: String? = nil,
        notes: String? = nil,
        overallRPE: Int? = nil
    ) async throws -> GymSession {
        let url = URL(string: "\(baseURL)/api/gym/log")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "sessionType": sessionType,
            "exercises": exercises.map { ex in
                var dict: [String: Any] = [
                    "name": ex.name,
                    "sets": ex.sets
                ]
                if let weight = ex.weight { dict["weight"] = weight }
                if let reps = ex.reps { dict["reps"] = reps }
                if let rpe = ex.rpe { dict["rpe"] = rpe }
                return dict
            }
        ]

        if let weekType = weekType { body["weekType"] = weekType }
        if let notes = notes { body["notes"] = notes }
        if let overallRPE = overallRPE { body["overallRPE"] = overallRPE }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let logResponse = try JSONDecoder().decode(QuickLogResponse.self, from: data)
        return logResponse.data
    }

    /// Fetches running stats (7-day, 30-day, load trend)
    public func getRunningStats() async throws -> RunningStats {
        let url = URL(string: "\(baseURL)/api/gym/running/stats")!

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let statsResponse = try JSONDecoder().decode(RunningStatsResponse.self, from: data)
        return statsResponse.data
    }
    */

    // MARK: - Notes API

    /// Fetches all notes with optional filtering and pagination
    /// - Parameters:
    ///   - status: Filter by status (draft, active, archived)
    ///   - priority: Filter by priority (low, medium, high, urgent)
    ///   - pinned: Filter pinned notes only
    ///   - offset: Number of notes to skip (default: 0)
    ///   - limit: Maximum number of notes to return (default: 50)
    /// - Returns: Array of notes
    public func getNotes(
        status: String? = nil,
        priority: String? = nil,
        pinned: Bool? = nil,
        offset: Int = 0,
        limit: Int = 50
    ) async throws -> [Note] {
        var urlComponents = URLComponents(string: "\(baseURL)/api/notes")!
        var queryItems: [URLQueryItem] = []

        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let priority = priority {
            queryItems.append(URLQueryItem(name: "priority", value: priority))
        }
        if let pinned = pinned {
            queryItems.append(URLQueryItem(name: "pinned", value: String(pinned)))
        }
        queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))

        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems

        let url = urlComponents.url!
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let notesResponse = try JSONDecoder().decode(NotesResponse.self, from: data)
        return notesResponse.data
    }

    /// Creates a new note
    /// - Parameters:
    ///   - title: Note title
    ///   - content: Note content (markdown supported)
    ///   - tags: Array of tags
    ///   - priority: Priority level (optional)
    ///   - confidential: Whether note is confidential (optional)
    /// - Returns: Created note
    public func createNote(
        title: String,
        content: String,
        tags: [String],
        priority: String? = nil,
        confidential: Bool? = nil
    ) async throws -> Note {
        let url = URL(string: "\(baseURL)/api/notes")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "title": title,
            "content": content,
            "tags": tags
        ]

        if let priority = priority {
            body["priority"] = priority
        }
        if let confidential = confidential {
            body["confidential"] = confidential
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let noteResponse = try JSONDecoder().decode(NoteResponse.self, from: data)
        return noteResponse.data
    }

    /// Fetches a single note by ID
    /// - Parameter id: Note ID
    /// - Returns: Note details
    public func getNote(id: String) async throws -> Note {
        let url = URL(string: "\(baseURL)/api/notes/\(id)")!

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let noteResponse = try JSONDecoder().decode(NoteResponse.self, from: data)
        return noteResponse.data
    }

    /// Updates a note
    /// - Parameters:
    ///   - id: Note ID
    ///   - title: New title (optional)
    ///   - content: New content (optional)
    ///   - tags: New tags array (optional)
    ///   - priority: New priority (optional)
    ///   - status: New status (optional)
    /// - Returns: Updated note
    public func updateNote(
        id: String,
        title: String? = nil,
        content: String? = nil,
        tags: [String]? = nil,
        isPinned: Bool? = nil,
        priority: String? = nil,
        status: String? = nil,
        confidential: Bool? = nil
    ) async throws -> Note {
        let url = URL(string: "\(baseURL)/api/notes/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [:]

        if let title = title { body["title"] = title }
        if let content = content { body["content"] = content }
        if let tags = tags { body["tags"] = tags }
        if let isPinned = isPinned { body["isPinned"] = isPinned }
        if let priority = priority { body["priority"] = priority }
        if let status = status { body["status"] = status }
        if let confidential = confidential { body["confidential"] = confidential }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let noteResponse = try JSONDecoder().decode(NoteResponse.self, from: data)
        return noteResponse.data
    }

    /// Deletes a note
    /// - Parameter id: Note ID
    public func deleteNote(id: String) async throws {
        let url = URL(string: "\(baseURL)/api/notes/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }
    }

    /// Fetches all note templates
    /// - Returns: Template data with categorized templates
    public func getNoteTemplates() async throws -> TemplateData {
        let url = URL(string: "\(baseURL)/api/notes/templates")!

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let templatesResponse = try JSONDecoder().decode(TemplatesResponse.self, from: data)
        return templatesResponse.data
    }

    /// Creates a note from a template
    /// - Parameters:
    ///   - templateId: Template ID to use
    ///   - title: Custom title for the note
    /// - Returns: Created note
    public func createNoteFromTemplate(templateId: String, title: String) async throws -> Note {
        let url = URL(string: "\(baseURL)/api/notes/templates?id=\(templateId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["title": title]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let noteResponse = try JSONDecoder().decode(NoteResponse.self, from: data)
        return noteResponse.data
    }

    /// Searches notes by query
    /// - Parameters:
    ///   - query: Search query string
    ///   - tags: Optional tag filter
    ///   - limit: Maximum results (default: 20)
    /// - Returns: Array of matching notes
    public func searchNotes(query: String, tags: [String]? = nil, limit: Int = 20) async throws -> [Note] {
        var urlComponents = URLComponents(string: "\(baseURL)/api/notes/search")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let tags = tags, !tags.isEmpty {
            queryItems.append(URLQueryItem(name: "tags", value: tags.joined(separator: ",")))
        }

        urlComponents.queryItems = queryItems

        let url = urlComponents.url!
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let notesResponse = try JSONDecoder().decode(NotesResponse.self, from: data)
        return notesResponse.data
    }

    /// Fetches backlinks for a note (notes that link to this note)
    /// - Parameter id: Note ID
    /// - Returns: Array of notes that link to this note
    public func getNoteBacklinks(id: String) async throws -> [Note] {
        let url = URL(string: "\(baseURL)/api/notes/\(id)/backlinks")!

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        let backlinksResponse = try JSONDecoder().decode(BacklinksResponse.self, from: data)
        return backlinksResponse.data
    }

    /// Performs an action on a note (duplicate, archive, convert-to-task, etc.)
    /// - Parameters:
    ///   - id: Note ID
    ///   - action: Action type (duplicate, archive, convert-to-task, set-review-date)
    ///   - parameters: Optional action parameters
    /// - Returns: Action result (may return a new note for some actions)
    public func performNoteAction(id: String, action: String, parameters: [String: String]? = nil) async throws -> NoteResponse {
        let url = URL(string: "\(baseURL)/api/notes/\(id)/actions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["action": action]
        if let parameters = parameters {
            body["parameters"] = parameters
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw APIError.networkError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(NoteResponse.self, from: data)
    }
}

/// MARK: - API Errors

public enum APIError: LocalizedError {
    case registrationFailed(statusCode: Int)
    case taskActionFailed(action: String, statusCode: Int)
    case networkError(statusCode: Int)
    case networkUnavailable
    case notFound(resource: String)
    case unauthorized
    case serverError
    case timeout

    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection"
        case .notFound(let resource):
            return "\(resource.capitalized) not found"
        case .unauthorized:
            return "Please log in again"
        case .serverError:
            return "Server error occurred"
        case .timeout:
            return "Request took too long"
        case .registrationFailed(let statusCode):
            if statusCode == 401 {
                return "Device registration failed - authentication required"
            } else if statusCode >= 500 {
                return "Device registration failed - server error"
            }
            return "Unable to register device for notifications"
        case .taskActionFailed(let action, let statusCode):
            if statusCode == 404 {
                return "Task not found - it may have been deleted"
            } else if statusCode >= 500 {
                return "Unable to \(action) task - server error"
            }
            return "Failed to \(action) task"
        case .networkError(let statusCode):
            if statusCode == 0 {
                return "No internet connection"
            } else if statusCode == 401 || statusCode == 403 {
                return "Please check your permissions"
            } else if statusCode == 404 {
                return "The requested item was not found"
            } else if statusCode >= 500 {
                return "Server is experiencing issues"
            }
            return "Network request failed"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable, .networkError(0):
            return "Check your internet connection and try again"
        case .timeout:
            return "Try again on a faster connection"
        case .unauthorized:
            return "Sign out and sign back in"
        case .serverError:
            return "Wait a moment and try again"
        case .networkError(let code) where code >= 500:
            return "Wait a moment and try again"
        case .notFound:
            return "Refresh the list to see current items"
        default:
            return "Try again or contact support if the problem persists"
        }
    }

    public var failureReason: String? {
        switch self {
        case .networkUnavailable:
            return "Device is not connected to the internet"
        case .timeout:
            return "The server took too long to respond"
        case .unauthorized:
            return "Your session may have expired"
        case .serverError:
            return "The server encountered an internal error"
        default:
            return nil
        }
    }
}

