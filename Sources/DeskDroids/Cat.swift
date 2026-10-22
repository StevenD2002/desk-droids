import Foundation

/// The cat's pixel art: a tuxedo cat. `K` black fur, `W` white bib/muzzle/paws, `G` eyes, `M` nose.
/// Side-view sprites face right.
enum CatSprite {
    static let sit = [
        "K.....K..",
        "KK...KK..",
        "KKKKKKK..",
        "KGKKKGK..",
        "KKWMWKK..",
        ".KWWWK...",
        ".KWWWK..K",
        "KKWWWKK.K",
        "KKWWWKKKK",
        "KWWKWWK..",
    ]
    static let sitTailFlick = [
        "K.....K..",
        "KK...KK..",
        "KKKKKKK..",
        "KGKKKGK..",
        "KKWMWKK..",
        ".KWWWK.K.",
        ".KWWWK.K.",
        "KKWWWKKK.",
        "KKWWWKK..",
        "KWWKWWK..",
    ]
    static let sitBlink = [
        "K.....K..",
        "KK...KK..",
        "KKKKKKK..",
        "KKKKKKK..",
        "KKWMWKK..",
        ".KWWWK...",
        ".KWWWK..K",
        "KKWWWKK.K",
        "KKWWWKKKK",
        "KWWKWWK..",
    ]
    /// Paw stretched out to the right, at droid-head height.
    static let swat = [
        "K.....K..",
        "KK...KK..",
        "KKKKKKK..",
        "KGKKKGK..",
        "KKWMWKK..",
        ".KWWWKKK.",
        ".KWWWK.WW",
        "KKWWWK...",
        "KKWWWKK..",
        "KWWKWWK..",
    ]
    static let walkA = [
        "..........K.K",
        "K.........KKK",
        "K........KKGK",
        ".KKKKKKKKKKWM",
        ".KKKKKKKWWWW.",
        ".KKKKKKKKW...",
        ".W.W....W.W..",
    ]
    static let walkB = [
        "..........K.K",
        "K.........KKK",
        "K........KKGK",
        ".KKKKKKKKKKWM",
        ".KKKKKKKWWWW.",
        ".KKKKKKKKW...",
        "..W.W..W.W...",
    ]
    static let loaf = [
        "......K...K",
        "......KKKKK",
        ".KKKKKKGKGK",
        "KKKKKKKWMWK",
        "KKKKKWWWWW.",
    ]
    static let loafAsleep = [
        "......K...K",
        "......KKKKK",
        ".KKKKKKKKKK",
        "KKKKKKKWMWK",
        "KKKKKWWWWW.",
    ]
}

/// Decides what the cat is doing: where it is, which sprite, and how the droid reacts.
/// Advances one step per animation tick. Main thread only.
final class CatDirector {
    enum Mode: String, CaseIterable {
        case off, visits, always

        var label: String {
            switch self {
            case .off: return "No cat"
            case .visits: return "Visits now and then"
            case .always: return "Always around"
            }
        }
    }

    enum Scene: String, CaseIterable {
        /// Sits and stares at the droid. The droid stares back.
        case stare
        /// Pokes the droid in the face, repeatedly.
        case poke
        /// Swats the hat clean off. It stays off until the droid starts a different task.
        case hatThief
        /// Jumps up and loafs on the droid's head.
        case headLoaf
        /// Walks right across the droid while it's typing. The droid's chatter comes out garbled.
        case keyboard
        /// Curls up next to the sleeping droid until it wakes.
        case nap
    }

    struct Frame {
        var rows: [String]
        var x: Int
        var y: Int
        var flipped = false
        /// Where the cat logically is (a sitting cat's left edge), which can differ from where it's drawn.
        var position: Int

        /// Stamps the cat with its outline. Draw it after the droid so the cat walks in front.
        func draw(into canvas: inout Canvas) {
            canvas.stamp(rows, x: x, y: y, flipped: flipped)
            canvas.outline("K", with: "q")
        }

        init(rows: [String], x: Int, y: Int, flipped: Bool = false, position: Int? = nil) {
            self.rows = rows
            self.x = x
            self.y = y
            self.flipped = flipped
            self.position = position ?? x
        }
    }

    /// The menu bar stage when the cat is enabled: cat on the left, droid on the right.
    static let stageWidth = 32
    static let droidX = stageWidth - Sprite.width
    private static let floor = 20
    private static let homeX = 1
    private static let pokeX = 9
    private static let headX = droidX + 3
    private static let offLeft = -14
    private static let offRight = stageWidth + 1
    private static let walkSpeed = 2
    private static let mischiefInterval: ClosedRange<TimeInterval> = 4 * 60...6 * 60

    var mode: Mode {
        didSet {
            beats = []
            x = mode == .always ? Self.homeX : Self.offLeft
            scheduleNext()
        }
    }
    var onSound: ((Phrase) -> Void)?

