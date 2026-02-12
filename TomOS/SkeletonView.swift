import SwiftUI

// MARK: - Skeleton Loading Views
//
// Modern skeleton loading screens that show content placeholders instead of spinners.
// Provides better UX by showing the structure of content being loaded.
//
// Created: 2026-01-21
// Purpose: UI/UX Enhancement Phase 2 - Polish

/// Animated skeleton shape for loading states
struct SkeletonShape: View {
    let cornerRadius: CGFloat
    @State private var isAnimating = false

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(cornerRadius)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

/// Skeleton row for task list loading
struct SkeletonTaskRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            // Status circle
            SkeletonShape(cornerRadius: 12)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Title
                SkeletonShape(cornerRadius: DesignSystem.CornerRadius.sm)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)

                // Metadata line
                HStack(spacing: DesignSystem.Spacing.xs) {
                    SkeletonShape(cornerRadius: DesignSystem.CornerRadius.sm)
                        .frame(width: 60, height: 12)

                    SkeletonShape(cornerRadius: DesignSystem.CornerRadius.sm)
                        .frame(width: 80, height: 12)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

/// Skeleton row for matter list loading
struct SkeletonMatterRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            // Icon
            SkeletonShape(cornerRadius: DesignSystem.CornerRadius.md)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Title
                SkeletonShape(cornerRadius: DesignSystem.CornerRadius.sm)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)

                // Client
                SkeletonShape(cornerRadius: DesignSystem.CornerRadius.sm)
                    .frame(width: 120, height: 12)

                // Metadata badges
                HStack(spacing: DesignSystem.Spacing.xs) {
                    SkeletonShape(cornerRadius: DesignSystem.CornerRadius.sm)
                        .frame(width: 70, height: 12)

                    SkeletonShape(cornerRadius: DesignSystem.CornerRadius.sm)
                        .frame(width: 60, height: 12)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

/// Skeleton card for recommendations
struct SkeletonRecommendationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                // Number badge
                SkeletonShape(cornerRadius: DesignSystem.CornerRadius.lg)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Title
                    SkeletonShape(cornerRadius: DesignSystem.CornerRadius.sm)
                        .frame(height: 16)

                    // Metadata
                    SkeletonShape(cornerRadius: DesignSystem.CornerRadius.sm)
                        .frame(width: 150, height: 12)
                }

                Spacer()
            }

            // Description
            SkeletonShape(cornerRadius: DesignSystem.CornerRadius.sm)
                .frame(height: 14)

            SkeletonShape(cornerRadius: DesignSystem.CornerRadius.sm)
                .frame(height: 14)
                .frame(width: 200)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.semantic.backgrounds.secondary)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

/// Full-screen skeleton loading for task list
struct SkeletonTaskList: View {
    var count: Int = 5

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonTaskRow()
                    .padding(.horizontal, DesignSystem.Spacing.md)

                Divider()
                    .padding(.leading, 52) // Align with content
            }

            Spacer()
        }
    }
}

/// Full-screen skeleton loading for matter list
struct SkeletonMatterList: View {
    var count: Int = 5

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonMatterRow()
                    .padding(.horizontal, DesignSystem.Spacing.md)

                Divider()
                    .padding(.leading, 52) // Align with content
            }

            Spacer()
        }
    }
}

/// Skeleton loading for Smart Surface recommendations
struct SkeletonRecommendationList: View {
    var count: Int = 3

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonRecommendationCard()
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
    }
}

// MARK: - View Modifier

struct SkeletonModifier: ViewModifier {
    let isLoading: Bool
    let skeleton: () -> AnyView

    func body(content: Content) -> some View {
        ZStack {
            if isLoading {
                skeleton()
            } else {
                content
            }
        }
    }
}

extension View {
    /// Show skeleton loading view while loading
    /// - Parameters:
    ///   - isLoading: Whether to show skeleton
    ///   - skeleton: The skeleton view to display
    func skeleton<S: View>(isLoading: Bool, @ViewBuilder skeleton: @escaping () -> S) -> some View {
        modifier(SkeletonModifier(
            isLoading: isLoading,
            skeleton: { AnyView(skeleton()) }
        ))
    }
}

// MARK: - Previews

#Preview("Task Row") {
    List {
        SkeletonTaskRow()
        SkeletonTaskRow()
        SkeletonTaskRow()
    }
    .listStyle(.plain)
}

#Preview("Matter Row") {
    List {
        SkeletonMatterRow()
        SkeletonMatterRow()
        SkeletonMatterRow()
    }
    .listStyle(.plain)
}

#Preview("Recommendation Card") {
    VStack {
        SkeletonRecommendationCard()
        SkeletonRecommendationCard()
        SkeletonRecommendationCard()
        Spacer()
    }
    .padding()
}

#Preview("Task List") {
    SkeletonTaskList()
}

#Preview("Matter List") {
    SkeletonMatterList()
}

#Preview("Recommendation List") {
    SkeletonRecommendationList()
}
