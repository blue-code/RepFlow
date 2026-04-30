import Foundation
import UserNotifications

/// GTG 알림 스케줄러: UserNotifications 로컬 알림으로 하루 N개의 알림을 스케줄.
/// 워치는 iPhone에 도착한 알림을 자동으로 미러링한다.
final class GTGSchedulerService: GTGSchedulerProtocol {

    static let categoryIdentifier = "REPFLOW_GTG"
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            registerCategory()
            return granted
        } catch {
            return false
        }
    }

    private func registerCategory() {
        let action = UNNotificationAction(
            identifier: "REPFLOW_GTG_ACK",
            title: "지금 시작",
            options: [.foreground]
        )
        let skip = UNNotificationAction(
            identifier: "REPFLOW_GTG_SKIP",
            title: "건너뛰기",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [action, skip],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }

    func scheduleToday(profile: UserProfile) async throws {
        guard profile.gtgEnabled else { return }
        guard profile.gtgEndHour > profile.gtgStartHour else {
            throw GTGSchedulerError.invalidWindow
        }
        let granted = await requestAuthorization()
        guard granted else { throw GTGSchedulerError.notAuthorized }

        await cancelAll()

        let count = max(1, profile.gtgPromptCount)
        let exerciseKind = ExerciseKind(rawValue: profile.preferredGTGExercise) ?? .pushUp
        let perPrompt = max(1, profile.gtgDailyTarget / count)

        let totalMinutes = (profile.gtgEndHour - profile.gtgStartHour) * 60
        let interval = totalMinutes / count

        let now = Date()
        let calendar = Calendar.current
        var startComps = calendar.dateComponents([.year, .month, .day], from: now)
        startComps.hour = profile.gtgStartHour
        startComps.minute = 0
        guard let dayStart = calendar.date(from: startComps) else { return }

        for i in 0..<count {
            // 균일 분포 + 약간의 지터(jitter)로 자연스럽게
            let jitter = Int.random(in: -8...8)
            let minuteOffset = i * interval + interval / 2 + jitter
            guard let fireDate = calendar.date(byAdding: .minute, value: minuteOffset, to: dayStart),
                  fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "💪 GTG: \(exerciseKind.displayName) \(perPrompt)개"
            content.body = "지금 가볍게! 절대 한계까지 가지 말 것 (RPE 5)."
            content.sound = profile.notificationSoundEnabled ? .default : nil
            content.categoryIdentifier = Self.categoryIdentifier
            content.userInfo = [
                "exercise": exerciseKind.rawValue,
                "suggestedReps": perPrompt
            ]

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "repflow.gtg.\(i)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
