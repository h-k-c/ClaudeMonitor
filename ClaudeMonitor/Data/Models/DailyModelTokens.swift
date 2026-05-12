import Foundation

struct DailyModelTokens: Codable {
    let date: String
    let tokensByModel: [String: Int]
}
