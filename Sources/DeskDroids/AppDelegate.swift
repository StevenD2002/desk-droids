import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let port: UInt16 = 4747

    private let store = SessionStore()
    private var server: HookServer?
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsMigration.runIfNeeded()  // before StatusBarController reads the settings
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
            onCommand: { [weak self] verb, argument in
                switch verb {
                case "say":
                    guard let phrase = Phrase(rawValue: argument) else { return false }
                    DispatchQueue.main.async { self?.statusBar?.say(phrase, force: true) }
                case "cat":
                    guard let scene = CatDirector.Scene(rawValue: argument) else { return false }
                    DispatchQueue.main.async { self?.statusBar?.summonCat(scene) }
                default:
                    return false
                }
                return true
            }
        )
        server.start()
        self.server = server
    }
}
