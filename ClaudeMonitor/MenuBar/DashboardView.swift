import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: StatsViewModel
    @State private var tick = false  // Toggle every 60s to force re-render

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Claude Monitor")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if !viewModel.planType.isEmpty && viewModel.planType.lowercased() != "unknown" {
                    Text(viewModel.planType.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(planColor)
                        .clipShape(Capsule())
                }
                if viewModel.hasAPIData {
                    Button {
                        viewModel.logout()
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("退出登录")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().opacity(0.3)

            if viewModel.apiNeedsLogin && !viewModel.hasAPIData {
                loginPromptView
            } else if viewModel.apiIsLoading && !viewModel.hasAPIData {
                loadingView
            } else if let error = viewModel.apiErrorMessage, !viewModel.hasAPIData {
                errorView(error)
            } else {
                // Three rings evenly distributed
                let _ = tick  // Force re-render when tick changes
                HStack(spacing: 0) {
                    ringItem(
                        label: "5 小时",
                        progress: viewModel.sessionPercentage,
                        resetLabel: viewModel.sessionResetLabel
                    )
                    ringItem(
                        label: "7 日",
                        progress: viewModel.weeklyPercentage,
                        resetLabel: viewModel.weeklyResetLabel
                    )
                    ringItem(
                        label: "今日 Tokens",
                        value: formatTokens(viewModel.todayRealtimeTokens),
                        color: Color.accentColor
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)

                Spacer(minLength: 0)

                if viewModel.hasAPIData, viewModel.sessionPercentage >= 0.2 {
                    tipBar
                }

                Divider().opacity(0.3)
                footerView
            }
        }
        .frame(width: 260, height: 280)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            tick.toggle()
        }
    }

    // MARK: - Ring item (uniform size)

    @ViewBuilder
    private func ringItem(label: String, progress: Double? = nil, value: String? = nil, resetLabel: String? = nil, color: Color? = nil) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 5)

                if let progress {
                    Circle()
                        .trim(from: 0, to: max(0.005, progress))
                        .stroke(
                            color ?? usageColor(progress),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)

                    Text("\(Int(progress * 100))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(usageColor(progress))
                        .contentTransition(.numericText())
                } else if let value {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.15), lineWidth: 5)

                    Text(value)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 52, height: 52)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)

            // Reset countdown
            HStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.system(size: 7))
                if let resetLabel {
                    Text(cleanResetLabel(resetLabel))
                        .font(.system(size: 8, design: .monospaced))
                } else {
                    Text("--")
                        .font(.system(size: 8, design: .monospaced))
                }
            }
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Clean up "重置于 2h30m" → "2h30m"
    private func cleanResetLabel(_ label: String) -> String {
        label.replacingOccurrences(of: "重置于 ", with: "")
    }

    // MARK: - Plan color

    private var planColor: Color {
        switch viewModel.planType.lowercased() {
        case "pro": return .green
        case "max": return .purple
        case "team": return .blue
        default: return .gray
        }
    }

    // MARK: - Login

    @State private var sessionKeyInput: String = ""

    private var loginPromptView: some View {
        VStack(spacing: 10) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "key.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            Text("连接 Claude")
                .font(.system(size: 14, weight: .semibold))
            VStack(spacing: 2) {
                Text("1. 浏览器登录 claude.ai")
                Text("2. F12 → Application → Cookies")
                Text("3. 复制 sessionKey 粘贴到下方")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            TextField("粘贴 sessionKey…", text: $sessionKeyInput)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                .onSubmit { connectAction() }
                .frame(maxWidth: 220)
            Button(action: connectAction) {
                Text("连接")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 220)
                    .padding(.vertical, 6)
                    .background(sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Text("⌘⌥I 打开开发者工具")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func connectAction() {
        let key = sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        viewModel.loginSucceeded(sessionKey: key)
        sessionKeyInput = ""
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView().scaleEffect(1.1)
            Text("正在获取用量数据…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(minHeight: 120)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        let isExpired = message.contains("过期")
        return VStack(spacing: 10) {
            Spacer()
            Image(systemName: isExpired ? "key.slash" : "wifi.exclamationmark")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if isExpired {
                // Show re-enter sessionKey
                TextField("粘贴新 sessionKey…", text: $sessionKeyInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                    .onSubmit { connectAction() }
                    .frame(maxWidth: 220)
                HStack(spacing: 8) {
                    Button("重新连接") { connectAction() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("重试") { viewModel.refreshAPI() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            } else {
                Button("重试") { viewModel.refreshAPI() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Spacer()
        }
        .frame(minHeight: 120)
    }

    // MARK: - Color: 0-60 green, 60-90 yellow, 90+ red

    private func usageColor(_ progress: Double) -> Color {
        switch progress {
        case 0.90...: return .red
        case 0.60...: return .yellow
        default: return .green
        }
    }

    // MARK: - Token format

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    // MARK: - Tip bar

    private var tipBar: some View {
        let pct = viewModel.sessionPercentage
        let tip: String? = {
            if pct >= 0.95 { return "即将用尽，请保存工作" }
            if pct >= 0.85 { return "适合短任务" }
            if pct >= 0.75 { return "结束长线程，保存输出" }
            if pct >= 0.60 { return "用量偏高，控制上下文" }
            if pct >= 0.20 { return "新话题开新会话" }
            return nil
        }()
        return Group {
            if let tip {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                    Text(tip)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.05))
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 6) {
            if !viewModel.lastUpdatedFormatted.isEmpty {
                Text(viewModel.lastUpdatedFormatted)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                viewModel.refreshAPI()
                viewModel.loadBuddyTokens()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .rotationEffect(viewModel.apiIsLoading ? .degrees(360) : .zero)
                    .animation(
                        viewModel.apiIsLoading
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: viewModel.apiIsLoading
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(viewModel.apiIsLoading)
            Button("退出") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
