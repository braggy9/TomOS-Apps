import Foundation
import UIKit

class APIService {
    static let shared = APIService()
    private let baseURL = "https://tomos-task-api.vercel.app"

    // MARK: - Brain Dump
    func batchImport(tasks: String) async throws -> BatchResponse {
        // Split tasks by newline or comma
        let taskLines = tasks
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        print("📝 Processing \(taskLines.count) tasks")

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
                "source": "TomOS iOS App"
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
            }

            // Decode single task response
            struct SingleTaskResponse: Codable {
                let success: Bool
                let notionPageId: String
                let parsedTask: ParsedTaskInfo
            }

            struct ParsedTaskInfo: Codable {
                let title: String
                let priority: String
                let dueDate: String?
            }

            let taskResponse = try JSONDecoder().decode(SingleTaskResponse.self, from: data)

            createdTasks.append(BatchTask(
                pageId: taskResponse.notionPageId,
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
    func getSmartSurface() async throws -> SmartSurfaceResponse {
        let url = URL(string: "\(baseURL)/api/task/smart-surface")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SmartSurfaceResponse.self, from: data)
    }

    // MARK: - Notifications
    func sendMorningOverview() async throws {
        let url = URL(string: "\(baseURL)/api/notifications/morning-overview")!
        _ = try await URLSession.shared.data(from: url)
    }

    func sendEODSummary() async throws {
        let url = URL(string: "\(baseURL)/api/notifications/eod-summary")!
        _ = try await URLSession.shared.data(from: url)
    }

    // MARK: - Dashboard
    func openDashboard() {
        if let url = URL(string: baseURL) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Response Models
struct BatchResponse: Codable {
    let success: Bool
    let taskCount: Int
    let tasks: [BatchTask]
    let message: String
}

struct BatchTask: Codable {
    let pageId: String
    let title: String
    let priority: String
    let dueDate: String?
}

struct SmartSurfaceResponse: Codable {
    let recommendations: [Recommendation]
    let overallAdvice: String
}

struct Recommendation: Codable, Identifiable {
    let id = UUID()
    let index: Int
    let title: String
    let reason: String
    let priority: String?
    let context: String?

    enum CodingKeys: String, CodingKey {
        case index, title, reason, priority, context
    }
}
