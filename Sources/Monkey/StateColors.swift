import SwiftUI
import AppKit

// MARK: - State colour system
//
// One palette for everything that signals *state* by colour: the eyes, the halo/aura
// around the mascot (Classic: soft glow · Pixel: lit 1px outline) and the menu-bar
// pawprint. Fur keeps the logo colours; poses and glyphs stay the non-colour signal.
// Intensity is a pure function of (state, time) — stepped where it needs to be — so
// both styles and the menu bar animate in sync and nothing can get stuck.

enum StateColors {
    static let idle    = Color(red: 0.13, green: 1.0,  blue: 0.25)   // #21FF40 neon green (dimmed)
    static let working = Color(red: 0.23, green: 0.78, blue: 1.0)    // #3BC7FF cyan
    static let asking  = Rig.askingColor                              // same orange as the asking badge
    static let done    = Rig.doneColor                                // same green as the done badge
    static let stale   = Color(red: 0.55, green: 0.57, blue: 0.62)   // grey, process presumed dead/interrupted

    static func tint(for state: MascotDisplayState) -> Color {
        switch state {
        case .none, .idle: return idle
        case .working:     return working
        case .asking:      return asking
        case .done:        return done
        case .stale:       return stale
        }
    }

    /// 0…1 brightness of the state signal at time `t` (seconds). `elapsed` is time
    /// since the state was entered. Motion policy (see MotionLevel): `.none` and
    /// `.minimal` are static for idle/working; asking blinks only during its
    /// attention window, done sparkles only during its short celebration.
    /// `stepped` quantises to the Pixel style's frame rate so it never looks tweened.
    static func intensity(for state: MascotDisplayState, t: Double, elapsed: Double,
                          motion: MotionLevel, stepped: Bool = false) -> Double {
        let time = stepped ? floor(t * PixelRig.fps) / PixelRig.fps : t
        let steady: Double = {
            switch state {
            case .none, .idle: return 0.35
            case .working:     return 0.7
            case .asking:      return 1.0
            case .done:        return 0.8
            case .stale:       return 0.2
            }
        }()
        switch motion {
        case .none:
            return steady
        case .minimal:
            switch state {
            case .asking where Attention.askingWindow(elapsed) < Attention.askingBlinkFor:
                return time.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1.0 : 0.35
            case .done where elapsed < Attention.doneCelebration:
                return 0.6 + 0.4 * (0.5 + 0.5 * sin(2 * .pi * time / 0.3))
            default:
                return steady
            }
        case .lively:
            switch state {
            case .none, .idle:
                return 0.25 + 0.15 * (0.5 + 0.5 * sin(2 * .pi * time / 4.0))
            case .working:
                let period = stepped ? 0.333 : 0.6   // synced to the typing cadence
                return 0.5 + 0.4 * (0.5 + 0.5 * sin(2 * .pi * time / period))
            case .asking:
                return time.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1.0 : 0.35
            case .done:
                let decay = max(0, 1 - elapsed / 4.0)
                return 0.6 + 0.4 * (0.5 + 0.5 * sin(2 * .pi * time / 0.3)) * decay
            case .stale:
                return 0.2
            }
        }
    }

    static func nsColor(for state: MascotDisplayState) -> NSColor {
        NSColor(tint(for: state))
    }
}

// MARK: - Motion policy

/// How much the mascot is allowed to move. Default is minimal: still poses, motion
/// only on events (needs you / finished / you interacted). Lively restores the
/// continuous idle/working animations. Reduce Motion (macOS) forces `.none`.
enum MotionMode: String, CaseIterable {
    case minimal
    case lively

    var label: String {
        switch self {
        case .minimal: return "Minimal (still, moves on events)"
        case .lively:  return "Lively (continuous idle/working animation)"
        }
    }
}

enum MotionLevel {
    case none       // Reduce Motion: nothing moves, static colours
    case minimal    // event-only motion
    case lively     // continuous
}

/// macOS "Reduce Motion" + the user's Motion preference, resolved every tick (cheap),
/// so toggling either takes effect immediately.
enum MotionPreference {
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static var level: MotionLevel {
        if reduceMotion { return .none }
        return MascotSettings.motion == .lively ? .lively : .minimal
    }
}

/// Event-motion timing shared by both styles.
enum Attention {
    /// Asking: one jump on entry, then a single nudge at most every `askingNudgeEvery`.
    static let askingNudgeEvery = 30.0
    static let askingJump = 1.0          // seconds the jump lasts
    static let askingBlinkFor = 3.0      // eyes/halo blink only this long per window
    /// Done: one short celebration, then still.
    static let doneCelebration = 1.5
    /// User interaction (hover/click/popover/rename): one small reaction.
    static let reaction = 0.8

    /// Seconds into the current asking window (0 = a jump just started).
    static func askingWindow(_ elapsed: Double) -> Double {
        elapsed.truncatingRemainder(dividingBy: askingNudgeEvery)
    }

    /// Occasional blink: once per 6–10s at a pseudo-random moment, `window` seconds long.
    static func blinking(t: Double, window: Double = 0.12) -> Bool {
        let seg = 8.0
        let k = floor(t / seg)
        var h = UInt32(truncatingIfNeeded: Int(k) &* 2654435761)
        h ^= h >> 15; h = h &* 2246822519; h ^= h >> 13
        let offset = 1.0 + 6.0 * Double(h % 1000) / 1000     // 1…7 s into the 8 s segment
        let local = t - k * seg - offset
        return local >= 0 && local < window
    }
}
