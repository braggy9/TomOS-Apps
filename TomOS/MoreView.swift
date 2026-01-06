import SwiftUI
import UserNotifications

/// View model that checks actual service connectivity
@MainActor
class MoreViewModel: ObservableObject {
    @Published var notionStatus: ServiceStatus = .checking
    @Published var apnsStatus: ServiceStatus = .checking
    @Published var calendarStatus: ServiceStatus = .notConfigured
    @Published var m365Status: ServiceStatus = .notConfigured

    enum ServiceStatus: Equatable {
        case checking
        case connected
        case disconnected
        case notConfigured

        var icon: String {
            switch self {
            case .checking: return "clock"
            case .connected: return "checkmark.circle.fill"
            case .disconnected: return "xmark.circle.fill"
            case .notConfigured: return "minus.circle"
            }
        }

        var color: Color {
            switch self {
            case .checking: return .gray
            case .connected: return .green
            case .disconnected: return .red
            case .notConfigured: return .orange
            }
        }

        var label: String {
            switch self {
            case .checking: return "Checking..."
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            case .notConfigured: return "Not Configured"
            }
        }
    }

    func checkConnections() {
        Task {
            await checkNotion()
            await checkAPNs()
            // Calendar integrations are optional - check if configured
            await checkCalendarIntegrations()
        }
    }

    private func checkNotion() async {
        do {
            // Try to fetch health endpoint which tests Notion connection
            let url = URL(string: "https://tomos-task-api.vercel.app/api/health")!
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                notionStatus = .connected
            } else {
                notionStatus = .disconnected
            }
        } catch {
            notionStatus = .disconnected
        }
    }

    private func checkAPNs() async {
        // Check if we have a device token stored (APNs registration succeeded)
        #if os(iOS)
        let hasToken = UserDefaults.standard.string(forKey: "apns_device_token") != nil
        #else
        let hasToken = UserDefaults.standard.string(forKey: "apns_device_token_macos") != nil
        #endif

        // Also check if notifications are authorized
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let authorized = settings.authorizationStatus == .authorized

        if hasToken && authorized {
            apnsStatus = .connected
        } else if authorized {
            apnsStatus = .disconnected // Authorized but no token
        } else {
            apnsStatus = .notConfigured // Not authorized
        }
    }

    private func checkCalendarIntegrations() async {
        // These are optional backend integrations - show as not configured
        // unless the user has set them up in the backend
        // For now, mark as not configured since they require OAuth setup
        calendarStatus = .notConfigured
        m365Status = .notConfigured
    }
}

struct MoreView: View {
    @StateObject private var viewModel = MoreViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TomOS AI Assistant")
                                .font(.title2.bold())

                            Text("ADHD-friendly task management with Claude AI")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 50))
                            .foregroundStyle(.purple.gradient)
                    }
                    .padding(.vertical, 8)
                }

                Section("Features") {
                    FeatureRow(
                        icon: "brain.head.profile",
                        color: .purple,
                        title: "Brain Dump",
                        description: "Dump multiple tasks - Claude parses them"
                    )

                    FeatureRow(
                        icon: "target",
                        color: .orange,
                        title: "Smart Surfacing",
                        description: "AI recommendations based on context"
                    )

                    FeatureRow(
                        icon: "sunrise.fill",
                        color: .yellow,
                        title: "Morning Overview",
                        description: "Start your day with AI-powered advice"
                    )

                    FeatureRow(
                        icon: "moon.fill",
                        color: .indigo,
                        title: "EOD Summary",
                        description: "Reflect and plan for tomorrow"
                    )
                }

                Section("AI Powered By") {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("Claude Sonnet 4.5")
                        Spacer()
                        Text("Anthropic")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.purple)
                        Text("Natural Language Processing")
                    }

                    HStack {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.purple)
                        Text("Context-Aware Recommendations")
                    }
                }

                Section("Connected Services") {
                    ServiceStatusRow(
                        icon: "note.text",
                        iconColor: .black,
                        title: "Notion Database",
                        status: viewModel.notionStatus
                    )

                    ServiceStatusRow(
                        icon: "bell.badge.fill",
                        iconColor: .blue,
                        title: "APNs Push Notifications",
                        status: viewModel.apnsStatus
                    )

                    ServiceStatusRow(
                        icon: "calendar",
                        iconColor: .red,
                        title: "Google Calendar",
                        subtitle: "Optional",
                        status: viewModel.calendarStatus
                    )

                    ServiceStatusRow(
                        icon: "calendar.badge.clock",
                        iconColor: .blue,
                        title: "M365 Calendar",
                        subtitle: "Optional",
                        status: viewModel.m365Status
                    )
                }
                .onAppear {
                    viewModel.checkConnections()
                }

                Section("Version") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("iOS/iPadOS")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Text("Built with Claude Sonnet 4.5")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("About")
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ServiceStatusRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    let status: MoreViewModel.ServiceStatus

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                if status == .checking {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: status.icon)
                        .foregroundColor(status.color)
                }
            }
        }
    }
}

#Preview {
    MoreView()
}
