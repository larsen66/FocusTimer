import Foundation

enum TimerMode: Sendable, Hashable {
    case pomodoro
    case custom(seconds: Int)

    var displayName: String {
        switch self {
        case .pomodoro: return "Pomodoro"
        case .custom(let s): return "Custom (\(s / 60)m)"
        }
    }

    var workDuration: Int {
        switch self {
        case .pomodoro: return 25 * 60
        case .custom(let s): return s
        }
    }

    var breakDuration: Int {
        switch self {
        case .pomodoro: return 5 * 60
        case .custom: return 0
        }
    }
}

extension TimerMode: Codable {
    enum CodingKeys: String, CodingKey { case type, seconds }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        if type == "pomodoro" {
            self = .pomodoro
        } else {
            let s = try c.decode(Int.self, forKey: .seconds)
            self = .custom(seconds: s)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pomodoro:
            try c.encode("pomodoro", forKey: .type)
        case .custom(let s):
            try c.encode("custom", forKey: .type)
            try c.encode(s, forKey: .seconds)
        }
    }
}
