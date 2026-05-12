import Foundation

/// 文件监听协议 — 监听文件变化并触发回调
protocol FileWatcherProtocol: AnyObject {
    var onFileChanged: (() -> Void)? { get set }
    func startWatching(path: String)
    func stopWatching()
}
