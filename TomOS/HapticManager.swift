#if os(iOS)
import UIKit

/// Provides haptic feedback for various app interactions.
/// ADHD-friendly: satisfying tactile responses reinforce task completion.
class HapticManager {
    static let shared = HapticManager()

    private init() {}

    // MARK: - Feedback Generators (reusable for performance)

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    // MARK: - Task Actions

    /// Satisfying "thunk" when completing a task - the dopamine hit!
    func taskCompleted() {
        notification.notificationOccurred(.success)
    }

    /// Lighter feedback when snoozing a task
    func taskSnoozed() {
        impactLight.impactOccurred()
    }

    /// Feedback when adding a new task
    func taskAdded() {
        impactMedium.impactOccurred()
    }

    // MARK: - Focus Session

    /// Strong feedback when starting a focus session
    func focusStarted() {
        impactHeavy.impactOccurred()
    }

    /// Success feedback when ending a focus session
    func focusEnded() {
        notification.notificationOccurred(.success)
    }

    // MARK: - Navigation & UI

    /// Light tap for button presses
    func buttonTap() {
        impactLight.impactOccurred()
    }

    /// Selection change feedback (tabs, options)
    func selectionChanged() {
        selection.selectionChanged()
    }

    /// Error feedback
    func error() {
        notification.notificationOccurred(.error)
    }

    /// Warning feedback
    func warning() {
        notification.notificationOccurred(.warning)
    }

    // MARK: - Prepare (call before expected interaction for minimal latency)

    func prepareForTaskCompletion() {
        notification.prepare()
    }

    func prepareForFocus() {
        impactHeavy.prepare()
    }
}
#endif
