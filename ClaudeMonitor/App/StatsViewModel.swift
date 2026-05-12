import Foundation
import Observation

/// ViewModel — combines local stats file data + Claude.ai API real-time data
@Observable
final class StatsViewModel {

    // MARK: - Local stats data (from stats-cache.json)

    private(set) var stats: ClaudeStats?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // MARK: - API real-time data (from Claude.ai)

    private(set) var apiUsageData: UsageData?
    private(set) var apiIsLoading = false
    private(set) var apiNeedsLogin = false
    private(set) var apiErrorMessage: String?

    // MARK: - Dependencies

    private let repository: StatsRepositoryProtocol
    let apiService: ClaudeAPIService
    private let notifications = NotificationService.shared
    private var usageHistory: [(date: Date, pct: Double)] = []

    // MARK: - Local stats derived data

    var totalMessages: Int { stats?.totalMessages ?? 0 }
    var totalSessions: Int { stats?.totalSessions ?? 0 }
    var firstSessionDate: String { stats?.firstSessionDate ?? "" }
    var lastComputedDate: String { stats?.lastComputedDate ?? "" }

    var todayActivity: DailyActivity? {
        guard let stats else { return nil }
        let today = Date().isoDateString
        return stats.dailyActivity.last(where: { $0.date == today })
    }

    var todayMessageCount: Int { todayActivity?.messageCount ?? 0 }
    var todaySessionCount: Int { todayActivity?.sessionCount ?? 0 }

    var todayTokensByModel: [String: Int] {
        guard let stats else { return [:] }
        let today = Date().isoDateString
        return stats.dailyModelTokens.last(where: { $0.date == today })?.tokensByModel ?? [:]
    }

    var todayTotalTokens: Int {
        todayTokensByModel.values.reduce(0, +)
    }

    var modelUsageSummary: [(model: String, tokens: Int, percentage: Double)] {
        guard let stats else { return [] }
        let total = stats.modelUsage.values.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }
        guard total > 0 else { return [] }

