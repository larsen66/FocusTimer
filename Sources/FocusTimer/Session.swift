import Foundation

struct Session: Codable, Identifiable, Sendable {
    let id: UUID
    let taskName: String
    let noteTitle: String?
    let startDate: Date
    let durationSeconds: Int
    let logDurationSeconds: Int  // what gets written to Notes (may differ from actual)

    init(taskName: String, noteTitle: String? = nil, startDate: Date, durationSeconds: Int, logDurationSeconds: Int? = nil) {
        self.id = UUID()
        self.taskName = taskName
        self.noteTitle = noteTitle
        self.startDate = startDate
        self.durationSeconds = durationSeconds
        self.logDurationSeconds = logDurationSeconds ?? durationSeconds
    }
}
