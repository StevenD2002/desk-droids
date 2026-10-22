import AppKit

/// The pixel-art droid, assembled from ASCII grids: one character is one point.
/// `.` is transparent; every other character is a color from `palette`.
///
/// Layers, top to bottom: hat (7 rows) on a head (8 rows) on legs (4 rows).
enum Sprite {
    static let width = 18
    static let height = 21

    enum Hat { case none, antenna, nightcap, wizard, gradCap, chef, hardHat, crown, propeller, party }
    enum Eyes { case normal, blink, happy, wide, left, right, squint, dizzy, up, down, shut }
    enum Legs { case stand, stepLeft, stepRight, sit }
    enum Prop {
        case none, zzzLow, zzzHigh, alert, sparklesA, sparklesB
        case bonk, starsA, starsB, question, facepalmA, facepalmB
    }

    struct Pose {
        var hat: Hat
        var eyes: Eyes
        var legs: Legs = .stand
        var prop: Prop = .none
        var eyeColor: NSColor = .systemCyan
        var hatFrame = 0
        /// Nudges the whole droid, for hops and wobbles. Negative `dy` is up.
        var dx = 0
        var dy = 0
        /// Moves just the hat, e.g. when a cat knocks it off.
        var hatOffset = (x: 0, y: 0)
        /// Subagent drones buzzing around the hat (at most `maxDrones`), and their animation frame.
        var drones = 0
        var droneFrame = 0
        /// Confetti falling down the sides, this many rows along. Nil for no confetti.
        var confettiFall: Int?
    }

    // MARK: Grids

    private static let head = [
        ".BBBBBBBBBB.",
        "BBBBBBBBBBBB",
        "BB........BB",
        "BB........BB",
        "BB........BB",
        "BB........BB",
        "BBBBBBBBBBBB",
        ".BBBBBBBBBB.",
    ]

    /// Drawn into the head's 8×4 screen.
    private static let eyes: [Eyes: [String]] = [
        .normal: ["........", ".EE..EE.", ".EE..EE.", "........"],
        .blink:  ["........", "........", ".EE..EE.", "........"],
        .happy:  ["........", ".E....E.", "E.E..E.E", "........"],
        .wide:   ["EEE..EEE", "E.E..E.E", "EEE..EEE", "........"],
        .left:   ["........", "EE..EE..", "EE..EE..", "........"],
        .right:  ["........", "..EE..EE", "..EE..EE", "........"],
        .squint: ["E......E", ".E....E.", "E......E", "........"],
        .dizzy:  ["E.E..E.E", ".E....E.", "E.E..E.E", "........"],
        .up:     [".EE..EE.", ".EE..EE.", "........", "........"],
        .down:   ["........", "........", ".EE..EE.", ".EE..EE."],
        .shut:   ["........", "EE....EE", "..E..E..", "........"],
    ]

    private static let legs: [Legs: [String]] = [
        .stand: [
            "......B....B......",
            "......B....B......",
            "......B....B......",
            ".....BB....BB.....",
        ],
        .stepLeft: [
            "......B....B......",
            ".....BB....B......",
            "...........B......",
            "...........BB.....",
        ],
        .stepRight: [
            "......B....B......",
            "......B....BB.....",
            "......B...........",
            ".....BB...........",
        ],
        .sit: [
            ".....BB....BB.....",
        ],
    ]

