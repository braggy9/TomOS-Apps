import SwiftUI

// MARK: - Notification Names for Navigation (Siri, Widgets, etc.)

extension Notification.Name {
    static let openBrainDump = Notification.Name("openBrainDump")
    static let openSmartSurface = Notification.Name("openSmartSurface")
    static let openQuickCapture = Notification.Name("openQuickCapture")
    static let openQuickAdd = Notification.Name("openQuickAdd")
}

struct ContentView: View {
    @State private var selectedTab = 0

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

            QuickActionsView()
                .tabItem {
                    Label("Quick Actions", systemImage: "bolt.circle")
                }
                .tag(2)

            NavigationStack {
                CalendarSyncView()
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(3)

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .tag(4)
        }
        .tint(.purple)
        .onReceive(NotificationCenter.default.publisher(for: .openBrainDump)) { _ in
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSmartSurface)) { _ in
            selectedTab = 1
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
