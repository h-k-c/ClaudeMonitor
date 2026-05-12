import Foundation

/// 数据仓库 — 封装数据源，提供缓存和自动刷新
/// ViewModel 只依赖 StatsRepositoryProtocol，不直接接触文件读取
final class StatsRepository: StatsRepositoryProtocol {

    private(set) var currentStats: ClaudeStats?

    private let dataSource: StatsDataSourceProtocol
    private let fileWatcher: FileWatcherProtocol
    private var onChangeHandler: ((ClaudeStats) -> Void)?
    private var timer: Timer?

    init(dataSource: StatsDataSourceProtocol, fileWatcher: FileWatcherProtocol) {
        self.dataSource = dataSource
        self.fileWatcher = fileWatcher

        // 文件变化时自动刷新并通知
        self.fileWatcher.onFileChanged = { [weak self] in
            self?.handleFileChange()
        }
    }

    func refresh() throws {
        let stats = try dataSource.loadStats()
        currentStats = stats
        DispatchQueue.main.async { [weak self] in
            self?.onChangeHandler?(stats)
        }
    }

    func startAutoRefresh(interval: TimeInterval, onChange: @escaping (ClaudeStats) -> Void) {
        onChangeHandler = onChange

        // 首次加载
        try? refresh()

        // 启动文件监听
        let path = defaultStatsPath()
        fileWatcher.startWatching(path: path)

        // 定时兜底刷新（防止文件监听遗漏）
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            try? self?.refresh()
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
        fileWatcher.stopWatching()
        onChangeHandler = nil
    }

    private func handleFileChange() {
        // 短暂延迟，等文件写入完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            try? self?.refresh()
        }
    }

    private func defaultStatsPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/stats-cache.json"
    }

    deinit {
        stopAutoRefresh()
    }
}
