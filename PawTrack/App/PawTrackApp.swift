import SwiftUI

@main
struct PawTrackApp: App {
    /// The one place a concrete client is chosen — swapping the bundled JSON for a real
    /// API is a change here and nowhere else.
    @State private var model = VisitListViewModel(network: MockNetworkClient())

    var body: some Scene {
        WindowGroup {
            VisitListView(model: model)
        }
    }
}
