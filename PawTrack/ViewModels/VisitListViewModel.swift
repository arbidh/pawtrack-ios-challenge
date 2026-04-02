import Foundation

// MARK: - Delegate Protocol

protocol VisitListViewModelDelegate {
    func viewModelDidUpdateVisits(_ viewModel: VisitListViewModel)
    func viewModel(_ viewModel: VisitListViewModel, didEncounterError error: Error)
}

// MARK: - View Model

class VisitListViewModel {

    // MARK: - Properties

    var delegate: VisitListViewModelDelegate?
    var visits: [Visit] = []
    var isLoading: Bool = false

    private let networkClient: NetworkClient
    private var timer: Timer?

    // MARK: - Init

    init(networkClient: NetworkClient = MockNetworkClient()) {
        self.networkClient = networkClient
    }

    // MARK: - Public Methods

    /// Fetches visits from the network and notifies the delegate.
    func fetchVisits() {
        isLoading = true
        Task {
            do {
                let fetchedVisits = try await networkClient.fetchVisits()
                self.visits = fetchedVisits
                self.isLoading = false
                self.delegate?.viewModelDidUpdateVisits(self)
            } catch {
                self.isLoading = false
                self.delegate?.viewModel(self, didEncounterError: error)
            }
        }
    }

    /// Starts polling for visit updates every 30 seconds.
    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.fetchVisits()
        }
    }

    /// Stops the polling timer.
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    /// Returns visits filtered by the given status string.
    func visits(withStatus status: String) -> [Visit] {
        return visits.filter { $0.status == status }
    }
}