        return stats.modelUsage.map { key, value in
            let tokens = value.inputTokens + value.outputTokens
            let pct = Double(tokens) / Double(total) * 100
            return (model: Self.shortModelName(key), tokens: tokens, percentage: pct)
        }
        .sorted { $0.percentage > $1.percentage }
    }

    var primaryModelPercentage: Int {
        // Use API data if available, otherwise fall back to local stats
        if let api = apiUsageData, api.hasSessionData {
            return Int(api.sessionPercentage * 100)
        }
        return modelUsageSummary.first.map { Int($0.percentage) } ?? 0
    }

    var primaryModel: String {
        modelUsageSummary.first?.model ?? ""
    }

    /// Today's real-time tokens (from buddy-tokens.json)
    private(set) var todayRealtimeTokens: Int = 0

    // MARK: - API data accessors (for DashboardView)

    var hasAPIData: Bool { apiUsageData != nil }

    var sessionPercentage: Double { apiUsageData?.sessionPercentage ?? 0 }
    var weeklyPercentage: Double { apiUsageData?.weeklyPercentage ?? 0 }
    var hasSessionData: Bool { apiUsageData?.hasSessionData ?? false }
    var sessionResetLabel: String? { apiUsageData?.sessionResetLabel }
    var weeklyResetLabel: String? { apiUsageData?.weeklyResetLabel }
    var planType: String { apiUsageData?.planType ?? "" }
    var isStale: Bool { apiUsageData?.isStale ?? false }
    var burnRateLabel: String? { apiUsageData?.burnRateLabel }
    var lastUpdatedFormatted: String { apiUsageData?.lastUpdatedFormatted ?? "" }

    var sonnetPercentage: Double { apiUsageData?.sonnetPercentage ?? 0 }
    var hasSonnetData: Bool { apiUsageData?.hasSonnetData ?? false }
    var sonnetResetLabel: String? { apiUsageData?.sonnetResetLabel }

    var claudeDesignPercentage: Double { apiUsageData?.claudeDesignPercentage ?? 0 }
    var hasClaudeDesignData: Bool { apiUsageData?.hasClaudeDesignData ?? false }
    var claudeDesignResetLabel: String? { apiUsageData?.claudeDesignResetLabel }

    var hasExtraUsage: Bool { apiUsageData?.hasExtraUsage ?? false }
    var extraUsageSpent: Double { apiUsageData?.extraUsageSpent ?? 0 }
    var extraUsageLimit: Double { apiUsageData?.extraUsageLimit ?? 0 }
    var extraUsagePercentage: Double { apiUsageData?.extraUsagePercentage ?? 0 }

    var hasRoutineData: Bool { apiUsageData?.hasRoutineData ?? false }
    var routineRunsUsed: Int { apiUsageData?.routineRunsUsed ?? 0 }
    var routineRunsLimit: Int { apiUsageData?.routineRunsLimit ?? 0 }
    var routineRunsPercentage: Double { apiUsageData?.routineRunsPercentage ?? 0 }
    var routineRunsRemaining: Int { apiUsageData?.routineRunsRemaining ?? 0 }

    var menuBarLabel: String { apiUsageData?.menuBarLabel ?? "" }

    // MARK: - Init

    init(repository: StatsRepositoryProtocol, apiService: ClaudeAPIService = ClaudeAPIService()) {
        self.repository = repository
        self.apiService = apiService
        setupAPICallbacks()
    }

    private func setupAPICallbacks() {
        apiService.onUsageUpdated = { [weak self] data in
            guard let self else { return }
            self.apiUsageData = data
            self.apiIsLoading = false
            self.apiErrorMessage = nil
            self.apiNeedsLogin = false

            // Track burn rate
            if data.sessionPercentage < (self.usageHistory.last?.pct ?? 0) - 0.01 {
                self.usageHistory.removeAll()
            }
            self.usageHistory.append((date: Date(), pct: data.sessionPercentage))
            if self.usageHistory.count > 10 { self.usageHistory.removeFirst() }

            var enriched = data
            enriched.usageHistory = self.usageHistory
            self.apiUsageData = enriched
            self.notifications.checkAndNotify(data: enriched)
        }
        apiService.onNeedsLogin = { [weak self] in
            self?.apiNeedsLogin = true
            self?.apiIsLoading = false
        }
        apiService.onLoadingChanged = { [weak self] loading in
            self?.apiIsLoading = loading
        }
        apiService.onError = { [weak self] message in
            self?.apiErrorMessage = message
            self?.apiIsLoading = false
        }
    }

    // MARK: - Public methods

    func startMonitoring() {
        repository.startAutoRefresh(interval: 30) { [weak self] stats in
            self?.stats = stats
            self?.isLoading = false
            self?.errorMessage = nil
        }
        notifications.requestPermission()
    }

    func stopMonitoring() {
        repository.stopAutoRefresh()
    }

    func refresh() {
        do {
            try repository.refresh()
            stats = repository.currentStats
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAPI() {
        apiIsLoading = true
        apiService.refresh()
    }

    func loadBuddyTokens() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Application Support/Claude/buddy-tokens.json"),
            home.appendingPathComponent(".claude/buddy-tokens.json"),
            home.appendingPathComponent(".config/claude/buddy-tokens.json"),
        ]
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else { return }

        // Guard against symlink attacks / oversized files (max 1MB)
        let maxSize: UInt64 = 1_000_000
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attrs[.size] as? UInt64,
           fileSize > maxSize {
            return
        }

        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let today = json["tokens-today"] as? [String: Any],
              let tokens = today["tokens"] as? Int else { return }
        todayRealtimeTokens = tokens
    }

    func loginSucceeded(sessionKey: String) {
        apiService.sessionKey = sessionKey
        apiNeedsLogin = false
        refreshAPI()
    }

    func logout() {
        apiService.logout()
        apiUsageData = nil
        apiNeedsLogin = true
    }

    // MARK: - Tool methods

    static func shortModelName(_ fullName: String) -> String {
        let lower = fullName.lowercased()
        if lower.contains("opus") { return "Opus" }
        if lower.contains("sonnet") { return "Sonnet" }
        if lower.contains("haiku") { return "Haiku" }
        return fullName.split(separator: "-").last.map(String.init) ?? fullName
    }

    static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.2fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
