import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationView {
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
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.black)
                        Text("Notion Database")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundColor(.blue)
                        Text("Ntfy Notifications")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.red)
                        Text("Google Calendar")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.purple)
                        Text("Microsoft Teams")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
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

#Preview {
    MoreView()
}
