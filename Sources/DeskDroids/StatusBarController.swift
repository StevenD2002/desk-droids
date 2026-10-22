import AppKit

/// Owns the menu bar item: animates the droid and builds the dropdown.
final class StatusBarController: NSObject, NSMenuDelegate {
    private static let frameInterval: TimeInterval = 0.4
    private static let fashionShowStateDuration: TimeInterval = 2.4
    private static let alertReminderInterval: TimeInterval = 45

    private let store: SessionStore
    static let catModeKey = "catMode"

    private let voice = Voice()
    private let cat = CatDirector(
        mode: CatDirector.Mode(rawValue: UserDefaults.standard.string(forKey: catModeKey) ?? "") ?? .visits
    )
    private var lastAlert = Date.distantPast
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

        cat.onSound = { [weak self] phrase in self?.say(phrase) }
        store.onChange = { [weak self] in self?.render() }
        store.onStateSet = { [weak self] from, to in
            guard let phrase = Phrase.forTransition(from: from, to: to) else { return }
            self?.say(phrase)
        }
        Timer.scheduledTimer(withTimeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.tick += 1
            self.cat.advance(droid: self.displayedState)
            self.render()
            self.remindIfIgnored()
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
            if !fashionShow.isEmpty {
                voice.say(Phrase.signature(for: state), force: true)
            } else if state == .sleeping, shownState != nil {
                say(.sleepy)
            }
            shownState = state
            tick = 0
        }
        // The fashion show gives the crown its entourage.
        let showDrones = state == .delegating ? Sprite.maxDrones : 0
        let drones = fashionShow.isEmpty ? store.droneCount : showDrones
        var pose = serverError == nil ? Sprite.pose(for: state, tick: tick, drones: drones) : Sprite.broken
        let width = cat.isEnabled ? CatDirector.stageWidth : Sprite.width
        var canvas = Canvas(width: width, height: Sprite.height)
        let (catFrame, adjustDroid) = cat.current(droid: state)
        adjustDroid(&pose)
        Sprite.draw(pose, into: &canvas, x: width - Sprite.width)
        catFrame?.draw(into: &canvas)
        item.button?.image = Sprite.image(of: canvas, eyeColor: pose.eyeColor)
        item.button?.toolTip = "desk-droids · \(state.label)"
    }

    func say(_ phrase: Phrase, force: Bool = false) {
        if phrase == .alert { lastAlert = Date() }
        voice.say(phrase, force: force)
    }

    /// Nags again if a permission prompt has been sitting there a while.
    private func remindIfIgnored() {
        if store.state == .needsYou, Date().timeIntervalSince(lastAlert) > Self.alertReminderInterval {
            say(.alert)
        }
    }

    func summonCat(_ scene: CatDirector.Scene? = nil) {
        cat.summon(scene, droid: displayedState)
        render()
    }

    @objc private func summonCatFromMenu() { summonCat() }

    @objc private func setCatMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? CatDirector.Mode else { return }
        cat.mode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.catModeKey)
        if mode != .off { say(.mrrp) }
        render()
    }

    @objc private func setSoundMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? Voice.Mode else { return }
        voice.mode = mode
        if mode != .muted { voice.say(.acknowledge) }
    }

    @objc private func toggleOpenAtLogin() { LoginItem.toggle() }

    /// Cycles through every state so you can see all the outfits.
    @objc private func startFashionShow() {
        fashionShow = DroidState.lineup
        fashionShowTimer?.invalidate()
        shownState = nil  // so the first outfit gets its sound even if it matches the real state
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
        let sounds = NSMenu()
        for mode in Voice.Mode.allCases {
            let option = NSMenuItem(title: mode.label, action: #selector(setSoundMode(_:)), keyEquivalent: "")
            option.target = self
            option.representedObject = mode
            option.state = voice.mode == mode ? .on : .off
            sounds.addItem(option)
        }
        let soundsItem = NSMenuItem(title: "Sounds", action: nil, keyEquivalent: "")
        soundsItem.submenu = sounds
        menu.addItem(soundsItem)

        let catMenu = NSMenu()
        for mode in CatDirector.Mode.allCases {
            let option = NSMenuItem(title: mode.label, action: #selector(setCatMode(_:)), keyEquivalent: "")
            option.target = self
            option.representedObject = mode
            option.state = cat.mode == mode ? .on : .off
            catMenu.addItem(option)
        }
        catMenu.addItem(.separator())
        let summon = NSMenuItem(title: "Summon the cat", action: cat.isEnabled ? #selector(summonCatFromMenu) : nil,
                                keyEquivalent: "")
        summon.target = self
        catMenu.addItem(summon)
        let catItem = NSMenuItem(title: "Cat", action: nil, keyEquivalent: "")
        catItem.submenu = catMenu
        menu.addItem(catItem)
        let show = NSMenuItem(title: "Fashion show", action: #selector(startFashionShow), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        let login = NSMenuItem(title: LoginItem.isAvailable ? "Open at login" : "Open at login (app only)",
                               action: LoginItem.isAvailable ? #selector(toggleOpenAtLogin) : nil, keyEquivalent: "")
        login.target = self
        login.state = LoginItem.menuState
        menu.addItem(login)
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
