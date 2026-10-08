import SwiftUI
import AppKit

// MARK: - Pixel style
//
// Second mascot style: the same monkey as MascotView's vector rig, but drawn as a
// 24x24 pixel sprite and animated frame-by-frame at a low, stepped rate (no tweening).
// Every sprite is a character map so the art can be edited in a text editor — no
// image assets. Everything here is a pure function of (state, previous state, time),
// same philosophy as `Pose`: a state change can never leave an animation stuck.

enum PixelRig {
    static let grid = 24                    // logical sprite size (cells per side)
    static let baseCell: CGFloat = 3        // points per cell at scale 1.0 (24 cells = 72pt, like Rig.bodyW)
    static let fps: Double = 6              // animation step rate (slow, stepped)
    static let transitionDuration = 0.6     // dissolve/scatter between states
    static let badgeGapCells = 7            // asking → done badge spacing, in cells

    /// Character palette for the sprite maps. `g` is the phosphor channel — it takes
    /// the state tint (green / cyan / orange / done-green) at draw time.
    static func color(_ ch: Character, phosphor: Color) -> Color? {
        switch ch {
        case "#": return Rig.stroke
        case "i": return Rig.fur
        case "d": return Rig.furDark
        case "v": return Rig.mask
        case "g": return phosphor
        case "w": return .white
        case "s": return Rig.shell
        default:  return nil
        }
    }

    /// Cell size in points for a given mascot scale, snapped to half points so every
    /// pixel edge lands on a Retina device pixel — this is what keeps the squares crisp.
    static func cell(forScale scale: CGFloat) -> CGFloat {
        max(1, (baseCell * scale * 2).rounded() / 2)
    }
}

/// A small sprite fragment anchored at (x, y) on the 24x24 grid. `.` is transparent.
struct PixelPart {
    let x: Int
    let y: Int
    let rows: [String]
}

/// Legend: `.` empty · `#` outline · `i` indigo · `d` shade · `v` violet · `g` eye/phosphor · `w` white
enum PixelSprites {
    // Figure is centred on x = 11, occupies rows 1...22.
    static let head = PixelPart(x: 1, y: 1, rows: [
        ".....###########.....",
        "....#iiiiiiiiiii#....",
        "...#iiiiiiiiiiiii#...",
        ".###iivvvvvvvvvii###.",
        "#ivi#ivvvvvvvvvi#ivi#",
        "#ivi#ivvvvvvvvvi#ivi#",
        "#ivi#iivvvvvvvii#ivi#",
        ".###iiivvvvvvviii###.",
        "...#iiiivvvvviiii#...",
        "...#iiiiiiiiiiiii#...",
        "....#iiiiiiiiiii#....",
        ".....###########.....",
    ])

    static let eyesOpen  = PixelPart(x: 8, y: 5, rows: ["gg..gg", "gg..gg"])
    static let eyesBlink = PixelPart(x: 8, y: 6, rows: ["##..##"])
    static let eyesHappy = PixelPart(x: 7, y: 5, rows: [".g....g.", "g.g..g.g"])
    static let eyesWide  = PixelPart(x: 8, y: 4, rows: ["gg..gg", "gg..gg", "gg..gg"])

    static let mouthSmile = PixelPart(x: 9, y: 9,  rows: ["#...#", ".###."])
    static let mouthFlat  = PixelPart(x: 10, y: 9, rows: ["###"])
    static let mouthO     = PixelPart(x: 10, y: 8, rows: ["###", "#d#", "###"])
    static let mouthGrin  = PixelPart(x: 8, y: 8,  rows: ["#.....#", ".#####."])

    static let torso = PixelPart(x: 7, y: 13, rows: [
        "########",
        "#iivvii#",
        "#ivvvvi#",
        "#ivvvvi#",
        "#iivvii#",
        "########",
    ])

