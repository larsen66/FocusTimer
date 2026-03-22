import Foundation
import Observation

@MainActor
@Observable
final class TimerEngine {
    // Configurable from Settings
    var sessionDuration: Int = 25 * 60 {
        didSet { if !hasStarted { reset() } }
    }

    private(set) var remainingSeconds: Int = 25 * 60
    private(set) var isRunning: Bool = false
    private(set) var hasStarted: Bool = false
    private(set) var completedToday: Int = 0

    var currentTask: String = ""
    var selectedNote: NoteItem? = nil

    var focusModeEnabled: Bool = false

    var onTick: (@MainActor (String) -> Void)?
    var onStart: (@MainActor () -> Void)?
    var onComplete: (@MainActor (Session) -> Void)?

    private var dispatchTimer: DispatchSourceTimer?
    private var sessionStartDate: Date?

    var progress: Double {
        guard sessionDuration > 0 else { return 0 }
        return Double(sessionDuration - remainingSeconds) / Double(sessionDuration)
    }

    var formattedTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    func start() {
        guard !isRunning else { return }
        if !hasStarted {
            remainingSeconds = sessionDuration
            sessionStartDate = Date()
            hasStarted = true
        onStart?()
        }
        isRunning = true
        scheduleTimer()
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        dispatchTimer?.cancel()
        dispatchTimer = nil
    }

    func resume() {
        guard !isRunning, hasStarted else { return }
        isRunning = true
        scheduleTimer()
    }

    func stop() {
        isRunning = false
        hasStarted = false
        dispatchTimer?.cancel()
        dispatchTimer = nil
        reset()
    }

    // MARK: - Private

    private func scheduleTimer() {
        dispatchTimer?.cancel()
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + 1, repeating: 1.0, leeway: .milliseconds(50))
        source.setEventHandler { [weak self] in self?.tick() }
        source.resume()
        dispatchTimer = source
    }

    private func tick() {
        guard isRunning else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            onTick?(formattedTime)
        } else {
            complete()
        }
    }

    private func complete() {
        dispatchTimer?.cancel()
        dispatchTimer = nil
        isRunning = false
        hasStarted = false
        completedToday += 1

        let session = Session(
            taskName: currentTask.isEmpty ? "—" : currentTask,
            noteTitle: selectedNote?.title,
            startDate: sessionStartDate ?? Date(),
            durationSeconds: sessionDuration
        )
        onComplete?(session)
        reset()
    }

    private func reset() {
        remainingSeconds = sessionDuration
        onTick?(formattedTime)
    }
}