    /// Each hat is 7 rows; the bottom row rests on top of the head. Some have two animation frames.
    private static let hats: [Hat: [[String]]] = [
        .antenna: [[
            "..................",
            "..................",
            "........EE........",
            ".......EEEE.......",
            "........EE........",
            "........BB........",
            "........BB........",
        ]],
        .nightcap: [[
            "..................",
            "..................",
            "..................",
            "........UUUUU.....",
            "......UUUUUUUUU...",
            ".....UUUUUUUU..WW.",
            "....WWWWWWWWWW.WW.",
        ]],
        .wizard: [[
            "..........P.......",
            ".........PP.......",
            "........PPP.......",
            ".......PSPPP......",
            "......PPPPPP......",
            ".....PPPPPSPP.....",
            "..PPPPPPPPPPPPPP..",
        ]],
        .gradCap: [[
            "..................",
            "..................",
            "........UU........",
            "..UUUUUUUUUUUUUU..",
            "......UUUUUU...Y..",
            "......UUUUUU...Y..",
            ".....UUUUUUUU..Y..",
        ]],
        .chef: [[
            "......gg..gg......",
            "....ggWWggWWgg....",
            "...gWWWWWWWWWWg...",
            "...gWWWWWWWWWWg...",
            "....gWWWWWWWWg....",
            "....gWWWWWWWWg....",
            "....gggggggggg....",
        ]],
        .hardHat: [[
            "..................",
            "..................",
            "......YYYYYY......",
            ".....YYYOOYYY.....",
            "....YYYYOOYYYY....",
            "....YYYYYYYYYY....",
            "..YYYYYYYYYYYYYY..",
        ]],
        .crown: [[
            "..................",
            "..................",
            "..................",
            "....Y..Y..Y..Y....",
            "....YY.YYYY.YY....",
            "....YYYYRRYYYY....",
            "....YYYYYYYYYY....",
        ]],
        .propeller: [
            [
                "..................",
                ".....YYYYYYYY.....",
                "........gg........",
                "......RRRUUU......",
                ".....RRRRUUUU.....",
                "....RRRRRUUUUU....",
                "....RRRRRUUUUU....",
            ],
            [
                "..................",
                "........YY........",
                "........gg........",
                "......RRRUUU......",
                ".....RRRRUUUU.....",
                "....RRRRRUUUUU....",
                "....RRRRRUUUUU....",
            ],
        ],
        .party: [[
            "........YY........",
            "........MM........",
            ".......MCCM.......",
            ".......CCMM.......",
            "......MMCCMM......",
            "......CCMMCC......",
            ".....MMCCMMCC.....",
        ]],
    ]

    /// Props are small grids placed at absolute canvas positions.
    private static let props: [Prop: [(x: Int, y: Int, grid: [String])]] = [
        .zzzLow: [(14, 3, ["EEEE", "..E.", ".E..", "EEEE"])],
        .zzzHigh: [(14, 0, ["EEEE", "..E.", ".E..", "EEEE"])],
        .alert: [(16, 8, ["E", "E", "E", ".", "E"])],
        .sparklesA: [(0, 8, [".S.", "SSS", ".S."]), (15, 13, [".S.", "SSS", ".S."])],
        .sparklesB: [(0, 13, [".S.", "SSS", ".S."]), (15, 8, [".S.", "SSS", ".S."])],
        .bonk: [(6, 0, ["Y.Y.Y", ".YYY.", "Y.Y.Y"])],
        .starsA: [(1, 3, ["S.S", ".S.", "S.S"]), (14, 6, ["S"]), (8, 0, ["S"])],
        .starsB: [(14, 2, ["S.S", ".S.", "S.S"]), (2, 6, ["S"]), (10, 0, ["S"])],
        .question: [(14, 1, ["EEE", "..E", ".E.", "...", ".E."])],
        .facepalmA: [cloud, (5, 6, ["U...U..", "..U...U"]), hand],
        .facepalmB: [cloud, (5, 6, [".U...U.", "U...U.."]), hand],
    ]

    private static let cloud = (x: 5, y: 2, grid: ["..ggg..", ".ggggg.", "ggggggg", ".ggggg."])
    /// A gray arm coming up from below the head to cover its left eye.
    private static let hand = (x: 1, y: 10, grid: [
        "....gggg",
        "...ggggg",
        "...gggg.",
        "..gg....",
        ".gg.....",
        "gg......",
        "g.......",
    ])

    /// Colored flecks that fall down the sides (wrapping around), one pixel per point.
    private static let confetti: [(x: Int, y: Int, color: Character)] = [
        (0, 1, "M"), (16, 0, "C"), (2, 5, "Y"), (15, 4, "G"), (1, 9, "R"), (17, 10, "M"),
        (0, 15, "C"), (16, 16, "Y"), (12, 1, "G"), (4, 3, "R"), (2, 18, "M"), (15, 19, "R"),
    ]

    static let maxDrones = 3