    static let armLDown   = PixelPart(x: 4,  y: 13, rows: ["###", "#i#", "#i#", "#v#", "###"])
    static let armRDown   = PixelPart(x: 15, y: 13, rows: ["###", "#i#", "#i#", "#v#", "###"])
    static let armLTypeUp = PixelPart(x: 4,  y: 12, rows: ["###", "#i#", "#v#", "###"])
    static let armRTypeUp = PixelPart(x: 15, y: 12, rows: ["###", "#i#", "#v#", "###"])
    static let armLTypeDn = PixelPart(x: 4,  y: 14, rows: ["###", "#i#", "#v#", "###"])
    static let armRTypeDn = PixelPart(x: 15, y: 14, rows: ["###", "#i#", "#v#", "###"])
    static let armLUp = PixelPart(x: 1,  y: 9, rows: ["###...", "#v#...", "#i#...", "#i#...", "#i####", "###i##", "..####"])
    static let armRUp = PixelPart(x: 17, y: 9, rows: ["...###", "...#v#", "...#i#", "...#i#", "####i#", "##i###", "####.."])

    static let legsStand = PixelPart(x: 7, y: 18, rows: [
        "##....##",
        "#i#..#i#",
        "#i#..#i#",
        "#v#..#v#",
        "##....##",
    ])
    static let legsTuck = PixelPart(x: 7, y: 18, rows: [
        "##....##",
        "#v#..#v#",
        "##....##",
    ])

    /// Tail leaves the right hip and hooks up beside the torso. Three frames = flick.
    static let tailRelaxed = PixelPart(x: 14, y: 10, rows: [
        "....###.",
        "...##i#.",
        "...#i##.",
        "...#i#..",
        "...#i#..",
        "..##i#..",
        "###i#...",
        "#ii#....",
        "###.....",
    ])
    static let tailOut = PixelPart(x: 14, y: 10, rows: [
        ".....###",
        "....##i#",
        "...##i##",
        "...#i#..",
        "...#i#..",
        "..##i#..",
        "###i#...",
        "#ii#....",
        "###.....",
    ])
    static let tailCurl = PixelPart(x: 14, y: 10, rows: [
        "..###...",
        "..#i##..",
        "..##ii#.",
        "...##i#.",
        "...#i#..",
        "..##i#..",
        "###i#...",
        "#ii#....",
        "###.....",
    ])

    // Speech-bubble glyphs (drawn in the phosphor colour).
    static let glyphQuestion: [String] = [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."]
    static let glyphCheck: [String]    = ["......#", ".....#.", "....#..", "#..#...", ".##....", "..#...."]

    /// 3x5 digit font for badges.
    static let digits: [[String]] = [
        ["###", "#.#", "#.#", "#.#", "###"],
        [".#.", "##.", ".#.", ".#.", "###"],
        ["###", "..#", "###", "#..", "###"],
        ["###", "..#", "###", "..#", "###"],
        ["#.#", "#.#", "###", "..#", "..#"],
        ["###", "#..", "###", "..#", "###"],
        ["###", "#..", "###", "#.#", "###"],
        ["###", "..#", ".#.", ".#.", ".#."],
        ["###", "#.#", "###", "#.#", "###"],
        ["###", "#.#", "###", "..#", "###"],
    ]
}

// MARK: - Grid

struct PixelGrid: Equatable {
    private(set) var cells: [[Character]]

    init() {
        cells = Array(repeating: Array(repeating: ".", count: PixelRig.grid), count: PixelRig.grid)
    }

    mutating func paint(_ part: PixelPart, dx: Int = 0, dy: Int = 0) {
        for (r, row) in part.rows.enumerated() {
            for (c, ch) in row.enumerated() where ch != "." {
                let x = part.x + c + dx, y = part.y + r + dy
                guard (0..<PixelRig.grid).contains(x), (0..<PixelRig.grid).contains(y) else { continue }
                cells[y][x] = ch
            }
        }
    }

