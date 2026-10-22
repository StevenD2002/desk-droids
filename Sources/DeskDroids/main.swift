import AppKit

// `--ascii` prints every pose to the terminal instead of launching, for eyeballing sprites.
if CommandLine.arguments.contains("--ascii") {
    for state in DroidState.lineup {
        // Compacting is a longer routine; show all of it.
        for tick in 0..<(state == .compacting ? 4 : 2) {
            print("── \(state.label) (frame \(tick)) ──")
            print(Sprite.ascii(for: Sprite.pose(for: state, tick: tick)))
        }
    }
    for tick in 0..<4 {
        print("── \(Sprite.maxDrones) subagent drones (frame \(tick)) ──")
        print(Sprite.ascii(for: Sprite.pose(for: .delegating, tick: tick, drones: Sprite.maxDrones)))
    }
    exit(0)
}

// `--ascii-cat <scene> [droid-state]` plays a cat scene tick by tick in the terminal.
if let flag = CommandLine.arguments.firstIndex(of: "--ascii-cat") {
    let args = CommandLine.arguments.dropFirst(flag + 1)
    let scene = args.first.flatMap(CatDirector.Scene.init(rawValue:)) ?? .poke
    let state = args.dropFirst().first.flatMap(DroidState.init(rawValue:)) ?? .writing
    let cat = CatDirector(mode: .visits)
    cat.summon(scene, droid: state)
    for tick in 0..<60 {
        var pose = Sprite.pose(for: state, tick: tick)
        var canvas = Canvas(width: CatDirector.stageWidth, height: Sprite.height)
        let (frame, adjust) = cat.current(droid: state)
        adjust(&pose)
        Sprite.draw(pose, into: &canvas, x: CatDirector.droidX)
        frame?.draw(into: &canvas)
        print("── \(scene.rawValue) tick \(tick) ──\n" + canvas.ascii)
        cat.advance(droid: state)
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu bar only: no Dock icon, no app menu.
app.setActivationPolicy(.accessory)
app.run()
