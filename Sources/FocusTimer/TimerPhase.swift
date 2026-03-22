import Foundation

enum TimerPhase: String, Sendable, Codable, Equatable {
    case idle
    case work
    case `break`
}