    subscript(x: Int, y: Int) -> Character { cells[y][x] }
}

/// One cell ready to draw: grid coordinates (may be fractional during a scatter) + palette char.
struct PixelCell {
    var x: Double
    var y: Double
    var ch: Character
}

// MARK: - Frame

/// Everything the Canvas needs for one tick. Pure function of (state, prev, time).
struct PixelFrame {
    var cells: [PixelCell] = []
    var hopCells: Int = 0
    var bubble: [String]? = nil
    var sparkles: [(x: Int, y: Int, big: Bool)] = []
    var phosphor: Color = Rig.eyeGreen
    /// Halo brightness, already quantised to 8 fps (0 = off). Drawn as a 1-cell lit
    /// outline hugging the sprite.
    var halo: Double = 0
    var haloCells: [PixelCell] = []

    /// Stepped clock: everything animates on `step` so there is no in-between motion.
    static func step(_ t: Double) -> Int { Int(floor(t * PixelRig.fps)) }

    static func make(state: MascotDisplayState,
                     previous: MascotDisplayState,
                     t: Double,
                     elapsed: Double,
                     motion: MotionLevel,
                     reaction: Double?) -> PixelFrame {
        var f = PixelFrame()
        let reduceMotion = motion == .none
        let s = reduceMotion ? 0 : step(t)
        let e = reduceMotion ? 0 : step(elapsed)
        let (grid, hop) = sprite(state: state, s: s, e: e, t: t, elapsed: elapsed, motion: motion, reaction: reaction, frame: &f)
        f.hopCells = hop
        f.phosphor = StateColors.tint(for: state)
        // Quantised to quarter steps so the aura "clicks" between levels like the rest.
        let raw = StateColors.intensity(for: state, t: t, elapsed: elapsed, motion: motion, stepped: true)
        f.halo = (raw * 4).rounded() / 4
        f.haloCells = outline(of: grid)

        // Pixel transition: old sprite dissolves away cell by cell while the new one
        // reassembles, with cells "in flight" drawn a few cells off their spot.
        let progress = reduceMotion ? 1.0 : min(1.0, elapsed / PixelRig.transitionDuration)
        if progress < 1, previous != .none, previous != state {
            var scratch = PixelFrame()
            let (old, _) = sprite(state: previous, s: s, e: 99, t: t, elapsed: 99, motion: .none, reaction: nil, frame: &scratch)
            let p = floor(progress * PixelRig.fps * PixelRig.transitionDuration) / (PixelRig.fps * PixelRig.transitionDuration)
            f.cells = dissolve(from: old, to: grid, progress: p)
            f.sparkles = []
            f.bubble = nil
            f.haloCells = []
        } else {
            f.cells = flatten(grid)
        }
        return f
    }

    /// Empty cells 4-adjacent to the sprite — the 1px aura ring.
    private static func outline(of g: PixelGrid) -> [PixelCell] {
        var out: [PixelCell] = []
        let n = PixelRig.grid
        for y in 0..<n {
            for x in 0..<n where g[x, y] == "." {
                let near = (x > 0 && g[x - 1, y] != ".") || (x < n - 1 && g[x + 1, y] != ".")
                    || (y > 0 && g[x, y - 1] != ".") || (y < n - 1 && g[x, y + 1] != ".")
                if near { out.append(PixelCell(x: Double(x), y: Double(y), ch: "g")) }
            }
        }
        return out
    }

    private static func flatten(_ g: PixelGrid) -> [PixelCell] {
        var out: [PixelCell] = []
        out.reserveCapacity(300)
        for y in 0..<PixelRig.grid {
            for x in 0..<PixelRig.grid where g[x, y] != "." {
                out.append(PixelCell(x: Double(x), y: Double(y), ch: g[x, y]))
            }
        }
        return out
    }

    /// Deterministic per-cell noise in [0, 1).
    private static func hash(_ x: Int, _ y: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: x &* 374761393 &+ y &* 668265263)
        h = (h ^ (h >> 13)) &* 1274126177
        h ^= h >> 16
        return Double(h % 1000) / 1000
    }

