#if os(iOS)
import Foundation
import ActivityKit
import SwiftUI

// MARK: - Activity Attributes

@available(iOS 16.2, *)
struct TomOSActivityAttributes: ActivityAttributes {
    // Static data (doesn't change during activity)
    public struct ContentState: Codable, Hashable {
        var taskTitle: String
        var taskContext: String
        var startTime: Date
        var isUrgent: Bool
    }

    // Fixed data set when activity starts
    var taskId: String
}

// MARK: - Live Activity Manager

@available(iOS 16.2, *)
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published private(set) var currentActivity: Activity<TomOSActivityAttributes>?

    private init() {}

    // MARK: - Start Activity

    func startTaskActivity(taskId: String, title: String, context: String, isUrgent: Bool = false) {
        // End any existing activity first
        Task {
            await endCurrentActivity()

            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                print("Live Activities not enabled")
                return
            }

            let attributes = TomOSActivityAttributes(taskId: taskId)
            let state = TomOSActivityAttributes.ContentState(
                taskTitle: title,
                taskContext: context,
                startTime: Date(),
                isUrgent: isUrgent
            )

            let content = ActivityContent(state: state, staleDate: nil)

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )

                await MainActor.run {
                    self.currentActivity = activity
                }

                print("Started Live Activity for task: \(title)")
            } catch {
                print("Failed to start Live Activity: \(error)")
            }
        }
    }

    // MARK: - Update Activity

    func updateTaskActivity(title: String, context: String, isUrgent: Bool = false) {
        guard let activity = currentActivity else { return }

        Task {
            let state = TomOSActivityAttributes.ContentState(
                taskTitle: title,
                taskContext: context,
                startTime: Date(),
                isUrgent: isUrgent
            )

            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
    }

    // MARK: - End Activity

    func endCurrentActivity() async {
        guard let activity = currentActivity else { return }

        let finalState = TomOSActivityAttributes.ContentState(
            taskTitle: "Task completed!",
            taskContext: "",
            startTime: Date(),
            isUrgent: false
        )

        let content = ActivityContent(state: finalState, staleDate: nil)
        await activity.end(content, dismissalPolicy: .immediate)

        await MainActor.run {
            self.currentActivity = nil
        }
    }

    func completeTask() {
        Task {
            await endCurrentActivity()
        }
    }

    // MARK: - End All Activities

    func endAllActivities() async {
        for activity in Activity<TomOSActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        await MainActor.run {
            self.currentActivity = nil
        }
    }
}

// MARK: - Convenience for non-async contexts

@available(iOS 16.2, *)
extension LiveActivityManager {
    func startTask(_ title: String, context: String = "Work", isUrgent: Bool = false) {
        let taskId = UUID().uuidString
        startTaskActivity(taskId: taskId, title: title, context: context, isUrgent: isUrgent)
    }
}
#endif