    private struct Beat {
        var ticks: Int
        var frame: (Int) -> Frame
        var droid: ((inout Sprite.Pose, Int) -> Void)?
        var sound: Phrase?
        /// Ends the beat early. With `ticks: .max`, the beat lasts until this is true.
        var until: ((DroidState) -> Bool)?
        var onStart: (() -> Void)?
        var isExit = false
    }

    private var beats: [Beat] = []
    private var beatTick = 0
    private var tick = 0
    private var x: Int
    private var nextMischief = Date()
    /// The droid state whose hat the cat stole. The hat comes back when the state changes.
    private var stolenHatFrom: DroidState?

    init(mode: Mode) {
        self.mode = mode
        x = mode == .always ? Self.homeX : Self.offLeft
        scheduleNext()
    }

    var isEnabled: Bool { mode != .off }

    // MARK: Ticking

    func advance(droid state: DroidState) {
        tick += 1
        if let stolen = stolenHatFrom, stolen != state { stolenHatFrom = nil }
        guard isEnabled else { return }

        // "Needs you" has to stay readable, so the cat scarpers.
        if state == .needsYou, !beats.isEmpty, !beats.contains(where: \.isExit) {
            beats = exitBeats()
            beatTick = 0
            startBeat()
            return
        }

        if let beat = beats.first {
            beatTick += 1
            if beatTick >= beat.ticks || beat.until?(state) == true {
                beats.removeFirst()
                beatTick = 0
                startBeat()
            }
        } else if Date() >= nextMischief, state != .needsYou {
            if let scene = pickScene(for: state) {
                perform(scene, droid: state)
            } else {
                scheduleNext()
            }
        }
    }

    /// Where the cat is right now, and how it changes the droid's pose.
    func current(droid state: DroidState) -> (frame: Frame?, adjust: (inout Sprite.Pose) -> Void) {
        let stolen = stolenHatFrom == state
        guard isEnabled else { return (nil, { _ in }) }

        if let beat = beats.first {
            let frame = beat.frame(beatTick)
            x = frame.position
            let t = beatTick
            return (frame, { pose in
                if stolen { pose.hat = .none }
                beat.droid?(&pose, t)
            })
        }

        let adjust: (inout Sprite.Pose) -> Void = { pose in if stolen { pose.hat = .none } }
        guard mode == .always else { return (nil, adjust) }
        return (resting(droid: state), adjust)
    }

    /// Starts something now (from the menu), or a specific scene (for testing).
    func summon(_ scene: Scene? = nil, droid state: DroidState) {
        guard isEnabled, state != .needsYou, let scene = scene ?? pickScene(for: state) else { return }
        perform(scene, droid: state)
    }

    // MARK: Scenes

    private func resting(droid state: DroidState) -> Frame {
        if state == .sleeping {
            return Frame(rows: CatSprite.loafAsleep, x: Self.homeX, y: Self.floor - CatSprite.loaf.count)
        }
        let rows: [String]
        if tick % 15 == 14 {
            rows = CatSprite.sitBlink
        } else {
            rows = (tick / 6) % 2 == 0 ? CatSprite.sit : CatSprite.sitTailFlick
        }
        return Frame(rows: rows, x: Self.homeX, y: Self.floor - rows.count)
    }

    private func pickScene(for state: DroidState) -> Scene? {
        if state == .sleeping {
            // An always-around cat is already napping.
            return mode == .visits ? .nap : nil
        }
        if state == .writing, Bool.random() { return .keyboard }
        var options: [Scene] = [.stare, .poke, .headLoaf]
        let hat = Sprite.pose(for: state, tick: 0).hat
        if hat != .antenna && hat != .none { options.append(.hatThief) }
        return options.randomElement()
    }

