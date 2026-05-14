import Foundation
import Observation

/// ViewModel — combines Claude.ai API + Codex API real-time data
@Observable
final class StatsViewModel {

    // MARK: - API real-time data (from Claude.ai)

    private(set) var apiUsageData: UsageData?
    private(set) var apiIsLoading = false
    private(set) var apiNeedsLogin = false
    private(set) var apiErrorMessage: String?

    // MARK: - Codex real-time data

    private(set) var codexUsageData: CodexUsageData?
    private(set) var codexIsLoading = false
    private(set) var codexNeedsLogin = false
    private(set) var codexErrorMessage: String?

    // MARK: - Toggle state (persisted)

    var claudeEnabled: Bool {
        didSet { UserDefaults.standard.set(claudeEnabled, forKey: "claudeEnabled") }
    }
    var codexEnabled: Bool {
        didSet { UserDefaults.standard.set(codexEnabled, forKey: "codexEnabled") }
    }

    // MARK: - Dependencies

    let apiService: ClaudeAPIService
    let codexService: CodexAPIService
    private let notifications = NotificationService.shared
    private var usageHistory: [(date: Date, pct: Double)] = []

    // MARK: - Menu bar data

    var primaryModelPercentage: Int {
        if let api = apiUsageData, api.hasSessionData {
            return Int(api.sessionPercentage * 100)
        }
        return 0
    }

    /// Today's real-time tokens (from buddy-tokens.json)
    private(set) var todayRealtimeTokens: Int = 0

    // MARK: - API data accessors (for DashboardView)

    var hasAPIData: Bool { apiUsageData != nil }

    var sessionPercentage: Double { apiUsageData?.sessionPercentage ?? 0 }
    var weeklyPercentage: Double { apiUsageData?.weeklyPercentage ?? 0 }
    var sessionResetLabel: String? { apiUsageData?.sessionResetLabel }
    var weeklyResetLabel: String? { apiUsageData?.weeklyResetLabel }
    var planType: String { apiUsageData?.planType ?? "" }
    var isStale: Bool { apiUsageData?.isStale ?? false }
    var lastUpdatedFormatted: String { apiUsageData?.lastUpdatedFormatted ?? "" }

    // MARK: - Codex data accessors (for DashboardView)

    var hasCodexData: Bool { codexUsageData != nil }
    var codexPrimaryPercentage: Double { Double(codexUsageData?.primaryUsedPercent ?? 0) / 100.0 }
    var codexSecondaryPercentage: Double { Double(codexUsageData?.secondaryUsedPercent ?? 0) / 100.0 }
    var codexPlanType: String { codexUsageData?.planType ?? "" }
    var codexPrimaryResetLabel: String? { codexUsageData?.primaryResetLabel }
    var codexSecondaryResetLabel: String? { codexUsageData?.secondaryResetLabel }
    var codexCreditBalance: Double? { codexUsageData?.creditBalance }
    var codexIsStale: Bool { codexUsageData?.isStale ?? true }
    var codexLimitReached: Bool { codexUsageData?.limitReached ?? false }

    // MARK: - Init

    init(
        apiService: ClaudeAPIService = ClaudeAPIService(),
        codexService: CodexAPIService = CodexAPIService()
    ) {
        self.claudeEnabled = UserDefaults.standard.bool(forKey: "claudeEnabled")
        self.codexEnabled = UserDefaults.standard.bool(forKey: "codexEnabled")
        self.apiService = apiService
        self.codexService = codexService
        setupAPICallbacks()
        setupCodexCallbacks()
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

    private func setupCodexCallbacks() {
        codexService.onUsageUpdated = { [weak self] data in
            guard let self else { return }
            self.codexUsageData = data
            self.codexIsLoading = false
            self.codexErrorMessage = nil
            self.codexNeedsLogin = false
        }
        codexService.onNeedsLogin = { [weak self] in
            self?.codexNeedsLogin = true
            self?.codexIsLoading = false
        }
        codexService.onLoadingChanged = { [weak self] loading in
            self?.codexIsLoading = loading
        }
        codexService.onError = { [weak self] message in
            self?.codexErrorMessage = message
            self?.codexIsLoading = false
        }
    }

    // MARK: - Public methods

    func refreshAPI() {
        apiIsLoading = true
        apiService.refresh()
    }

    func refreshCodex() {
        codexIsLoading = true
        codexService.refresh()
    }

    func toggleClaude(_ enabled: Bool) {
        claudeEnabled = enabled
        if enabled {
            refreshAPI()
        } else {
            apiUsageData = nil
            apiErrorMessage = nil
            apiNeedsLogin = false
        }
    }

    func toggleCodex(_ enabled: Bool) {
        codexEnabled = enabled
        if enabled {
            refreshCodex()
        } else {
            codexUsageData = nil
            codexErrorMessage = nil
            codexNeedsLogin = false
        }
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

}
