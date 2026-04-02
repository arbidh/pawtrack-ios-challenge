import Foundation

// MARK: - Protocol

protocol NetworkClient {
    func fetchVisits() async throws -> [Visit]
}

// MARK: - Errors

enum NetworkError: Error {
    case fileNotFound
    case decodingFailed(Error)
    case unknown(Error)
}

// MARK: - Mock Implementation

/// Reads visit data from bundled JSON files to simulate network responses.
/// Replace this with a real API client in production.
class MockNetworkClient: NetworkClient {

    func fetchVisits() async throws -> [Visit] {
        // Simulate network latency
        try await Task.sleep(nanoseconds: 500_000_000)

        guard let url = Bundle.main.url(forResource: "visits", withExtension: "json") else {
            throw NetworkError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let visits = try decoder.decode([Visit].self, from: data)
            return visits
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