    private func perform(_ scene: Scene, droid state: DroidState) {
        scheduleNext()
        let start = mode == .always ? Self.homeX : Self.offLeft
        var script: [Beat] = []
        if mode == .visits { script.append(walk(from: start, to: Self.homeX)) }

        switch scene {
        case .stare:
            script.append(Beat(ticks: 10, frame: { t in self.sitting(at: Self.homeX, t: t) },
                               droid: { pose, _ in pose.eyes = .left }, sound: .mrrp))
        case .poke:
            script.append(walk(from: Self.homeX, to: Self.pokeX))
            script.append(Beat(ticks: 2, frame: { _ in self.sitting(at: Self.pokeX) },
                               droid: { pose, _ in pose.eyes = .left }, sound: .mrrp))
            script.append(Beat(ticks: 8, frame: { t in
                self.sitting(at: Self.pokeX, rows: t % 2 == 0 ? CatSprite.swat : CatSprite.sit)
            }, droid: { pose, t in pose.eyes = t % 2 == 0 ? .squint : .left }, sound: .startled))
        case .hatThief:
            let flight = [(-3, -2), (-7, -3), (-11, -3), (-16, -1), (-22, 2), (-29, 6)]
            script.append(walk(from: Self.homeX, to: Self.pokeX))
            script.append(Beat(ticks: 2, frame: { _ in self.sitting(at: Self.pokeX) }, sound: .mrrp))
            script.append(Beat(ticks: flight.count, frame: { _ in
                self.sitting(at: Self.pokeX, rows: CatSprite.swat)
            }, droid: { pose, t in
                pose.hatOffset = (x: flight[t].0, y: flight[t].1)
                pose.eyes = .wide
                pose.prop = .alert
            }, sound: .startled))
            script.append(Beat(ticks: 6, frame: { t in self.sitting(at: Self.pokeX, t: t) },
                               droid: { pose, _ in pose.eyes = .up },
                               onStart: { self.stolenHatFrom = state }))
        case .headLoaf:
            let onHead: (Int) -> Frame = { t in
                Frame(rows: t % 10 >= 7 ? CatSprite.loafAsleep : CatSprite.loaf, x: Self.headX, y: 3)
            }
            let grumpy: (inout Sprite.Pose, Int) -> Void = { pose, _ in
                pose.hat = .none
                pose.eyes = .up
            }
            script.append(walk(from: Self.homeX, to: Self.pokeX))
            script.append(Beat(ticks: 1, frame: { _ in self.sitting(at: Self.pokeX) }, sound: .mrrp))
            script.append(Beat(ticks: 8, frame: onHead, droid: grumpy, sound: .grumpy))
            script.append(Beat(ticks: 14, frame: onHead, droid: grumpy, sound: .purr))
            script.append(Beat(ticks: 1, frame: { _ in self.sitting(at: Self.pokeX) }))
        case .keyboard:
            script.append(walk(from: Self.homeX, to: Self.droidX - 4))
            script.append(walk(from: Self.droidX - 4, to: Self.offRight, sound: .garbled) { pose, _ in
                pose.eyes = .wide
            })
            if mode == .always { script.append(walk(from: Self.offLeft, to: Self.homeX, isExit: true)) }
            beats = script
            beatTick = 0
            startBeat()
            return  // already off-stage, or back home
        case .nap:
            script.append(Beat(ticks: .max, frame: { _ in
                Frame(rows: CatSprite.loafAsleep, x: Self.homeX, y: Self.floor - CatSprite.loaf.count)
            }, sound: .purr, until: { $0 != .sleeping }))
        }

        beats = script + exitBeats(from: lastX(of: script))
        beatTick = 0
        startBeat()
    }

    /// Visiting cats leave stage left; resident cats go back to their spot.
    private func exitBeats(from position: Int? = nil) -> [Beat] {
        let from = position ?? x
        let to = mode == .visits ? Self.offLeft : Self.homeX
        return from == to ? [] : [walk(from: from, to: to, isExit: true)]
    }

    private func lastX(of script: [Beat]) -> Int {
        guard let last = script.last else { return x }
        let ticks = last.ticks == .max ? 0 : last.ticks - 1
        let position = last.frame(ticks).position
        // Hopping down off the droid's head lands back at the poke spot.
        return position == Self.headX ? Self.pokeX : position
    }

    // MARK: Building blocks

    private func walk(from: Int, to: Int, sound: Phrase? = nil, isExit: Bool = false,
                      droid: ((inout Sprite.Pose, Int) -> Void)? = nil) -> Beat {
        let distance = to - from
        let ticks = max(1, abs(distance) / Self.walkSpeed)
        // Positions are where a sitting cat's left edge would be. The walking sprite is wider,
        // so shift it left to keep its nose from poking into the droid.
        let overhang = CatSprite.walkA[0].count - CatSprite.sit[0].count
        return Beat(ticks: ticks, frame: { t in
            let rows = t % 2 == 0 ? CatSprite.walkA : CatSprite.walkB
            let position = from + distance * (t + 1) / ticks
            return Frame(rows: rows, x: position - overhang, y: Self.floor - rows.count,
                         flipped: distance < 0, position: position)
        }, droid: droid, sound: sound, isExit: isExit)
    }

    private func sitting(at x: Int, rows: [String] = CatSprite.sit, t: Int = 0) -> Frame {
        let rows = rows == CatSprite.sit && t % 5 == 4 ? CatSprite.sitBlink : rows
        return Frame(rows: rows, x: x, y: Self.floor - rows.count)
    }

    private func startBeat() {
        guard let beat = beats.first else { return }
        beat.onStart?()
        if let sound = beat.sound { onSound?(sound) }
    }

    private func scheduleNext() {
        nextMischief = Date().addingTimeInterval(.random(in: Self.mischiefInterval))
    }
}
