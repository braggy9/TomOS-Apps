import SwiftUI

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

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .tag(3)
        }
        .tint(.purple)
    }
}

#Preview {
    ContentView()
}
