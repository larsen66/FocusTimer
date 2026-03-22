import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []

    private let storageURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("FocusTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sessions.json")
    }()

    init() {
        Task { await self.load() }
    }

    func save(_ session: Session) async {
        sessions.append(session)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(sessions) else { return }
        let url = storageURL
        try? await Task.detached(priority: .utility) {
            try data.write(to: url, options: .atomic)
        }.value
    }

    private func load() async {
        let url = storageURL
        guard let data = try? await Task.detached(priority: .utility) { try Data(contentsOf: url) }.value
        else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        sessions = (try? decoder.decode([Session].self, from: data)) ?? []
    }

    func dailyStats(for date: Date = .now) -> DailyStats {
        let cal = Calendar.current
        let today = sessions.filter { cal.isDate($0.startDate, inSameDayAs: date) }
        return DailyStats(sessions: today, date: date)
    }

    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(sessions)
    }

    func exportCSV() -> String {
        var lines = ["id,task,note,start,durationSeconds"]
        let fmt = ISO8601DateFormatter()
        for s in sessions {
            lines.append("\(s.id),\"\(s.taskName)\",\"\(s.noteTitle ?? "")\",\(fmt.string(from: s.startDate)),\(s.durationSeconds)")
        }
        return lines.joined(separator: "\n")
    }
}
