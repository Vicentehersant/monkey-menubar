import Foundation
import Combine

/// User-editable session names, plus Claude Code's own `/rename` titles.
///
/// Display name resolution, in order: custom name (set in the popover) → the
/// session's `custom-title` entry in its Claude Code transcript → cwd basename.
///
/// Custom names live in `names.json` next to the sessions dir (see STATE-CONTRACT.md,
/// "Companion files") so the Monkey OS console can read them later. The hook script
/// and the per-session JSON schema are untouched — this file is app-owned.
final class SessionNames: ObservableObject {

    static let shared = SessionNames()

    /// Bumped on every change so SwiftUI rows re-read names.
    @Published private(set) var revision = 0

    /// `~/.claude/monkey/names.json` (or `<MONKEY_DIR>/../names.json` in dev).
    static var fileURL: URL {
        SessionStore.directory.deletingLastPathComponent().appendingPathComponent("names.json")
    }

    /// Entries for sessions that no longer exist are dropped after this long.
    static let pruneAfter: TimeInterval = 7 * 24 * 60 * 60

    private struct Entry: Codable {
        var name: String
        var cwd: String
        var ts: TimeInterval
    }

    private var entries: [String: Entry] = [:]

    /// Incremental transcript scan state: bytes already read + last title found.
    private struct TranscriptScan {
        var offset: UInt64 = 0
        var title: String?
        var missingChecks = 0
    }
    private var scans: [String: TranscriptScan] = [:]

    private init() { load() }

    // MARK: - Public

    func displayName(for session: Session) -> String {
        if let custom = customName(for: session.id) { return custom }
        if let title = transcriptTitle(for: session) { return title }
        return session.folder
    }

    func customName(for id: String) -> String? {
        entries[id]?.name
    }

    /// Empty / whitespace-only name removes the override (back to the default).
    func setCustomName(_ name: String?, for session: Session) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            entries.removeValue(forKey: session.id)
        } else {
            entries[session.id] = Entry(name: trimmed, cwd: session.cwd, ts: Date().timeIntervalSince1970)
        }
        save()
        revision += 1
    }

    /// Called on every reload with the live session ids: refreshes `ts` of live
    /// entries and drops names of sessions gone for longer than `pruneAfter`.
    func sync(live sessions: [Session]) {
        let now = Date().timeIntervalSince1970
        let liveIDs = Set(sessions.map(\.id))
        var changed = false
        for (id, var e) in entries {
            if liveIDs.contains(id) {
                if now - e.ts > 3600 { e.ts = now; entries[id] = e; changed = true }
            } else if now - e.ts > Self.pruneAfter {
                entries.removeValue(forKey: id); changed = true
            }
        }
        scans = scans.filter { liveIDs.contains($0.key) }
        var titlesChanged = false
        for s in sessions { if scanTranscript(for: s) { titlesChanged = true } }
        if changed { save() }
        if changed || titlesChanged { revision += 1 }
    }

    // MARK: - Transcript titles (`/rename` in Claude Code)

    /// `~/.claude/projects/<cwd with every non-alphanumeric → "-">/<session_id>.jsonl`
    static func transcriptURL(for session: Session) -> URL {
        let sanitized = session.cwd.map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
            .appendingPathComponent(sanitized)
            .appendingPathComponent("\(session.id).jsonl")
    }

    private func transcriptTitle(for session: Session) -> String? {
        scans[session.id]?.title
    }

    /// Reads only the bytes appended since the last scan, so a long-running session
    /// with a multi-MB transcript costs nothing per reload. Returns true if the
    /// title changed. Looks for `{"type":"custom-title","customTitle":"…"}` lines.
    @discardableResult
    private func scanTranscript(for session: Session) -> Bool {
        var scan = scans[session.id] ?? TranscriptScan()
        // Fake/demo sessions have no transcript; stop probing after a few misses.
        if scan.missingChecks >= 3 { return false }
        let url = Self.transcriptURL(for: session)
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            scan.missingChecks += 1
            scans[session.id] = scan
            return false
        }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd(), end > scan.offset else { return false }
        try? handle.seek(toOffset: scan.offset)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return false }
        scan.offset = end

        var found: String?
        for line in text.split(separator: "\n") where line.contains("\"custom-title\"") {
            if let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
               obj["type"] as? String == "custom-title",
               let title = obj["customTitle"] as? String {
                let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                found = t.isEmpty ? nil : t
            }
        }
        let changed = found != nil && found != scan.title
        if let found { scan.title = found }
        scans[session.id] = scan
        return changed
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        let url = Self.fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(entries) else { return }
        // Atomic, same as the hook script's tmp + mv.
        try? data.write(to: url, options: .atomic)
    }
}
