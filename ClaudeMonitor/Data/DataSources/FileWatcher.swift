import Foundation

/// 文件监听器 — 使用 GCD DispatchSource 监听文件变化
final class FileWatcher: FileWatcherProtocol {

    var onFileChanged: (() -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.claude-monitor.file-watcher", qos: .utility)

    func startWatching(path: String) {
        stopWatching()

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.onFileChanged?()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.source = source
    }

    func stopWatching() {
        source?.cancel()
        source = nil
    }

    deinit {
        stopWatching()
    }
}
