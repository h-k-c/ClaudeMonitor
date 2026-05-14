import SwiftUI
import AppKit

// MARK: - Frosted glass background (native macOS vibrancy)

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.isEmphasized = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(effectView)

        let tintView = NSView()
        tintView.wantsLayer = true
        if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            tintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        } else {
            tintView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.35).cgColor
        }
        tintView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tintView)

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: container.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            tintView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tintView.topAnchor.constraint(equalTo: container.topAnchor),
            tintView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let tintView = nsView.subviews.last {
            tintView.wantsLayer = true
            if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                tintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
            } else {
                tintView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.35).cgColor
            }
        }
    }
}

// MARK: - Adaptive green (contrast-aware for light/dark)

private let adaptiveGreen = Color(NSColor(name: nil) { appearance in
    if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
        return NSColor(red: 60/255, green: 199/255, blue: 95/255, alpha: 1.0)
    } else {
        return NSColor(red: 27/255, green: 107/255, blue: 52/255, alpha: 1.0)
    }
})

// MARK: - Main Dashboard

struct DashboardView: View {
    @Bindable var viewModel: StatsViewModel
    @State private var tick = false
    @State private var claudeToast: (String, Bool)?
    @State private var codexToast: (String, Bool)?
    @State private var refreshRotation: Double = 0
    @State private var refreshTimer: Timer?

    private var hasAnyContent: Bool {
        (viewModel.claudeEnabled && (viewModel.hasAPIData || viewModel.apiNeedsLogin || viewModel.apiErrorMessage != nil || viewModel.apiIsLoading))
        || (viewModel.codexEnabled && (viewModel.hasCodexData || viewModel.codexNeedsLogin || viewModel.codexIsLoading))
    }

