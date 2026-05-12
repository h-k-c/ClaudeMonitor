import Foundation

/// 数据源协议 — 定义数据读取的抽象接口
/// 未来可扩展为网络 API、数据库等实现
protocol StatsDataSourceProtocol {
    func loadStats() throws -> ClaudeStats
}
