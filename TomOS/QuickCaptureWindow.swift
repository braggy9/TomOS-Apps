#if os(macOS)
import SwiftUI
import AppKit
import UserNotifications

/// QuickCaptureWindowController manages the floating quick task capture window.
///
/// ## Design:
/// - Small floating window (400x120px)
/// - Always on top
/// - Auto-focus text field on appear
/// - Enter to submit, Escape to close
/// - Posts to /api/task
/// - Shows success notification
/// - Auto-closes after successful submit
/// - Supports pre-filled text (e.g., from Outlook email subject)
///
class QuickCaptureWindowController {

    // MARK: - Properties

    private var window: NSWindow?
    private var hostingController: NSHostingController<QuickCaptureView>?
    private var initialText: String = ""

    // MARK: - Initialization

    init() {
        print("📝 QuickCaptureWindowController: Initialized")
    }

    // MARK: - Window Management

    /// Shows the quick capture window, creating it if needed
    /// - Parameter prefillText: Optional text to pre-fill the text field
    func showWindow(prefillText: String? = nil) {
        // Store the initial text
        initialText = prefillText ?? ""

        // Always recreate window to ensure fresh state with new prefill text
        createWindow()

        guard let window = window else { return }

        // Position window in center-top of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth: CGFloat = 400
            let windowHeight: CGFloat = 120

            let x = screenFrame.midX - (windowWidth / 2)
            let y = screenFrame.maxY - windowHeight - 100  // 100px from top

            window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }

        // Show and focus
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Focus the text field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeFirstResponder(window.contentView)
        }

        print("📝 QuickCaptureWindowController: Window shown\(prefillText != nil ? " with prefill: \(prefillText!)" : "")")
    }

    /// Hides and resets the quick capture window
    func hideWindow() {
        window?.orderOut(nil)
        print("📝 QuickCaptureWindowController: Window hidden")
    }

    /// Creates the NSWindow with SwiftUI content
    private func createWindow() {
        // Create the SwiftUI view with close handler and initial text
        let quickCaptureView = QuickCaptureView(
            initialText: initialText,
            onClose: { [weak self] in
                self?.hideWindow()
            }
        )

        // Create hosting controller
        hostingController = NSHostingController(rootView: quickCaptureView)

        // Create window with specific style
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure window appearance
        window.title = "Quick Capture"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.contentViewController = hostingController

        // Keep window on top
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Handle window close
        window.isReleasedWhenClosed = false

        self.window = window

        print("📝 QuickCaptureWindowController: Window created")
    }
}

/// QuickCaptureView is the SwiftUI content for the floating quick capture window.
struct QuickCaptureView: View {
    /// Initial text to pre-fill (e.g., from Outlook email subject)
    let initialText: String

    @State private var taskText = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isTextFieldFocused: Bool

    /// Closure called when the window should close
    var onClose: () -> Void

    init(initialText: String = "", onClose: @escaping () -> Void) {
        self.initialText = initialText
        self.onClose = onClose
        // Initialize taskText with initialText
        _taskText = State(initialValue: initialText)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Text field
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.purple)
                    .font(.title2)

                TextField("What needs to be done?", text: $taskText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        submitTask()
                    }
                    .onExitCommand {
                        onClose()
                    }

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.textFieldBackground)
            .cornerRadius(10)

            // Hint text
            HStack {
                Text("Press")
                    .foregroundColor(.secondary)
                Text("Enter")
                    .font(.system(.caption, design: .rounded).bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                Text("to create task,")
                    .foregroundColor(.secondary)
                Text("Esc")
                    .font(.system(.caption, design: .rounded).bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
                Text("to close")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding(16)
        .frame(width: 400, height: 120)
        .background(VisualEffectBlur())
        .onAppear {
            isTextFieldFocused = true
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func submitTask() {
        guard !taskText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !isLoading else { return }

        isLoading = true
        let taskToCreate = taskText

        Task {
            do {
                _ = try await APIService.shared.batchImport(tasks: taskToCreate)

                await MainActor.run {
                    isLoading = false
                    print("✅ QuickCapture: Task created successfully")

                    // Show success notification
                    showSuccessNotification(task: taskToCreate)

                    // Clear and close
                    taskText = ""
                    onClose()

                    // Refresh menu bar tasks
                    MenuBarController.shared.refreshTasks()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to create task: \(error.localizedDescription)"
                    showError = true
                    print("❌ QuickCapture: Failed to create task: \(error)")
                }
            }
        }
    }

    private func showSuccessNotification(task: String) {
        let content = UNMutableNotificationContent()
        content.title = "Task Created"
        content.body = task
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

/// Visual effect blur background for the floating window
struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { }
}

#endif