    private static func dissolve(from old: PixelGrid, to new: PixelGrid, progress p: Double) -> [PixelCell] {
        var out: [PixelCell] = []
        let flight = 0.3   // fraction of the timeline a cell spends "in the air"
        for y in 0..<PixelRig.grid {
            for x in 0..<PixelRig.grid {
                let h = hash(x, y)
                let dir = (dx: cos(h * 2 * .pi * 7), dy: sin(h * 2 * .pi * 7))
                let o = old[x, y], n = new[x, y]
                if o != "." {
                    if h > p + flight {
                        out.append(PixelCell(x: Double(x), y: Double(y), ch: o))
                    } else if h > p {
                        // leaving: scatter outward, further the longer it has been going
                        let k = (1 - (h - p) / flight) * 3
                        out.append(PixelCell(x: Double(x) + (dir.dx * k).rounded(), y: Double(y) + (dir.dy * k).rounded(), ch: o))
                    }
                }
                if n != "." {
                    if h < p - flight {
                        out.append(PixelCell(x: Double(x), y: Double(y), ch: n))
                    } else if h < p {
                        // arriving: fly in from a few cells away
                        let k = ((h - (p - flight)) / flight) * 3
                        out.append(PixelCell(x: Double(x) - (dir.dx * k).rounded(), y: Double(y) - (dir.dy * k).rounded(), ch: n))
                    }
                }
            }
        }
        return out
    }

    // MARK: Per-state sprite assembly

