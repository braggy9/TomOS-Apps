import SwiftUI

// MARK: - Notification Names for Navigation (Siri, Widgets, etc.)

extension Notification.Name {
    static let openBrainDump = Notification.Name("openBrainDump")
    static let openSmartSurface = Notification.Name("openSmartSurface")
    static let openQuickCapture = Notification.Name("openQuickCapture")
    static let openQuickAdd = Notification.Name("openQuickAdd")
    static let openMatters = Notification.Name("openMatters")
    static let openNotes = Notification.Name("openNotes")
    static let openFitness = Notification.Name("openFitness")
    static let openQuickLog = Notification.Name("openQuickLog")
    static let fitnessSessionLogged = Notification.Name("fitnessSessionLogged")
}

struct ContentView: View {
    /// Persisted tab selection - user returns to last viewed tab
    @AppStorage("selectedTab") private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            BrainDumpView()
                .tabItem {
                    Label("Brain Dump", systemImage: "brain.head.profile")
                }
                .tag(0)

            SmartSurfaceView()
                .tabItem {
                    Label("What to Work On", systemImage: "target")
                }
                .tag(1)

            NavigationStack {
                MattersView()
            }
            .tabItem {
                Label("Matters", systemImage: "briefcase")
            }
            .tag(2)

            TasksView()
                .tabItem {
                    Label("My Tasks", systemImage: "checklist")
                }
                .tag(3)

            NavigationStack {
                CalendarSyncView()
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(4)

            NavigationStack {
                NotesView()
            }
            .tabItem {
                Label("Notes", systemImage: "note.text")
            }
            .tag(5)

            // MARK: - FitnessView disabled until files are added to Xcode project
            // FitnessView()
            //     .tabItem {
            //         Label("Fitness", systemImage: "figure.strengthtraining.traditional")
            //     }
            //     .tag(6)

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .tag(6)  // Was 7, now 6 since FitnessView disabled
        }
        .tint(.purple)
        .onReceive(NotificationCenter.default.publisher(for: .openBrainDump)) { _ in
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSmartSurface)) { _ in
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMatters)) { _ in
            selectedTab = 2
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNotes)) { _ in
            selectedTab = 5
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFitness)) { _ in
            selectedTab = 6
        }
        .onReceive(NotificationCenter.default.publisher(for: .openQuickAdd)) { _ in
            // Quick Add opens Brain Dump for fast task entry
            selectedTab = 0
        }
    }
}

#Preview {
    ContentView()
}
