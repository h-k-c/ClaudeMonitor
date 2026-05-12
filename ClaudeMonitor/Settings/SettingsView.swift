import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            AboutTab()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 250)
    }
}

// MARK: - General settings

private struct GeneralSettingsTab: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 120

    private let options: [(String, Double)] = [
        ("30 秒", 30),
        ("1 分钟", 60),
        ("2 分钟", 120),
        ("5 分钟", 300),
        ("10 分钟", 600),
    ]

    var body: some View {
        Form {
            Picker("API 刷新间隔", selection: $refreshInterval) {
                ForEach(options, id: \.1) { label, value in
                    Text(label).tag(value)
                }
            }

            Section {
                Text("API 数据来自 Claude.ai 实时接口，需要登录 Claude 账号。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Claude Monitor")
                .font(.title2)
                .fontWeight(.semibold)

            Text("实时用量监控仪表盘")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Claude.ai API + 本地统计文件")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
    }
}
