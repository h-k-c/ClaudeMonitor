import Foundation
import UserNotifications

/// Usage threshold notifications
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    private var notifiedThresholds = Set<Int>()
    private var lastKnownResetDate: Date?
    private var notifiedRoutineRunsLow = false
    private var notifiedRoutineRunsExhausted = false

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func checkAndNotify(data: UsageData) {
        checkUsageThresholds(data: data)
        checkSessionReset(data: data)
        checkRoutineRunsBudget(data: data)
    }

    // MARK: - Usage threshold alerts

    private func checkUsageThresholds(data: UsageData) {
        let pct = data.hasSessionData ? data.sessionPercentage : 0

        let config: [(threshold: Int, title: String, body: String)] = [
            (75, "已使用 75%", "考虑结束长对话，为新话题开启新会话。"),
            (80, "已使用 80%", "避免新项目或大文件上传。适合：快速提问、短编辑。"),
            (90, "已使用 90%", "剩余约 10%，请尽快完成当前任务。"),
            (95, "即将用尽", "请保存工作。\(data.sessionResetLabel ?? "即将重置")"),
            (100, "已达到限制", "配额已用完。\(data.sessionResetLabel ?? "即将重置")")
        ]

        for item in config {
            let fraction = Double(item.threshold) / 100.0
            if pct >= fraction {
                guard !notifiedThresholds.contains(item.threshold) else { continue }
                notifiedThresholds.insert(item.threshold)
                sendAlert(title: item.title, body: item.body, id: "claude-tip-\(item.threshold)")
            } else {
                notifiedThresholds.remove(item.threshold)
            }
        }
    }

    private func sendAlert(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Routine run budget alerts

    private func checkRoutineRunsBudget(data: UsageData) {
        guard data.hasRoutineData else { return }

        if data.routineRunsUsed == 0 {
            notifiedRoutineRunsLow = false
            notifiedRoutineRunsExhausted = false
            return
        }

        if data.routineRunsRemaining == 0 && !notifiedRoutineRunsExhausted {
            notifiedRoutineRunsExhausted = true
            notifiedRoutineRunsLow = true
            sendAlert(
                title: "今日 Routine 已用尽",
                body: "已使用全部 \(data.routineRunsLimit) 次日常 Routine。明天重置。",
                id: "claude-routine-exhausted"
            )
        } else if data.routineRunsRemaining == 1 && !notifiedRoutineRunsLow {
            notifiedRoutineRunsLow = true
            sendAlert(
                title: "剩余 1 次 Routine",
                body: "已使用 \(data.routineRunsUsed)/\(data.routineRunsLimit) 次日常 Routine。",
                id: "claude-routine-low"
            )
        }
    }

    // MARK: - Session reset detection

    private func checkSessionReset(data: UsageData) {
        guard let newReset = data.resetDate else { return }

        if let known = lastKnownResetDate, newReset > known.addingTimeInterval(3600) {
            notifiedThresholds.removeAll()
            sendAlert(
                title: "会话已重置",
                body: "用量窗口已重置，配额已恢复。",
                id: "claude-reset-\(Int(Date().timeIntervalSince1970))"
            )
        }

        lastKnownResetDate = newReset
    }
}
