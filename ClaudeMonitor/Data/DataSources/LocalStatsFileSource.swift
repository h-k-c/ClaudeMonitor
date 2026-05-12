import Foundation

/// 本地文件数据源 — 读取 ~/.claude/stats-cache.json
final class LocalStatsFileSource: StatsDataSourceProtocol {

    private let filePath: String
    private let fileManager: FileManager

    init(filePath: String? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.filePath = filePath ?? Self.defaultStatsPath()
    }

    func loadStats() throws -> ClaudeStats {
        let url = URL(fileURLWithPath: filePath)

        guard fileManager.fileExists(atPath: filePath) else {
            throw StatsDataSourceError.fileNotFound(filePath)
        }

        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        return try decoder.decode(ClaudeStats.self, from: data)
    }

    private static func defaultStatsPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/stats-cache.json"
    }
}

enum StatsDataSourceError: LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Stats file not found at: \(path)"
        }
    }
}
