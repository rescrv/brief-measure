import Foundation
import UserNotifications
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var notificationTime: Date {
        didSet {
            UserDefaults.standard.set(notificationTime, forKey: "notificationTime")
            scheduleNotification()
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            if notificationsEnabled {
                requestPermission()
            } else {
                cancelNotifications()
            }
        }
    }

    private init() {
        if let savedTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date {
            self.notificationTime = savedTime
        } else {
            var components = DateComponents()
            components.hour = 6
            components.minute = 0
            self.notificationTime = Calendar.current.date(from: components) ?? Date()
        }

        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    self.scheduleNotification()
                }
            }
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func scheduleNotification() {
        guard notificationsEnabled else { return }

        cancelNotifications()

        let content = UNMutableNotificationContent()
        content.title = "Daily Check-in"
        content.body = "Time for your daily questionnaire!"
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: notificationTime)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "dailyQuestionnaire", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled for \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }

    func cancelNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyQuestionnaire"])
    }

    func shouldResetQuestionnaire(lastCompletionDate: Date?) -> Bool {
        guard let lastCompletionDate = lastCompletionDate else { return false }

        let calendar = Calendar.current
        let now = Date()

        let notificationComponents = calendar.dateComponents([.hour, .minute], from: notificationTime)

        guard let todayNotificationTime = calendar.date(bySettingHour: notificationComponents.hour ?? 6,
                                                         minute: notificationComponents.minute ?? 0,
                                                         second: 0,
                                                         of: now) else {
            return false
        }

        return now >= todayNotificationTime && lastCompletionDate < todayNotificationTime
    }

    func nextNotificationTime() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let notificationComponents = calendar.dateComponents([.hour, .minute], from: notificationTime)

        guard let todayNotificationTime = calendar.date(bySettingHour: notificationComponents.hour ?? 6,
                                                         minute: notificationComponents.minute ?? 0,
                                                         second: 0,
                                                         of: now) else {
            return nil
        }

        if now < todayNotificationTime {
            return todayNotificationTime
        } else {
            return calendar.date(byAdding: .day, value: 1, to: todayNotificationTime)
        }
    }
}
