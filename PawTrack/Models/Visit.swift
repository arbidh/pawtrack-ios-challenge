import Foundation

struct ScheduledWindow: Codable {
    let start: Date
    let end: Date
}

struct Visit: Codable {
    let id: String
    let petName: String
    let petType: String
    let ownerName: String
    let address: String
    let scheduledWindow: ScheduledWindow
    let status: String
    let notes: String
    let photos: [String]
    let specialInstructions: String
}
