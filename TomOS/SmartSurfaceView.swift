import SwiftUI

struct SmartSurfaceView: View {
    @State private var recommendations: [Recommendation] = []
    @State private var overallAdvice = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
                                    recommendation: rec
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
            .navigationBarTitleDisplayMode(.inline)
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
}

struct RecommendationCard: View {
    let number: Int
    let recommendation: Recommendation

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
            }

            Text(recommendation.reason)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
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

#Preview {
    SmartSurfaceView()
}
