import SwiftUI

// MARK: - Rig constants
//
// Monkey fork of Termi's rig. Every proportion of the character lives here.
// Brand reference: Monkey OS logo (pixel monkey, indigo->violet, neon-green eyes).

enum Rig {
    /// Overall character box — badges and the bubble are placed relative to it.
    static let bodyW: CGFloat = 72
    static let bodyH: CGFloat = 58
    static let outline: CGFloat = 1.4

    static let headSize = CGSize(width: 44, height: 36)
    static let headY: CGFloat = -11
    static let earR: CGFloat = 8.5
    static let earX: CGFloat = 24
    static let earY: CGFloat = -12
    static let maskSize = CGSize(width: 32, height: 25)
    static let maskY: CGFloat = -8

    static let eyeR: CGFloat = 3.8        // half-side of the square "pixel" eye
    static let eyeGap: CGFloat = 8        // half-distance between eyes
    static let eyeY: CGFloat = -12

    static let mouthY: CGFloat = -1
    static let mouthW: CGFloat = 10

    static let torsoSize = CGSize(width: 28, height: 22)
    static let torsoY: CGFloat = 17

    static let legSpread: CGFloat = 8
    static let legLen: CGFloat = 9
    static let legW: CGFloat = 5
    static let footW: CGFloat = 9

    static let armSeg1 = CGSize(width: 8, height: 9)
    static let armSeg2 = CGSize(width: 5, height: 8)
    static let armW: CGFloat = 4.5

    static let tailBase = CGPoint(x: 13, y: 24)

    /// Brand palette (sampled from Monkey-os-logo.png).
    static let fur = Color(red: 0.20, green: 0.27, blue: 0.86)       // indigo
    static let furDark = Color(red: 0.12, green: 0.16, blue: 0.55)   // shadow navy
    static let mask = Color(red: 0.42, green: 0.30, blue: 0.93)      // violet face/belly
    static let shell = Color(red: 0.06, green: 0.08, blue: 0.30)     // bubble fill
    static let stroke = Color(red: 0.05, green: 0.06, blue: 0.22)    // outline
    static let eyeGreen = Color(red: 0.13, green: 1.0, blue: 0.25)

    static let askingColor = Color(red: 1.0, green: 0.72, blue: 0.3)
    static let doneColor = Color(red: 0.13, green: 0.58, blue: 0.32)
    static let badgeGap: CGFloat = 18
}

// MARK: - Animation parameters
//
// A pure function of (state, elapsed time). No @State animation machinery, so a state
// change can never leave a half-finished or stuck repeating animation behind.

struct Pose {
    var hopY: CGFloat = 0
    var breathe: CGFloat = 1
    var bobY: CGFloat = 0
    var eyeOpen: CGFloat = 1
    var eyeScale: CGFloat = 1
    var eyeLookX: CGFloat = 0
    var happyEyes = false
    var mouthCurve: CGFloat = 0.25
    var mouthOpen = false
    var armAngleL: Double = 0       // degrees; negative raises the arm
    var armAngleR: Double = 0
    var pawTapL: CGFloat = 0        // working: paws "typing" up/down
    var pawTapR: CGFloat = 0
    var tailAngle: Double = 0       // degrees of sway around the tail base
    var tailCurl: CGFloat = 1       // 1 = relaxed hook, higher = tighter curl
    var bubble: String? = nil
    var glow: CGFloat = 0
    var phosphor: Color = Rig.eyeGreen
    /// Halo/aura brightness around the whole character (StateColors.intensity).
    var halo: CGFloat = 0