    var body: some View {
        VStack(spacing: 0) {
            claudeSection
            if let t = claudeToast { toastView(t.0, isError: t.1) }
            if viewModel.claudeEnabled && viewModel.hasAPIData { tipBar }

            Divider().opacity(0.3).padding(.horizontal, 14)

            codexSection
            if let t = codexToast { toastView(t.0, isError: t.1) }

            if hasAnyContent { Spacer(minLength: 0) }

            Divider().opacity(0.3).padding(.horizontal, 14)
            footerView
        }
        .frame(width: 280)
        .background(VisualEffectBackground())
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            tick.toggle()
        }
        .onChange(of: viewModel.hasAPIData) { _, newValue in
            if newValue { showClaudeToast("连接成功") }
        }
        .onChange(of: viewModel.apiErrorMessage) { _, newValue in
            if let msg = newValue { showClaudeToast(msg, isError: true) }
        }
        .onChange(of: viewModel.hasCodexData) { _, newValue in
            if newValue { showCodexToast("连接成功") }
        }
        .onChange(of: viewModel.codexNeedsLogin) { _, newValue in
            if newValue { showCodexToast("未连接", isError: true) }
        }
    }

    // MARK: - Ring item

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

    private func cleanResetLabel(_ label: String) -> String {
        label.replacingOccurrences(of: "重置于 ", with: "")
    }

    // MARK: - Claude section

    @ViewBuilder
    private var claudeSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                icon: "brain.head.profile",
                iconColor: .accentColor,
                title: "Claude",
                planType: viewModel.planType,
                planColor: planColor,
                isEnabled: viewModel.claudeEnabled,
                onToggle: { viewModel.toggleClaude($0) }
            )

            if viewModel.claudeEnabled {
                if viewModel.apiIsLoading && !viewModel.hasAPIData {
                    loadingRow
                } else if viewModel.apiNeedsLogin && !viewModel.hasAPIData {
                    claudeLoginView
                } else if let error = viewModel.apiErrorMessage, !viewModel.hasAPIData {
                    claudeErrorView(error)
                } else if viewModel.hasAPIData {
                    let _ = tick
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
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Codex section

    @ViewBuilder
    private var codexSection: some View {
        VStack(spacing: 0) {
            sectionHeader(
                icon: "terminal",
                iconColor: .orange,
                title: "Codex",
                planType: viewModel.codexEnabled ? viewModel.codexPlanType : "",
                planColor: codexPlanColor,
                isEnabled: viewModel.codexEnabled,
                onToggle: { viewModel.toggleCodex($0) },
                extraBadge: viewModel.codexEnabled && viewModel.codexLimitReached ? "已用尽" : nil,
                extraBadgeColor: .red
            )

            if viewModel.codexEnabled {
                if viewModel.codexIsLoading && !viewModel.hasCodexData {
                    loadingRow
                } else if viewModel.codexNeedsLogin {
                    codexLoginRow
                } else if let error = viewModel.codexErrorMessage, !viewModel.hasCodexData {
                    codexErrorRow(error)
                } else if viewModel.hasCodexData {
                    HStack(spacing: 0) {
                        ringItem(
                            label: "5 小时",
                            progress: viewModel.codexPrimaryPercentage,
                            resetLabel: viewModel.codexPrimaryResetLabel
                        )
                        ringItem(
                            label: "7 日",
                            progress: viewModel.codexSecondaryPercentage,
                            resetLabel: viewModel.codexSecondaryResetLabel
                        )
                        ringItem(
                            label: "Credits",
                            value: codexCreditText,
                            color: .orange
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(
        icon: String,
        iconColor: Color,
        title: String,
        planType: String,
        planColor: Color,
        isEnabled: Bool,
        onToggle: @escaping (Bool) -> Void,
        extraBadge: String? = nil,
        extraBadgeColor: Color = .red
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(iconColor)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            Spacer()
            if isEnabled && !planType.isEmpty && planType.lowercased() != "unknown" {
                Text(planType.uppercased())
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(planColor)
                    .clipShape(Capsule())
            }
            if let extraBadge {
                Text(extraBadge)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(extraBadgeColor)
            }
            Toggle("", isOn: Binding(get: { isEnabled }, set: onToggle))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Loading

    private var loadingRow: some View {
        HStack(spacing: 6) {
            ProgressView().scaleEffect(0.6)
            Text("获取数据…")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Toast

    private func showClaudeToast(_ message: String, isError: Bool = false) {
        claudeToast = (message, isError)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if claudeToast?.0 == message { claudeToast = nil }
        }
    }

    private func showCodexToast(_ message: String, isError: Bool = false) {
        codexToast = (message, isError)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if codexToast?.0 == message { codexToast = nil }
        }
    }

    @ViewBuilder
    private func toastView(_ message: String, isError: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(isError ? .red : adaptiveGreen)
            Text(message)
                .font(.system(size: 10))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isError ? Color.red : adaptiveGreen).opacity(0.06))
    }

    // MARK: - Claude login

    @State private var sessionKeyInput: String = ""

    private var claudeLoginView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "key.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
                Text("连接 Claude")
                    .font(.system(size: 10, weight: .medium))
                Spacer()
            }
            VStack(spacing: 2) {
                Text("1. 浏览器登录 claude.ai")
                Text("2. F12 → Application → Cookies")
                Text("3. 复制 sessionKey 粘贴到下方")
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                TextField("粘贴 sessionKey…", text: $sessionKeyInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                    .onSubmit { connectAction() }

                Button(action: connectAction) {
                    Text("连接")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func connectAction() {
        let key = sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        viewModel.loginSucceeded(sessionKey: key)
        sessionKeyInput = ""
        showClaudeToast("正在连接…")
    }

    // MARK: - Claude error

    private func claudeErrorView(_ message: String) -> some View {
        let isExpired = message.contains("过期")
        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: isExpired ? "key.slash" : "wifi.exclamationmark")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(message)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Spacer()
            }
            if isExpired {
                HStack(spacing: 4) {
                    TextField("粘贴新 sessionKey…", text: $sessionKeyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                        .onSubmit { connectAction() }
                    Button("连接") { connectAction() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                        .disabled(sessionKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                HStack {
                    Spacer()
                    Button("重试") { viewModel.refreshAPI() }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Codex login

    private var codexLoginRow: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text("在终端运行 codex 登录 ChatGPT 账号")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
            }
            Button {
                viewModel.refreshCodex()
            } label: {
                Text("重试")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.orange)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func codexErrorRow(_ message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(message)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(2)
            Spacer()
            Button("重试") { viewModel.refreshCodex() }
                .buttonStyle(.bordered)
                .controlSize(.mini)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Tip bar

    private var tipBar: some View {
        let pct = viewModel.sessionPercentage
        let tip: (String, String, Color)? = {
            if pct >= 0.95 { return ("exclamationmark.triangle.fill", "即将用尽，建议保存当前工作", .red) }
            if pct >= 0.85 { return ("lightbulb.fill", "余量不多，适合短任务", .orange) }
            if pct >= 0.75 { return ("lightbulb.fill", "建议结束长线程，保存输出", .orange) }
            if pct >= 0.60 { return ("lightbulb.fill", "用量偏高，注意控制上下文", .yellow) }
            if pct >= 0.20 { return ("hand.thumbsup.fill", "用量正常，放心使用", adaptiveGreen) }
            return ("checkmark.circle.fill", "余量充足，放心使用", adaptiveGreen)
        }()
        return Group {
            if let tip {
                HStack(spacing: 4) {
                    Image(systemName: tip.0)
                        .font(.system(size: 8))
                        .foregroundColor(tip.2)
                    Text(tip.1)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(tip.2.opacity(0.05))
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        let isLoading = viewModel.apiIsLoading || viewModel.codexIsLoading
        return HStack(spacing: 6) {
            if !viewModel.lastUpdatedFormatted.isEmpty {
                Text(viewModel.lastUpdatedFormatted)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                if viewModel.claudeEnabled { viewModel.refreshAPI() }
                if viewModel.codexEnabled { viewModel.refreshCodex() }
                viewModel.loadBuddyTokens()
                startRefreshSpin()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .rotationEffect(.degrees(refreshRotation))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(isLoading)
            Button("退出") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .onChange(of: isLoading) { _, loading in
            if !loading { stopRefreshSpin() }
        }
    }

    private func startRefreshSpin() {
        refreshTimer?.invalidate()
        refreshRotation = 0
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            refreshRotation += 6
            if refreshRotation >= 360 { refreshRotation -= 360 }
        }
    }

    private func stopRefreshSpin() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        withAnimation(.easeOut(duration: 0.3)) {
            refreshRotation = 0
        }
    }

    // MARK: - Helpers

    private var codexCreditText: String? {
        guard let balance = viewModel.codexCreditBalance else { return nil }
        return String(format: "$%.0f", balance)
    }

    private var codexPlanColor: Color {
        switch viewModel.codexPlanType.lowercased() {
        case "pro": return adaptiveGreen
        case "plus": return .purple
        case "free": return .gray
        default: return .orange
        }
    }

    private var planColor: Color {
        switch viewModel.planType.lowercased() {
        case "pro": return adaptiveGreen
        case "max": return .purple
        case "team": return .blue
        default: return .gray
        }
    }

    private func usageColor(_ progress: Double) -> Color {
        switch progress {
        case 0.90...: return .red
        case 0.60...: return .orange
        default: return adaptiveGreen
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