    private static func sprite(state: MascotDisplayState, s: Int, e: Int, t: Double, elapsed: Double,
                               motion: MotionLevel, reaction: Double?, frame f: inout PixelFrame) -> (PixelGrid, Int) {
        var g = PixelGrid()
        var hop = 0
        var eyes = PixelSprites.eyesOpen
        var mouth = PixelSprites.mouthSmile
        var armL = PixelSprites.armLDown, armR = PixelSprites.armRDown
        var legs = PixelSprites.legsStand
        var tail = PixelSprites.tailRelaxed
        var eyeDX = 0
        var bodyDY = 0
        let animate = motion != .none
        let lively = motion == .lively
        // Occasional blink (6–10 s apart), one step long. Cheap: a hash per 8 s segment.
        let blink = animate && Attention.blinking(t: Double(s) / PixelRig.fps, window: 1 / PixelRig.fps)

        switch state {
        case .none:
            break

        case .idle, .stale:
            if state == .stale { mouth = PixelSprites.mouthFlat }
            if blink { eyes = PixelSprites.eyesBlink }
            if lively {
                // Breathing: 1px settle for the second half of a ~2s cycle; tail flick every ~4s.
                bodyDY = (s / 6) % 2 == 0 ? 0 : 1
                switch s % 24 {
                case 20: tail = PixelSprites.tailOut
                case 21: tail = PixelSprites.tailCurl
                case 22: tail = PixelSprites.tailOut
                default: tail = PixelSprites.tailRelaxed
                }
            }

        case .working:
            mouth = PixelSprites.mouthFlat
            tail = PixelSprites.tailCurl
            if lively {
                // Paws typing: alternate every 2 steps; eyes scan one pixel at a time.
                let up = (s / 2) % 2 == 0
                armL = up ? PixelSprites.armLTypeUp : PixelSprites.armLTypeDn
                armR = up ? PixelSprites.armRTypeDn : PixelSprites.armRTypeUp
                let scan = [-1, -1, 0, 0, 1, 1, 0, 0]
                eyeDX = scan[(s / 3) % scan.count]
                tail = (s / 6) % 2 == 0 ? PixelSprites.tailCurl : PixelSprites.tailRelaxed
                bodyDY = (s / 6) % 2 == 0 ? 0 : 1
            } else {
                // Still "at the keyboard" pose — colour carries the signal.
                armL = PixelSprites.armLTypeUp
                armR = PixelSprites.armRTypeUp
            }
            if blink { eyes = PixelSprites.eyesBlink }

        case .asking:
            eyes = PixelSprites.eyesWide
            mouth = PixelSprites.mouthO
            armL = PixelSprites.armLUp; armR = PixelSprites.armRUp
            tail = PixelSprites.tailCurl
            f.bubble = PixelSprites.glyphQuestion
            // One stepped jump on entry, then a single nudge every ~30 s while still asking.
            let window = Attention.askingWindow(elapsed)
            if animate, window < Attention.askingJump {
                let hops = [0, -2, -4, -5, -4, -2]
                hop = hops[min(hops.count - 1, step(window))]
                if hop <= -3 { legs = PixelSprites.legsTuck }
            }

        case .done:
            eyes = PixelSprites.eyesHappy
            mouth = PixelSprites.mouthGrin
            armL = PixelSprites.armLUp; armR = PixelSprites.armRUp
            f.bubble = PixelSprites.glyphCheck
            // Short celebration: three decaying hops (3 steps each = 1.5 s), then still.
            if animate, elapsed < Attention.doneCelebration {
                let n = e / 3
                if n < 3 {
                    let amp = [5, 3, 2][n]
                    let shape = [0, 2, 1]   // halves of amp
                    hop = -(amp * shape[e % 3]) / 2
                    if hop <= -2 { legs = PixelSprites.legsTuck }
                }
                tail = e % 2 == 0 ? PixelSprites.tailOut : PixelSprites.tailRelaxed
                let spots = [(2, 2), (21, 3), (1, 14), (22, 12), (4, 22), (20, 21), (12, 0)]
                for (i, p) in spots.enumerated() where (s + i * 3) % 7 < 3 {
                    f.sparkles.append((x: p.0, y: p.1, big: (s + i) % 2 == 0))
                }
            }
        }

        // One-shot reaction to the user (hover / click / popover / rename): a little
        // wave with the right paw and a glance, then back to the still pose.
        if animate, let r = reaction, r < Attention.reaction, state != .asking, state != .done {
            armR = step(r) % 2 == 0 ? PixelSprites.armRUp : PixelSprites.armRTypeUp
            eyeDX = 1
            mouth = PixelSprites.mouthSmile
        }

        g.paint(tail, dy: bodyDY)
        g.paint(legs)
        g.paint(armL, dy: bodyDY)
        g.paint(armR, dy: bodyDY)
        g.paint(PixelSprites.torso, dy: bodyDY)
        g.paint(PixelSprites.head, dy: bodyDY)
        g.paint(eyes, dx: eyeDX, dy: bodyDY)
        g.paint(mouth, dy: bodyDY)
        return (g, hop)
    }
}

// MARK: - View

struct PixelCharacterView: View {
    let frame: PixelFrame
    let count: Int
    let doneCount: Int
    let askingCount: Int
    let scale: CGFloat