    static func make(state: MascotDisplayState, t: Double, elapsed: Double,
                     motion: MotionLevel, reaction: Double?) -> Pose {
        var p = Pose()
        let animate = motion != .none
        let lively = motion == .lively
        p.phosphor = StateColors.tint(for: state)
        p.halo = CGFloat(StateColors.intensity(for: state, t: t, elapsed: elapsed, motion: motion))
        p.glow = p.halo
        // Occasional blink (6–10 s apart, 0.12 s) — the only idle motion in Minimal.
        let blink = animate && Attention.blinking(t: t)

        switch state {
        case .none:
            break

        case .idle, .stale:
            p.mouthCurve = state == .stale ? 0.0 : 0.25
            p.armAngleL = 4
            p.armAngleR = 4
            p.eyeOpen = blink ? 0.08 : 1
            if lively {
                p.breathe = 1 + 0.015 * sin(2 * .pi * t / 3.2)
                p.tailAngle = 7 * sin(2 * .pi * t / 4.0)
            }

        case .working:
            // Paws held forward at the keyboard; colour (cyan eyes + halo) says "busy".
            p.armAngleL = 18
            p.armAngleR = 18
            p.mouthCurve = 0.05
            p.tailCurl = 1.3
            p.tailAngle = 6
            p.eyeOpen = blink ? 0.08 : 1
            if lively {
                p.bobY = 1.5 * sin(2 * .pi * t / 2.0)
                p.pawTapL = 2.2 * CGFloat(max(0, sin(2 * .pi * t / 0.6)))
                p.pawTapR = 2.2 * CGFloat(max(0, sin(2 * .pi * t / 0.6 + .pi)))
                p.eyeLookX = 2.2 * sin(2 * .pi * t / 3.5)
                p.tailAngle = 10 * sin(2 * .pi * t / 2.0)
            }

        case .asking:
            p.eyeScale = 1.18
            p.mouthOpen = true
            p.armAngleL = -52
            p.armAngleR = -52
            p.tailAngle = -22
            p.tailCurl = 1.6
            p.bubble = "?"
            // One eased jump on entry, then a single nudge every ~30 s while still asking.
            let window = Attention.askingWindow(elapsed)
            if animate, window < 0.6 {
                p.hopY = -14 * CGFloat(sin(.pi * window / 0.6))
            }

        case .done:
            p.happyEyes = true
            p.mouthCurve = 0.95
            p.armAngleL = -48
            p.armAngleR = -48
            p.bubble = "✓"
            // Short celebration: three decaying hops (~1.3 s), then still.
            if animate, elapsed < Attention.doneCelebration {
                let cycle = 0.42
                let n = floor(elapsed / cycle)
                let amp: CGFloat = n < 3 ? 16 * pow(0.72, CGFloat(n)) : 0
                let ph = elapsed.truncatingRemainder(dividingBy: cycle) / cycle
                p.hopY = -amp * CGFloat(sin(.pi * ph))
                p.tailAngle = 18 * sin(2 * .pi * t / 0.6)
            }
        }

        // One-shot reaction to the user (hover / click / popover / rename): wave the
        // right paw, glance over, then settle back to the still pose.
        if animate, let r = reaction, r < Attention.reaction, state != .asking, state != .done {
            let ease = sin(.pi * r / Attention.reaction)
            p.armAngleR = -60 * ease + 12 * sin(2 * .pi * r / 0.35) * ease
            p.eyeLookX = 1.5 * CGFloat(ease)
            p.mouthCurve = max(p.mouthCurve, 0.5 * ease)
        }
        return p
    }
}

/// Plain reference box, not itself observed — see MascotView.freeze.
private final class PoseFreeze {
    var pose: Pose?
    var frame: PixelFrame?
}

// MARK: - View

struct MascotView: View {
    @ObservedObject var store: SessionStore
    @State private var stateEnteredAt = Date()
    /// The state we came from — the Pixel style scatters the old sprite into the new one.
    @State private var previousState: MascotDisplayState = .none
    /// Last user interaction (hover / click / popover / rename) → one-shot reaction.
    @State private var reactedAt: Date?

    /// Holds the character's pose still while a resize is in progress (see
    /// MascotSettings.isResizingMascot). A plain class, not @State: this is a
    /// cache mutated during body evaluation, not something that should itself
    /// trigger a re-render — TimelineView's own 30fps tick already does that.
    @State private var freeze = PoseFreeze()