    /// One subagent drone: rotors on top (two frames), a body with an eye.
    private static let drone = [["g.g", "BEB"], [".g.", "BEB"]]
    /// Where each drone hovers: left of the hat, right of the hat, above it. One per `maxDrones`.
    private static let droneSpots = [(x: 0, y: 3), (x: 15, y: 3), (x: 7, y: 0)]

    private static let whiteish = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : NSColor(white: 0.78, alpha: 1)
    }

    /// Black fur that stays visible on a dark menu bar.
    private static let tuxedoBlack = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.2, alpha: 1) : NSColor(white: 0.1, alpha: 1)
    }

    /// A faint rim around the cat so black fur doesn't vanish into a dark menu bar.
    private static let tuxedoOutline = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(white: 0.5, alpha: 0.55) : .clear
    }

    private static func palette(eyeColor: NSColor) -> [Character: NSColor] {
        [
            "B": .labelColor,
            "E": eyeColor,
            "W": whiteish,
            "g": .systemGray,
            "P": .systemPurple,
            "S": .systemYellow,
            "Y": .systemYellow,
            "O": .systemOrange,
            "U": .systemBlue,
            "R": .systemRed,
            "M": .systemPink,
            "C": .systemTeal,
            "G": .systemGreen,
            "K": tuxedoBlack,
            "q": tuxedoOutline,
        ]
    }

    // MARK: Composition

    /// Draws the droid into `canvas` with its left edge at column `x`.
    static func draw(_ pose: Pose, into canvas: inout Canvas, x: Int) {
        let (ox, oy) = (x + pose.dx, pose.dy)
        // Standing, the head sits at row 8 (row 0 is headroom for hops). Sitting drops it onto the floor.
        let headTop = pose.legs == .sit ? 12 : 8
        canvas.stamp(legs[pose.legs]!, x: ox, y: oy + headTop + head.count)
        canvas.stamp(head, x: ox + 3, y: oy + headTop)
        canvas.stamp(eyes[pose.eyes]!, x: ox + 5, y: oy + headTop + 2)
        if let frames = hats[pose.hat] {
            canvas.stamp(frames[pose.hatFrame % frames.count],
                         x: ox + pose.hatOffset.x, y: oy + headTop - 7 + pose.hatOffset.y)
        }
        for prop in props[pose.prop] ?? [] {
            canvas.stamp(prop.grid, x: x + prop.x, y: prop.y)
        }
        if let fall = pose.confettiFall {
            for fleck in confetti {
                canvas.stamp([String(fleck.color)], x: x + fleck.x, y: (fleck.y + fall) % height)
            }
        }
        // Drones bob and drift a pixel, out of step with each other, so they look like they're buzzing.
        for (i, spot) in droneSpots.prefix(pose.drones).enumerated() {
            let frame = pose.droneFrame + i
            let drift = (frame / 3) % 2 * (spot.x > width / 2 ? -1 : 1)
            canvas.stamp(drone[frame % 2], x: x + spot.x + drift, y: spot.y + (frame / 2) % 2)
        }
    }

    static func image(of canvas: Canvas, eyeColor: NSColor) -> NSImage {
        let colors = palette(eyeColor: eyeColor)
        let pixels = canvas.pixels
        // The drawing handler runs at draw time, so `labelColor` resolves against the
        // menu bar's current appearance (black on light, white on dark).
        return NSImage(size: NSSize(width: canvas.width, height: canvas.height), flipped: true) { _ in
            for (y, row) in pixels.enumerated() {
                for (x, key) in row.enumerated() where key != "." {
                    colors[key]?.setFill()
                    NSRect(x: x, y: y, width: 1, height: 1).fill()
                }
            }
            return true
        }
    }

    /// Plain-text rendering of a lone droid, for checking sprites in a terminal.
    static func ascii(for pose: Pose) -> String {
        var canvas = Canvas(width: width, height: height)
        draw(pose, into: &canvas, x: 0)
        return canvas.ascii
    }
}

