import SwiftUI

@main
struct ClaudeMonitorApp: App {
    @State private var viewModel = StatsViewModel(repository: StatsRepository(
        dataSource: LocalStatsFileSource(),
        fileWatcher: FileWatcher()
    ))
    @State private var apiRefreshTimer: Timer?
    @State private var tokenRefreshTimer: Timer?

    init() {
        // Timers start at app launch — independent of popover lifecycle
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView(viewModel: viewModel)
                .onAppear {
                    viewModel.startMonitoring()
                    viewModel.loadBuddyTokens()
                    viewModel.refreshAPI()
                    startAPIAutoRefreshIfNeeded()
                    startTokenAutoRefreshIfNeeded()
                }
        } label: {
            Image(nsImage: RingImage.render(
                percentage: viewModel.primaryModelPercentage,
                isStale: viewModel.isStale && viewModel.hasAPIData
            ))
        }
        .menuBarExtraStyle(.window)
    }

    private func startAPIAutoRefreshIfNeeded() {
        guard apiRefreshTimer == nil else { return }
        apiRefreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            viewModel.refreshAPI()
        }
    }

    private func startTokenAutoRefreshIfNeeded() {
        guard tokenRefreshTimer == nil else { return }
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            viewModel.loadBuddyTokens()
        }
    }
}

// MARK: - Status bar ring icon (NSImage, reliable in menu bar)

enum RingImage {
    private static let size: CGFloat = 16
    private static let lineWidth: CGFloat = 1.6

    static func render(percentage: Int, isStale: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = (size - lineWidth) / 2

        // Use template mode for states without meaningful color data
        // so the system auto-adapts the icon to any menu bar background.
        let useTemplate = isStale || percentage <= 0

        let color: NSColor
        if useTemplate {
            color = .labelColor
        } else if percentage >= 90 {
            color = .systemRed
        } else if percentage >= 60 {
            color = .systemYellow
        } else {
            color = .systemGreen
        }

        // Background ring
        let bgPath = NSBezierPath()
        bgPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        bgPath.lineWidth = lineWidth
        color.withAlphaComponent(percentage > 0 ? 0.25 : 0.5).setStroke()
        bgPath.stroke()

        // Progress arc
        if percentage > 0 {
            let startDeg: CGFloat = 90
            let endDeg = startDeg - CGFloat(percentage) / 100 * 360
            let arcPath = NSBezierPath()
            arcPath.appendArc(withCenter: center, radius: radius, startAngle: startDeg, endAngle: endDeg)
            arcPath.lineWidth = lineWidth
            arcPath.lineCapStyle = .round
            color.setStroke()
            arcPath.stroke()
        } else {
            let dotRadius: CGFloat = 2.5
            let dotPath = NSBezierPath(ovalIn: NSRect(
                x: center.x - dotRadius,
                y: center.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
            color.withAlphaComponent(0.6).setFill()
            dotPath.fill()
        }

        image.unlockFocus()
        image.isTemplate = useTemplate
        return image
    }
}
