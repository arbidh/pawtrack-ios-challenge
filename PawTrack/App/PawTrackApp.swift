import SwiftUI

@main
struct PawTrackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Placeholder root view — replace or modify as needed.
struct ContentView: View {
    var body: some View {
        TabView {
            // TODO: Replace with your visit list view
            Text("Visits")
                .tabItem {
                    Label("Visits", systemImage: "list.clipboard")
                }

            // Optional: Add additional tabs if needed
            Text("Settings")
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
