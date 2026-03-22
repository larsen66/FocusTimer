import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func fireCompletion(for session: Session) {
        let fmt = DateFormatter()
        fmt.dateFormat = "MM.dd"
        let dateStr = fmt.string(from: session.startDate)
        let mins = session.durationSeconds / 60
        let content = UNMutableNotificationContent()
        content.title = session.taskName.isEmpty ? "—" : session.taskName
        content.body = "\(dateStr) · \(mins) min"
        content.sound = .default
        let req = UNNotificationRequest(identifier: "ft-\(session.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
