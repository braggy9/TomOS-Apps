import SwiftUI

struct SmartSurfaceView: View {
    @State private var recommendations: [Recommendation] = []
    @State private var overallAdvice = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var focusedTask: Recommendation?
    @State private var focusStartTime: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Active Focus Session Banner (iOS only)
                    #if os(iOS)
                    if let task = focusedTask, let startTime = focusStartTime {
                        ActiveFocusBanner(
                            task: task,
                            startTime: startTime,
                            onStop: { stopFocusSession() }
                        )
                        .padding(.horizontal)
                    }
                    #endif

                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(.system(size: 60))
                            .foregroundStyle(.purple.gradient)

                        Text("What Should I Work On?")
                            .font(.title2.bold())

                        Text("AI-powered recommendations based on time, focus, and priorities")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)

                    // Get Recommendations Button
                    if recommendations.isEmpty {
                        Button(action: fetchRecommendations) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Get AI Recommendations")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal)
                    }

                    // Overall Advice
                    if !overallAdvice.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.purple)
                                Text("Claude's Advice")
                                    .font(.headline)
                            }

                            Text(overallAdvice)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Recommendations
                    if !recommendations.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, rec in
                                RecommendationCard(
                                    number: index + 1,
                                    recommendation: rec,
                                    isFocused: focusedTask?.title == rec.title,
                                    onStartFocus: { startFocusSession(rec) }
                                )
                            }
                        }
                        .padding(.horizontal)

                        Button(action: fetchRecommendations) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Recommendations")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    func fetchRecommendations() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await APIService.shared.getSmartSurface()
                await MainActor.run {
                    recommendations = response.recommendations
                    overallAdvice = response.overallAdvice
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to fetch recommendations: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Focus Session

    func startFocusSession(_ task: Recommendation) {
        focusedTask = task
        focusStartTime = Date()

        #if os(iOS)
        // Haptic feedback for starting focus
        HapticManager.shared.focusStarted()

        if #available(iOS 16.2, *) {
            let context = task.context ?? "Work"
            let isUrgent = task.priority?.lowercased() == "urgent"
            LiveActivityManager.shared.startTask(task.title, context: context, isUrgent: isUrgent)
        }
        #endif
    }

    func stopFocusSession() {
        focusedTask = nil
        focusStartTime = nil

        #if os(iOS)
        // Satisfying completion haptic - the dopamine hit!
        HapticManager.shared.focusEnded()

        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.completeTask()
        }
        #endif
    }
}

struct RecommendationCard: View {
    let number: Int
    let recommendation: Recommendation
    var isFocused: Bool = false
    var onStartFocus: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(number)")
                    .font(.title2.bold())
                    .foregroundColor(.purple)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.purple.opacity(0.1)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.headline)

                    if let priority = recommendation.priority {
                        Text(priority)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(priorityColor(priority).opacity(0.2))
                            .foregroundColor(priorityColor(priority))
                            .cornerRadius(4)
                    }
                }

                Spacer()

                // Focus Button (iOS only)
                #if os(iOS)
                if isFocused {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                        Text("Focusing")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
                } else {
                    Button(action: { onStartFocus?() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "scope")
                            Text("Focus")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                #endif
            }

            Text(recommendation.reason)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(isFocused ? Color.green.opacity(0.05) : Color.secondarySystemBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.green : Color.clear, lineWidth: 2)
        )
        .cornerRadius(12)
    }

    func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "urgent": return .red
        case "important": return .orange
        case "low": return .blue
        default: return .gray
        }
    }
}

// MARK: - Active Focus Banner

#if os(iOS)
struct ActiveFocusBanner: View {
    let task: Recommendation
    let startTime: Date
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Pulsing indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                    )

                Text("Focus Session Active")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)

                Spacer()

                // Timer
                Text(startTime, style: .timer)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .lineLimit(1)

                    if let context = task.context {
                        Text(context)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: onStop) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Done")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green, lineWidth: 2)
        )
        .cornerRadius(16)
    }
}
#endif

#Preview {
    SmartSurfaceView()
}