/// A grid of palette keys (`.` = empty) that sprites get stamped onto.
struct Canvas {
    let width: Int
    let height: Int
    private(set) var pixels: [[Character]]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        pixels = Array(repeating: Array(repeating: ".", count: width), count: height)
    }

    /// Copies the non-empty pixels of `rows` onto the canvas, clipping at the edges.
    mutating func stamp(_ rows: [String], x: Int, y: Int, flipped: Bool = false) {
        for (r, row) in rows.enumerated() {
            let pixels = flipped ? Array(row.reversed()) : Array(row)
            for (c, pixel) in pixels.enumerated() where pixel != "." {
                let (px, py) = (x + c, y + r)
                if (0..<width).contains(px), (0..<height).contains(py) {
                    self.pixels[py][px] = pixel
                }
            }
        }
    }

    /// Rims every `key` pixel with `outline` on its empty neighbors (up, down, left, right).
    mutating func outline(_ key: Character, with outline: Character) {
        let source = pixels
        for y in 0..<height {
            for x in 0..<width where source[y][x] == "." {
                let touches = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)].contains { nx, ny in
                    (0..<width).contains(nx) && (0..<height).contains(ny) && source[ny][nx] == key
                }
                if touches { pixels[y][x] = outline }
            }
        }
    }

    var ascii: String {
        pixels.map { String($0.map { $0 == "." ? " " : $0 }) }.joined(separator: "\n")
    }
}

extension Sprite {
    /// How the droid acts out each state. `tick` advances every animation frame.
    static func pose(for state: DroidState, tick: Int, drones: Int = 0) -> Pose {
        var pose = basePose(for: state, tick: tick)
        pose.drones = min(drones, maxDrones)
        pose.droneFrame = tick
        return pose
    }

    private static func basePose(for state: DroidState, tick: Int) -> Pose {
        let even = tick % 2 == 0
        switch state {
        case .sleeping:
            return Pose(hat: .nightcap, eyes: .blink, legs: .sit,
                        prop: (tick / 3) % 2 == 0 ? .zzzLow : .zzzHigh, eyeColor: .systemGray)
        case .idle:
            return Pose(hat: .antenna, eyes: tick % 12 == 11 ? .blink : .normal)
        case .thinking:
            return Pose(hat: .wizard, eyes: (tick / 4) % 2 == 0 ? .up : .normal)
        case .reading:
            return Pose(hat: .gradCap, eyes: (tick / 2) % 2 == 0 ? .left : .right)
        case .writing:
            return Pose(hat: .chef, eyes: .down, legs: even ? .stepLeft : .stepRight)
        case .running:
            return Pose(hat: .hardHat, eyes: .squint, legs: even ? .stepLeft : .stepRight)
        case .delegating:
            return Pose(hat: .crown, eyes: tick % 8 < 4 ? .left : .right)
        case .tinkering:
            return Pose(hat: .propeller, eyes: .normal, hatFrame: tick)
        case .compacting:
            // Bonk: knocked down a pixel, then seeing stars for a while.
            switch tick % 8 {
            case 0: return Pose(hat: .antenna, eyes: .squint, prop: .bonk, eyeColor: .systemPurple, dy: 1)
            case 1: return Pose(hat: .antenna, eyes: .squint, prop: .bonk, eyeColor: .systemPurple)
            default: return Pose(hat: .antenna, eyes: .dizzy, prop: even ? .starsA : .starsB, eyeColor: .systemPurple)
            }
        case .forgetful:
            return Pose(hat: .antenna, eyes: (tick / 2) % 2 == 0 ? .up : .left, prop: .question,
                        eyeColor: .systemPurple)
        case .oops:
            return Pose(hat: .none, eyes: .shut, prop: even ? .facepalmA : .facepalmB, eyeColor: .systemBlue)
        case .needsYou:
            return Pose(hat: .antenna, eyes: .wide, prop: even ? .alert : .none,
                        eyeColor: .systemOrange, dy: even ? -1 : 0)
        case .triumph:
            var pose = Pose(hat: .party, eyes: .happy, eyeColor: .systemGreen, dy: even ? -1 : 0)
            pose.confettiFall = tick
            return pose
        case .done:
            return Pose(hat: .party, eyes: .happy, prop: even ? .sparklesA : .sparklesB,
                        eyeColor: .systemGreen, dy: tick % 4 == 0 ? -1 : 0)
        }
    }

    /// Shown when the hook server can't start.
    static let broken = Pose(hat: .antenna, eyes: .dizzy, eyeColor: .systemRed)
}
