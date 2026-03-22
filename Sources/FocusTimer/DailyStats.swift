import Foundation

struct DailyStats: Sendable {
    let date: Date
    let totalSessions: Int
    let totalMinutes: Int
    let byTask: [(name: String, minutes: Int)]

    init(sessions: [Session], date: Date) {
        self.date = date
        self.totalSessions = sessions.count
        self.totalMinutes = sessions.reduce(0) { $0 + $1.durationSeconds } / 60
        var dict: [String: Int] = [:]
        for s in sessions { dict[s.taskName, default: 0] += s.durationSeconds / 60 }
        self.byTask = dict.sorted { $0.value > $1.value }.map { (name: $0.key, minutes: $0.value) }
    }
}
