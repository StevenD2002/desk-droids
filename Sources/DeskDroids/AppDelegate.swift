import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let port: UInt16 = 4747

    private let store = SessionStore()
    private var server: HookServer?
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(store: store)

        let server = HookServer(
            port: Self.port,
            onEvent: { [weak self] event in
                DispatchQueue.main.async { self?.store.apply(event) }
            },
            snapshot: { [weak self] in
                DispatchQueue.main.sync { self?.store.snapshotJSON() ?? Data("{}".utf8) }
            },
            onFailure: { [weak self] message in
                DispatchQueue.main.async { self?.statusBar?.showServerError(message) }
            },
            onSay: { [weak self] name in
                guard let phrase = Phrase(rawValue: name) else { return false }
                DispatchQueue.main.async { self?.statusBar?.say(phrase, force: true) }
                return true
            }
        )
        server.start()
        self.server = server
    }
}