    var body: some View {
        // 30fps is plenty for this character and costs half of a display-linked
        // schedule — this app runs all day.
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let elapsed = ctx.date.timeIntervalSince(stateEnteredAt)
            let motion = MotionPreference.level
            let reaction = reactedAt.map { ctx.date.timeIntervalSince($0) }
            switch MascotSettings.style {
            case .classic:
                let livePose = Pose.make(state: store.displayState, t: t, elapsed: elapsed,
                                         motion: motion, reaction: reaction)
                let pose = resolvedPose(live: livePose)

                // Read fresh every tick, same pattern as the badge counts — the character
                // is drawn once at its fixed base size and scaled as a whole here, so
                // resizing never has to touch Rig's own geometry.
                CharacterView(
                    pose: pose,
                    count: store.sessions.count,
                    doneCount: store.doneBadgeCount,
                    askingCount: store.askingBadgeCount
                )
                .scaleEffect(MascotSettings.scale)

            case .pixel:
                // Pixel art is drawn at its real cell size (snapped to half points)
                // instead of being scaled as a whole, so the squares stay crisp.
                let liveFrame = PixelFrame.make(
                    state: store.displayState,
                    previous: previousState,
                    t: t,
                    elapsed: elapsed,
                    motion: motion,
                    reaction: reaction
                )
                PixelCharacterView(
                    frame: resolvedFrame(live: liveFrame),
                    count: store.sessions.count,
                    doneCount: store.doneBadgeCount,
                    askingCount: store.askingBadgeCount,
                    scale: MascotSettings.scale
                )
            }
        }
        // Fills whatever size MascotPanel currently is (it resizes the real window
        // to match the scale), rather than a fixed size — the scaled content is
        // centered in it automatically since scaleEffect scales around its own centre.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { inside in
            if inside { reactedAt = Date() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .monkeyMascotReact)) { _ in
            reactedAt = Date()
        }
        .onChange(of: store.displayState) { old, _ in
            // Reset the clock so hops always start from the ground.
            previousState = old
            stateEnteredAt = Date()
        }
    }

    /// Resizing and animating at the same time reads as janky — hold the last
    /// live pose steady for the whole gesture, then resume normally the instant
    /// it ends. Plain function rather than inline `if/else` in the TimelineView
    /// closure: that confused @ViewBuilder's control-flow rewriting since the
    /// branches don't produce View content.
    private func resolvedPose(live: Pose) -> Pose {
        guard MascotSettings.isResizingMascot else {
            freeze.pose = nil
            return live
        }
        if freeze.pose == nil { freeze.pose = live }
        return freeze.pose!
    }

    /// Same hold-still-while-resizing rule for the Pixel style.
    private func resolvedFrame(live: PixelFrame) -> PixelFrame {
        guard MascotSettings.isResizingMascot else {
            freeze.frame = nil
            return live
        }
        if freeze.frame == nil { freeze.frame = live }
        return freeze.frame!
    }
}

private struct CharacterView: View {
    let pose: Pose
    let count: Int
    let doneCount: Int
    let askingCount: Int

    var body: some View {
        let topLeftX = -(Rig.bodyW / 2 - 1)
        let topY = -(Rig.bodyH / 2) - 1

        ZStack {
            if let bubble = pose.bubble {
                BubbleView(symbol: bubble, tint: pose.phosphor)
                    .offset(y: -(Rig.bodyH / 2 + 30))
            }

            ZStack {
                // State aura: soft glow behind the whole character.
                Ellipse()
                    .fill(pose.phosphor.opacity(0.55 * pose.halo))
                    .frame(width: Rig.bodyW + 10, height: Rig.bodyH + 16)
                    .blur(radius: 12)
                    .offset(y: 4)
                TailView(pose: pose)
                LegsView(pose: pose)
                TorsoView()
                ArmsView(pose: pose)
                HeadView(pose: pose)

                if count >= 2 {
                    CountBadgeView(count: count, color: .accentColor)
                        .offset(x: -topLeftX, y: topY)
                }
                if askingCount >= 1 {
                    CountBadgeView(count: askingCount, color: Rig.askingColor)
                        .offset(x: topLeftX, y: topY)
                }
                if doneCount >= 1 {
                    CountBadgeView(count: doneCount, color: Rig.doneColor)
                        .offset(x: topLeftX + (askingCount >= 1 ? Rig.badgeGap : 0), y: topY)
                }
            }
            .scaleEffect(x: 1, y: pose.breathe, anchor: .bottom)
            .offset(y: pose.hopY + pose.bobY)
        }
        .frame(width: kBasePanelSize.width, height: kBasePanelSize.height)
        .shadow(color: .black.opacity(0.28), radius: 6, y: 3)
    }
}

// MARK: - Head (ears, skull, face mask, eyes, mouth)

private struct HeadView: View {
    let pose: Pose

    var body: some View {
        ZStack {
            ForEach([-1.0, 1.0], id: \.self) { s in
                ZStack {
                    Circle().fill(Rig.fur)
                    Circle().fill(Rig.mask).padding(3.5)
                    Circle().strokeBorder(Rig.stroke, lineWidth: Rig.outline)
                }
                .frame(width: Rig.earR * 2, height: Rig.earR * 2)
                .offset(x: CGFloat(s) * Rig.earX, y: Rig.earY)
            }

            RoundedRectangle(cornerRadius: 13)
                .fill(Rig.fur)
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Rig.stroke, lineWidth: Rig.outline))
                .frame(width: Rig.headSize.width, height: Rig.headSize.height)
                .offset(y: Rig.headY)

