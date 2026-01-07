import SwiftUI

/// Temporary toast notification that appears at top of screen and auto-dismisses
struct ToastView: View {
    let message: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(color)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

/// View modifier to show toast notifications
struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Content) -> some View {
        ZStack {
            content

            if let toast = toast {
                VStack {
                    ToastView(
                        message: toast.message,
                        icon: toast.icon,
                        color: toast.color
                    )
                    .padding(.top, 50)
                    .transition(.move(edge: .top).combined(with: .opacity))

                    Spacer()
                }
                .zIndex(999)
            }
        }
        .onChange(of: toast) { newValue in
            if newValue != nil {
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut) {
                        toast = nil
                    }
                }
            }
        }
    }
}

extension View {
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

/// Toast configuration model
struct Toast: Equatable {
    let message: String
    let icon: String
    let color: Color

    static func success(_ message: String) -> Toast {
        Toast(message: message, icon: "checkmark.circle.fill", color: .green)
    }

    static func error(_ message: String) -> Toast {
        Toast(message: message, icon: "exclamationmark.circle.fill", color: .red)
    }

    static func info(_ message: String) -> Toast {
        Toast(message: message, icon: "info.circle.fill", color: .blue)
    }

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.message == rhs.message && lhs.icon == rhs.icon
    }
}
