import AppKit

/// Owns the menu bar item: animates the droid's face and builds the dropdown.
///
/// The faces are text placeholders until the pixel-art sprite lands (milestone 2).
final class StatusBarController: NSObject, NSMenuDelegate {
    private static let frames: [DroidState: [String]] = [
        .sleeping:   ["[-_-] z ", "[-_-] zZ"],
        .idle:       ["[•_•]   ", "[•_•]   ", "[•_•]   ", "[-_-]   "],
        .thinking:   ["[•_•].  ", "[•_•].. ", "[•_•]..."],
        .reading:    ["[◑_◑]   ", "[◐_◐]   "],
        .writing:    ["[•_•]✎  ", "[•_•] ✎ "],
        .running:    ["[>_<]⚙  ", "[>_<] ⚙ "],
        .delegating: ["[•_•]»  ", "[•_•]»» "],
        .tinkering:  ["[•_•]~  ", "[•_•] ~ "],
        .compacting: ["[@_@]   ", "[x_x]   "],
        .needsYou:   ["[°o°]!  ", "[°O°]!! "],
        .done:       ["[^_^]✓  ", "[^‿^]✓  "],
    ]

    private let store: SessionStore
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    private var frameIndex = 0
    private var shownState: DroidState?
    private var serverError: String?

    init(store: SessionStore) {
        self.store = store
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        item.length = Self.frames.values.joined().map { width(of: $0) }.max()! + 8

        store.onChange = { [weak self] in self?.render() }
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.frameIndex += 1
            self?.render()
        }
        render()
    }

    func showServerError(_ message: String) {
        serverError = message
        render()
    }

    private func render() {
        let state = store.state
        if state != shownState {
            shownState = state
            frameIndex = 0
        }

        let text: String
        let color: NSColor
        if serverError != nil {
            text = "[x_x]?  "
            color = .systemRed
        } else {
            let frames = Self.frames[state]!
            text = frames[frameIndex % frames.count]
            color = state == .needsYou ? .systemOrange : .labelColor
        }
        item.button?.attributedTitle = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    }

    private func width(of text: String) -> CGFloat {
        ceil(NSAttributedString(string: text, attributes: [.font: font]).size().width)
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