            // Face mask: two brow lobes merged with a muzzle, like the logo.
            ZStack {
                HStack(spacing: -4) {
                    RoundedRectangle(cornerRadius: 7).frame(width: 18, height: 15)
                    RoundedRectangle(cornerRadius: 7).frame(width: 18, height: 15)
                }
                .offset(y: -5)
                RoundedRectangle(cornerRadius: 8).frame(width: 26, height: 15).offset(y: 5)
            }
            .foregroundStyle(Rig.mask)
            .frame(width: Rig.maskSize.width, height: Rig.maskSize.height)
            .offset(y: Rig.maskY)

            FaceView(pose: pose)
        }
    }
}

private struct FaceView: View {
    let pose: Pose

    var body: some View {
        ZStack {
            HStack(spacing: Rig.eyeGap * 2 - Rig.eyeR * 2) { eye; eye }
                .offset(x: pose.eyeLookX, y: Rig.eyeY)

            Group {
                if pose.mouthOpen {
                    Ellipse().fill(Rig.stroke).frame(width: 5, height: 6)
                } else {
                    MouthShape(curve: pose.mouthCurve)
                        .stroke(Rig.stroke, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        .frame(width: Rig.mouthW, height: 6)
                }
            }
            .offset(y: Rig.mouthY)
        }
    }

    @ViewBuilder private var eye: some View {
        if pose.happyEyes {
            HappyEyeShape()
                .stroke(pose.phosphor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: Rig.eyeR * 2.2, height: Rig.eyeR * 1.3)
                .shadow(color: pose.phosphor.opacity(pose.glow), radius: 3)
        } else {
            RoundedRectangle(cornerRadius: 1)
                .fill(pose.phosphor.opacity(0.55 + 0.45 * pose.glow))
                .frame(width: Rig.eyeR * 2, height: Rig.eyeR * 2)
                .scaleEffect(x: pose.eyeScale, y: pose.eyeOpen * pose.eyeScale)
                .shadow(color: pose.phosphor.opacity(pose.glow), radius: 3)
        }
    }
}

private struct MouthShape: Shape {
    let curve: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY),
                       control: CGPoint(x: r.midX, y: r.midY + curve * 6))
        return p
    }
}

private struct HappyEyeShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                       control: CGPoint(x: r.midX, y: r.minY - r.height * 0.6))
        return p
    }
}

// MARK: - Torso, tail, limbs

private struct TorsoView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Rig.fur)
            RoundedRectangle(cornerRadius: 5).fill(Rig.mask)
                .frame(width: Rig.torsoSize.width * 0.5, height: Rig.torsoSize.height * 0.75)
            RoundedRectangle(cornerRadius: 8).strokeBorder(Rig.stroke, lineWidth: Rig.outline)
        }
        .frame(width: Rig.torsoSize.width, height: Rig.torsoSize.height)
        .offset(y: Rig.torsoY)
    }
}

/// Hooked tail rising from the right hip, swaying around its base.
private struct TailView: View {
    let pose: Pose

    var body: some View {
        TailShape(base: Rig.tailBase, curl: pose.tailCurl)
            .stroke(Rig.fur, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .background(
                TailShape(base: Rig.tailBase, curl: pose.tailCurl)
                    .stroke(Rig.stroke, style: StrokeStyle(lineWidth: 6.4, lineCap: .round, lineJoin: .round))
            )
            .rotationEffect(.degrees(pose.tailAngle),
                            anchor: UnitPoint(x: 0.5 + Rig.tailBase.x / kBasePanelSize.width,
                                              y: 0.5 + Rig.tailBase.y / kBasePanelSize.height))
            .frame(width: kBasePanelSize.width, height: kBasePanelSize.height)
    }
}

private struct TailShape: Shape {
    let base: CGPoint
    let curl: CGFloat
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX + base.x, y: r.midY + base.y)
        var p = Path()
        p.move(to: c)
        p.addQuadCurve(to: CGPoint(x: c.x + 22, y: c.y - 4),
                       control: CGPoint(x: c.x + 16, y: c.y + 6))
        p.addQuadCurve(to: CGPoint(x: c.x + 24, y: c.y - 34),
                       control: CGPoint(x: c.x + 28, y: c.y - 16))
        // The hook at the tip.
        p.addQuadCurve(to: CGPoint(x: c.x + 24 + 9 * curl, y: c.y - 30 + 2 * curl),
                       control: CGPoint(x: c.x + 30 + 2 * curl, y: c.y - 44))
        return p
    }
}

