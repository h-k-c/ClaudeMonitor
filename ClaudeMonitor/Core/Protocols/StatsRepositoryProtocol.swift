import Foundation

/// 仓库协议 — 对 ViewModel 暴露数据访问接口
/// 负责缓存策略和数据刷新，ViewModel 不关心数据从哪来
protocol StatsRepositoryProtocol {
    var currentStats: ClaudeStats? { get }
    func refresh() throws
    func startAutoRefresh(interval: TimeInterval, onChange: @escaping (ClaudeStats) -> Void)
    func stopAutoRefresh()
}
