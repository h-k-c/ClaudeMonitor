import Foundation

extension Date {
    /// 格式化为 "yyyy-MM-dd"，用于匹配 stats-cache.json 中的日期字段
    var isoDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self)
    }

    /// 格式化为 "MM-dd"，用于 UI 短显示
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: self)
    }

    /// 判断是否是今天
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}

extension String {
    /// 将 "yyyy-MM-dd" 字符串解析为 Date
    var toDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: self)
    }

    /// 将 ISO8601 字符串解析为 Date
    var toISODate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: self)
    }
}
