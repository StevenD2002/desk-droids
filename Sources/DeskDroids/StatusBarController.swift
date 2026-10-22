import AppKit

/// Owns the menu bar item: animates the droid and builds the dropdown.
final class StatusBarController: NSObject, NSMenuDelegate {
    private static let frameInterval: TimeInterval = 0.4
    private static let fashionShowStateDuration: TimeInterval = 2.4

    private let store: SessionStore
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var tick = 0
    private var shownState: DroidState?
    private var serverError: String?
    private var fashionShow: [DroidState] = []
    private var fashionShowTimer: Timer?

    init(store: SessionStore) {
        self.store = store
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        item.button?.imagePosition = .imageOnly

        store.onChange = { [weak self] in self?.render() }
        Timer.scheduledTimer(withTimeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            self?.tick += 1
            self?.render()
        }
        render()
    }

    func showServerError(_ message: String) {
        serverError = message
        render()
    }

    private var displayedState: DroidState { fashionShow.first ?? store.state }

    private func render() {
        let state = displayedState
        if state != shownState {
            shownState = state
            tick = 0
        }
        let pose = serverError == nil ? Sprite.pose(for: state, tick: tick) : Sprite.broken
        item.button?.image = Sprite.image(for: pose)
        item.button?.toolTip = "desk-droids · \(state.label)"
    }

    /// Cycles through every state so you can see all the outfits.
    @objc private func startFashionShow() {
        fashionShow = [.idle, .thinking, .reading, .writing, .running, .delegating,
                       .tinkering, .compacting, .needsYou, .done, .sleeping]
        fashionShowTimer?.invalidate()
        fashionShowTimer = Timer.scheduledTimer(withTimeInterval: Self.fashionShowStateDuration, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            self.fashionShow.removeFirst()
            if self.fashionShow.isEmpty { timer.invalidate() }
            self.render()
        }
        render()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if let serverError {
            menu.addItem(disabled("⚠️ \(serverError)"))
            menu.addItem(.separator())
        }

        menu.addItem(disabled("desk-droids · \(store.state.label)", bold: true))
        menu.addItem(.separator())

        let sessions = store.sessions.values.sorted { $0.updated > $1.updated }
        if sessions.isEmpty {
            menu.addItem(disabled("No Claude sessions yet"))
        }
        for session in sessions {
            let ago = RelativeDateTimeFormatter().localizedString(for: session.updated, relativeTo: Date())
            menu.addItem(disabled("\(session.project) · \(session.state.label)", bold: session === store.focus))
            menu.addItem(disabled("    \(session.detail) · \(ago)"))
        }

        menu.addItem(.separator())
        let show = NSMenuItem(title: "Fashion show", action: #selector(startFashionShow), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        let quit = NSMenuItem(title: "Quit desk-droids", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func disabled(_ title: String, bold: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        if bold {
            item.attributedTitle = NSAttributedString(string: title, attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        }
        return item
    }
}
