import AppKit

/// The pixel-art droid, assembled from ASCII grids: one character is one point.
/// `.` is transparent; every other character is a color from `palette`.
///
/// Layers, top to bottom: hat (7 rows) on a head (8 rows) on legs (4 rows).
enum Sprite {
    static let width = 18
    static let height = 21

    enum Hat { case none, antenna, nightcap, wizard, gradCap, chef, hardHat, crown, propeller, party }
    enum Eyes { case normal, blink, happy, wide, left, right, squint, dizzy, up, down }
    enum Legs { case stand, stepLeft, stepRight, sit }
    enum Prop { case none, zzzLow, zzzHigh, alert, sparklesA, sparklesB }

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
    ]

    private static let whiteish = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : NSColor(white: 0.78, alpha: 1)
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
        ]
    }

    // MARK: Composition

    /// Composites a pose into a grid of color keys (`.` = empty).
    static func grid(for pose: Pose) -> [[Character]] {
        var canvas = Array(repeating: Array(repeating: Character("."), count: width), count: height)

        func stamp(_ rows: [String], x: Int, y: Int) {
            for (r, row) in rows.enumerated() {
                for (c, pixel) in row.enumerated() where pixel != "." {
                    let (px, py) = (x + c + pose.dx, y + r + pose.dy)
                    if (0..<width).contains(px), (0..<height).contains(py) {
                        canvas[py][px] = pixel
                    }
                }
            }
        }

        // Standing, the head sits at row 8 (row 0 is headroom for hops). Sitting drops it onto the floor.
        let headTop = pose.legs == .sit ? 12 : 8
        stamp(legs[pose.legs]!, x: 0, y: headTop + head.count)
        stamp(head, x: 3, y: headTop)
        stamp(eyes[pose.eyes]!, x: 5, y: headTop + 2)
        if let frames = hats[pose.hat] {
            stamp(frames[pose.hatFrame % frames.count], x: 0, y: headTop - 7)
        }
        for prop in props[pose.prop] ?? [] {
            stamp(prop.grid, x: prop.x - pose.dx, y: prop.y - pose.dy)
        }
        return canvas
    }

    static func image(for pose: Pose) -> NSImage {
        let canvas = grid(for: pose)
        let colors = palette(eyeColor: pose.eyeColor)
        // The drawing handler runs at draw time, so `labelColor` resolves against the
        // menu bar's current appearance (black on light, white on dark).
        return NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            for (y, row) in canvas.enumerated() {
                for (x, key) in row.enumerated() where key != "." {
                    colors[key]?.setFill()
                    NSRect(x: x, y: y, width: 1, height: 1).fill()
                }
            }
            return true
        }
    }

    /// Plain-text rendering, for checking sprites in a terminal (`swift run DeskDroids --ascii`).
    static func ascii(for pose: Pose) -> String {
        grid(for: pose).map { String($0.map { $0 == "." ? " " : $0 }) }.joined(separator: "\n")
    }
}

extension Sprite {
    /// How the droid acts out each state. `tick` advances every animation frame.
    static func pose(for state: DroidState, tick: Int) -> Pose {
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
            return Pose(hat: .antenna, eyes: .dizzy, eyeColor: .systemPurple, dx: even ? -1 : 1)
        case .needsYou:
            return Pose(hat: .antenna, eyes: .wide, prop: even ? .alert : .none,
                        eyeColor: .systemOrange, dy: even ? -1 : 0)
        case .done:
            return Pose(hat: .party, eyes: .happy, prop: even ? .sparklesA : .sparklesB,
                        eyeColor: .systemGreen, dy: tick % 4 == 0 ? -1 : 0)
        }
    }

    /// Shown when the hook server can't start.
    static let broken = Pose(hat: .antenna, eyes: .dizzy, eyeColor: .systemRed)
}