private struct ArmsView: View {
    let pose: Pose

    var body: some View {
        ZStack {
            arm(left: true, angle: pose.armAngleL, tap: pose.pawTapL)
            arm(left: false, angle: pose.armAngleR, tap: pose.pawTapR)
        }
    }

    private func arm(left: Bool, angle: Double, tap: CGFloat) -> some View {
        let sign: CGFloat = left ? -1 : 1
        let shoulder = CGPoint(x: sign * (Rig.torsoSize.width / 2 - 1), y: Rig.torsoY - 8)
        let elbow = CGPoint(x: shoulder.x + sign * Rig.armSeg1.width, y: shoulder.y + Rig.armSeg1.height)
        let hand = CGPoint(x: elbow.x + sign * Rig.armSeg2.width, y: elbow.y + Rig.armSeg2.height - tap)
        let deg = left ? -angle : angle
        let e = rotate(elbow, around: shoulder, degrees: deg)
        let h = rotate(hand, around: shoulder, degrees: deg)

        return ZStack {
            LimbShape(points: [shoulder, e, h])
                .stroke(Rig.stroke, style: StrokeStyle(lineWidth: Rig.armW + 2.4, lineCap: .round, lineJoin: .round))
            LimbShape(points: [shoulder, e, h])
                .stroke(Rig.fur, style: StrokeStyle(lineWidth: Rig.armW, lineCap: .round, lineJoin: .round))
            // Paw
            LimbShape(points: [h, h])
                .stroke(Rig.mask, style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }
        .frame(width: kBasePanelSize.width, height: kBasePanelSize.height)
    }
}

private struct LegsView: View {
    let pose: Pose

    var body: some View {
        let tuck = min(1, abs(pose.hopY) / 16) * 3
        let len = Rig.legLen - tuck

        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { sign in
                let x = CGFloat(sign) * Rig.legSpread
                let top = CGPoint(x: x, y: Rig.torsoY + Rig.torsoSize.height / 2 - 3)
                let bottom = CGPoint(x: x, y: top.y + len)
                ZStack {
                    LimbShape(points: [top, bottom])
                        .stroke(Rig.stroke, style: StrokeStyle(lineWidth: Rig.legW + 2.4, lineCap: .round))
                    LimbShape(points: [top, bottom])
                        .stroke(Rig.fur, style: StrokeStyle(lineWidth: Rig.legW, lineCap: .round))
                    LimbShape(points: [
                        CGPoint(x: x + CGFloat(sign) * -1, y: bottom.y + 1),
                        CGPoint(x: x + CGFloat(sign) * (Rig.footW - 4), y: bottom.y + 1)
                    ])
                    .stroke(Rig.mask, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
                .frame(width: kBasePanelSize.width, height: kBasePanelSize.height)
            }
        }
    }
}

/// Draws a polyline in centre-origin coordinates, so the rig constants above can be
/// written relative to the middle of the character rather than a corner.
private struct LimbShape: Shape {
    let points: [CGPoint]
    func path(in r: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        let c = CGPoint(x: r.midX, y: r.midY)
        p.move(to: CGPoint(x: c.x + first.x, y: c.y + first.y))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: c.x + pt.x, y: c.y + pt.y))
        }
        return p
    }
}

private func rotate(_ p: CGPoint, around o: CGPoint, degrees: Double) -> CGPoint {
    let r = degrees * .pi / 180
    let dx = p.x - o.x, dy = p.y - o.y
    return CGPoint(
        x: o.x + dx * CGFloat(cos(r)) - dy * CGFloat(sin(r)),
        y: o.y + dx * CGFloat(sin(r)) + dy * CGFloat(cos(r))
    )
}

// MARK: - Bubble & badge

private struct BubbleView: View {
    let symbol: String
    let tint: Color

    var body: some View {
        ZStack {
            Capsule().fill(Rig.shell)
            Capsule().strokeBorder(Rig.stroke, lineWidth: 1.4)
            Text(symbol)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(width: 26, height: 24)
    }
}

private struct CountBadgeView: View {
    let count: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle().fill(color)
            Circle().strokeBorder(Rig.stroke, lineWidth: 1.2)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 17, height: 17)
    }
}
