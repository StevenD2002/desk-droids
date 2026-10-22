import AppKit

// `--ascii` prints every pose to the terminal instead of launching, for eyeballing sprites.
if CommandLine.arguments.contains("--ascii") {
    let states: [DroidState] = [.idle, .thinking, .reading, .writing, .running, .delegating,
                                .tinkering, .compacting, .needsYou, .done, .sleeping]
    for state in states {
        for tick in 0..<2 {
            print("── \(state.label) (frame \(tick)) ──")
            print(Sprite.ascii(for: Sprite.pose(for: state, tick: tick)))
        }
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu bar only: no Dock icon, no app menu.
app.setActivationPolicy(.accessory)
app.run()
