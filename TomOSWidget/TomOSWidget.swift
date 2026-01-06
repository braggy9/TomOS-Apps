import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

// MARK: - Timeline Provider

struct TomOSProvider: TimelineProvider {
    func placeholder(in context: Context) -> TomOSEntry {
        TomOSEntry(date: Date(), topTask: "Loading...", taskCount: 0, taskId: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TomOSEntry) -> Void) {
        let entry = TomOSEntry(date: Date(), topTask: "Review contract", taskCount: 5, taskId: "preview")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TomOSEntry>) -> Void) {
        fetchTopTask { topTask, count, taskId in
            let entry = TomOSEntry(date: Date(), topTask: topTask, taskCount: count, taskId: taskId)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchTopTask(completion: @escaping (String, Int, String?) -> Void) {
        guard let url = URL(string: "https://tomos-task-api.vercel.app/api/task/smart-surface") else {
            completion("Add a task", 0, nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let recommendations = json["recommendations"] as? [[String: Any]],
                  let firstTask = recommendations.first,
                  let title = firstTask["title"] as? String else {
                completion("Add a task", 0, nil)
                return
            }

            let taskId = firstTask["id"] as? String
            completion(title, recommendations.count, taskId)
        }.resume()
    }
}

// MARK: - Timeline Entry

struct TomOSEntry: TimelineEntry {
    let date: Date
    let topTask: String
    let taskCount: Int
    let taskId: String?
}

// MARK: - Interactive Widget Intents (iOS 17+)

@available(iOS 17.0, *)
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var description = IntentDescription("Mark the current task as complete")

    @Parameter(title: "Task ID")
    var taskId: String?

    init() {}

    init(taskId: String?) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        guard let taskId = taskId else { return .result() }

        // Call API to complete task
        guard let url = URL(string: "https://tomos-task-api.vercel.app/api/task/\(taskId)/complete") else {
            return .result()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        _ = try? await URLSession.shared.data(for: request)

        return .result()
    }
}

@available(iOS 17.0, *)
struct SnoozeTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Snooze Task"
    static var description = IntentDescription("Snooze the current task for 30 minutes")

    @Parameter(title: "Task ID")
    var taskId: String?

    init() {}

    init(taskId: String?) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        guard let taskId = taskId else { return .result() }

        guard let url = URL(string: "https://tomos-task-api.vercel.app/api/task/\(taskId)/snooze") else {
            return .result()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        _ = try? await URLSession.shared.data(for: request)

        return .result()
    }
}

// MARK: - Widget Views

struct TomOSWidgetEntryView: View {
    var entry: TomOSProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (Home Screen)

struct SmallWidgetView: View {
    var entry: TomOSEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("TomOS")
                    .font(.headline)
                    .foregroundColor(.purple)
            }

            Spacer()

            Text(entry.topTask)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(.primary)

            Spacer()

            // Interactive buttons (iOS 17+)
            #if os(iOS)
            if #available(iOS 17.0, *) {
                HStack(spacing: 8) {
                    Button(intent: CompleteTaskIntent(taskId: entry.taskId)) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)

                    Button(intent: SnoozeTaskIntent(taskId: entry.taskId)) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Link(destination: URL(string: "tomos://quick-add")!) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.purple)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.purple)
                    Text("Quick Add")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            #else
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.purple)
                Text("Quick Add")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            #endif
        }
        .padding()
        #if os(iOS)
        .containerBackground(.fill.tertiary, for: .widget)
        #endif
    }
}

// MARK: - Medium Widget (Home Screen)

struct MediumWidgetView: View {
    var entry: TomOSEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Quick Add
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("TomOS")
                        .font(.headline)
                        .foregroundColor(.purple)
                }

                Spacer()

                Link(destination: URL(string: "tomos://quick-add")!) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Quick Add")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple)
                    .cornerRadius(20)
                }
            }

            Divider()

            // Right side - Top Task with actions
            VStack(alignment: .leading, spacing: 4) {
                Text("Next Up")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(entry.topTask)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Spacer()

                // Interactive buttons (iOS 17+)
                #if os(iOS)
                if #available(iOS 17.0, *) {
                    HStack(spacing: 12) {
                        Button(intent: CompleteTaskIntent(taskId: entry.taskId)) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                Text("Done")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        Button(intent: SnoozeTaskIntent(taskId: entry.taskId)) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text("Later")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if entry.taskCount > 0 {
                            Text("\(entry.taskCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    if entry.taskCount > 0 {
                        Text("\(entry.taskCount) tasks")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                #else
                if entry.taskCount > 0 {
                    Text("\(entry.taskCount) tasks")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        #if os(iOS)
        .containerBackground(.fill.tertiary, for: .widget)
        #endif
    }
}

// MARK: - Lock Screen Circular Widget

struct CircularWidgetView: View {
    var entry: TomOSEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .widgetURL(URL(string: "tomos://quick-add"))
    }
}

// MARK: - Lock Screen Rectangular Widget

struct RectangularWidgetView: View {
    var entry: TomOSEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("TomOS")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(entry.topTask)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .widgetURL(URL(string: "tomos://open"))
    }
}

// MARK: - Live Activity Attributes (iOS only)

#if os(iOS)
struct TomOSActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var taskTitle: String
        var taskContext: String
        var startTime: Date
        var isUrgent: Bool
    }

    var taskId: String
}

// MARK: - Live Activity Widget

@available(iOS 16.2, *)
struct TomOSLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TomOSActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(elapsedTime(from: context.state.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.taskTitle)
                            .font(.headline)
                            .lineLimit(2)
                        if !context.state.taskContext.isEmpty {
                            Text(context.state.taskContext)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                Image(systemName: context.state.isUrgent ? "exclamationmark.circle.fill" : "brain.head.profile")
                    .foregroundColor(context.state.isUrgent ? .red : .purple)
            } compactTrailing: {
                Text(elapsedTime(from: context.state.startTime))
                    .font(.caption2)
            } minimal: {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
            }
        }
    }

    private func elapsedTime(from startTime: Date) -> String {
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
    }
}

// MARK: - Lock Screen Live Activity View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TomOSActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Left icon
            ZStack {
                Circle()
                    .fill(context.state.isUrgent ? Color.red.opacity(0.2) : Color.purple.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: context.state.isUrgent ? "exclamationmark.circle.fill" : "brain.head.profile")
                    .foregroundColor(context.state.isUrgent ? .red : .purple)
                    .font(.title2)
            }

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text("Working on")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(context.state.taskTitle)
                    .font(.headline)
                    .lineLimit(1)
                if !context.state.taskContext.isEmpty {
                    Text(context.state.taskContext)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Timer
            VStack(alignment: .trailing) {
                Text(context.state.startTime, style: .timer)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.8))
    }
}
#endif

// MARK: - Widget Bundle

@main
struct TomOSWidgetBundle: WidgetBundle {
    var body: some Widget {
        TomOSWidget()
        #if os(iOS)
        if #available(iOS 16.2, *) {
            TomOSLiveActivity()
        }
        #endif
    }
}

// MARK: - Standard Widget Configuration

struct TomOSWidget: Widget {
    let kind: String = "TomOSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TomOSProvider()) { entry in
            TomOSWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TomOS")
        .description("Quick access to your tasks and add new ones.")
        #if os(iOS)
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
        #else
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
        #endif
    }
}