    var body: some View {
        let cell = PixelRig.cell(forScale: scale)
        Canvas(rendersAsynchronously: false) { ctx, size in
            let n = CGFloat(PixelRig.grid)
            // Snap the sprite origin to half points too — otherwise the crisp cell
            // size would be undone by a fractional offset.
            let ox = ((size.width - n * cell) / 2 * 2).rounded() / 2
            let oy = ((size.height - n * cell) / 2 * 2 + 4 * cell).rounded() / 2   // sit a little low, leaves bubble room
            let hop = CGFloat(frame.hopCells) * cell

            func rect(_ x: Double, _ y: Double, w: Double = 1, h: Double = 1) -> CGRect {
                CGRect(x: ox + CGFloat(x) * cell, y: oy + CGFloat(y) * cell + hop, width: cell * CGFloat(w), height: cell * CGFloat(h))
            }
            func px(_ x: Double, _ y: Double, _ color: Color) {
                ctx.fill(Path(rect(x, y)), with: .color(color))
            }
            func paint(_ rows: [String], at x: Int, _ y: Int, map: (Character) -> Color?) {
                for (r, row) in rows.enumerated() {
                    for (c, ch) in row.enumerated() {
                        if let col = map(ch) { px(Double(x + c), Double(y + r), col) }
                    }
                }
            }

            // State aura: 1px outline ring, stepped brightness.
            if frame.halo > 0 {
                for c in frame.haloCells { px(c.x, c.y, frame.phosphor.opacity(0.15 + 0.6 * frame.halo)) }
            }

            // Body (eyes follow the aura brightness: dim when idle/stale, bright when it matters)
            let eye = frame.phosphor.opacity(0.5 + 0.5 * frame.halo)
            for c in frame.cells {
                if let col = PixelRig.color(c.ch, phosphor: eye) { px(c.x, c.y, col) }
            }

            // Sparkles (done)
            for sp in frame.sparkles {
                if sp.big {
                    paint([".w.", "www", ".w."], at: sp.x - 1, sp.y - 1) { $0 == "w" ? frame.phosphor : nil }
                } else {
                    px(Double(sp.x), Double(sp.y), .white)
                }
            }

            // Speech bubble above the head: shell box + outline + glyph.
            if let glyph = frame.bubble {
                let gw = glyph[0].count, gh = glyph.count
                let bw = gw + 4, bh = gh + 2
                let bx = PixelRig.grid / 2 - bw / 2, by = -bh - 1
                ctx.fill(Path(rect(Double(bx), Double(by), w: Double(bw), h: Double(bh))), with: .color(Rig.shell))
                // 1-cell outline with notched corners (pixel-rounded)
                let o = Rig.stroke
                for x in (bx + 1)..<(bx + bw - 1) { px(Double(x), Double(by), o); px(Double(x), Double(by + bh - 1), o) }
                for y in (by + 1)..<(by + bh - 1) { px(Double(bx), Double(y), o); px(Double(bx + bw - 1), Double(y), o) }
                ctx.fill(Path(rect(Double(bx), Double(by), w: 1, h: 1)), with: .color(.clear))
                // tail of the bubble
                px(Double(PixelRig.grid / 2 - 1), Double(by + bh), o)
                px(Double(PixelRig.grid / 2 - 1), Double(by + bh - 1), Rig.shell)
                paint(glyph, at: bx + 2, by + 1) { $0 == "#" ? frame.phosphor : nil }
            }

            // Badges — pixel pills with a 3x5 digit font, at the body box corners.
            func badge(_ value: Int, color: Color, atX x: Int, y: Int) {
                let text = String(min(value, 99))
                let w = text.count * 4 + 1, h = 7
                let o = Rig.stroke
                ctx.fill(Path(rect(Double(x), Double(y), w: Double(w), h: Double(h))), with: .color(color))
                for xx in (x + 1)..<(x + w - 1) { px(Double(xx), Double(y - 1), o); px(Double(xx), Double(y + h), o) }
                for yy in y..<(y + h) { px(Double(x - 1), Double(yy), o); px(Double(x + w), Double(yy), o) }
                for (i, chr) in text.enumerated() {
                    if let d = chr.wholeNumberValue {
                        paint(PixelSprites.digits[d], at: x + 1 + i * 4, y + 1) { $0 == "#" ? .white : nil }
                    }
                }
            }
            if count >= 2 { badge(count, color: .accentColor, atX: 19, y: -2) }
            if askingCount >= 1 { badge(askingCount, color: Rig.askingColor, atX: 0, y: -2) }
            if doneCount >= 1 { badge(doneCount, color: Rig.doneColor, atX: askingCount >= 1 ? PixelRig.badgeGapCells : 0, y: -2) }
        }
        .frame(width: kBasePanelSize.width * scale, height: kBasePanelSize.height * scale)
        .shadow(color: .black.opacity(0.28), radius: 6 * scale, y: 3 * scale)
    }
}

