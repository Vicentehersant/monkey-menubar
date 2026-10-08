# Monkey state contract (v1 — identical to Termi's schema)

Producer: `hooks/monkey-state.sh <state>` (installed to `~/.claude/monkey/hooks/`), invoked by
Claude Code hooks with the hook JSON payload on stdin. Consumers: Monkey.app (FSEvents) and,
later, the Monkey OS console. Consumers must treat files as read-only.

## Location
`~/.claude/monkey/sessions/<session_id>.json` — one file per live session.
Override for dev/tests: env `MONKEY_DIR=<dir>` (app side; disables process discovery).

## Fields
| field | type | meaning |
|---|---|---|
| `session_id` | string | Claude Code session id (also the filename) |
| `cwd` | string | session working dir (UI label = last path component) |
| `state` | string | `idle` \| `working` \| `asking` \| `done` |
| `ppid` | int | PID of the hook's parent (the `claude` process) — liveness check |
| `ts` | int | unix seconds of last write (heartbeat) |
| `pendingBackground` | bool | `working` is a known wait on a `run_in_background` shell; don't apply stale timeout |

Example: `{"session_id":"abc","cwd":"/Users/v/proj","state":"working","ppid":4242,"ts":1791136397,"pendingBackground":false}`

## Hook → state mapping (install.sh)
| hook event | arg | resulting state |
|---|---|---|
| SessionStart | `idle` | idle |
| UserPromptSubmit | `working` | working |
| PreToolUse (matcher `AskUserQuestion`) | `asking` | asking |
| PostToolUse (`*`) | `working` | working |
| Notification | `notify` | asking only if `notification_type == "permission_prompt"`, else no write |
| Stop | `done` | done — or `working` + `pendingBackground:true` if last inbound transcript entry is an unresolved background-shell ack |
| SessionEnd | `end` | file deleted |

## Lifecycle
1. Created on first hook of a session; overwritten (atomic `tmp` + `mv`) on every hook.
2. Deleted on `SessionEnd`. **Absence = no session.** Zero files = "no-sessions" display state.
3. App-side pruning (not in file): dead `ppid` → session dropped; `working` with no heartbeat
   for `Tuning.staleWorkingTimeout` and `pendingBackground=false` → treated as interrupted
   (Esc fires no hook); very old files ignored.
4. Hook always exits 0, never blocks a session; needs only bash + jq.

## Display aggregation (app)
Top display state priority: asking > done > working > idle > none. `asking`/`done` poses decay
to idle after a short celebration; the orange (asking) and green (done, unseen) badges persist
until answered / the session's terminal is focused. Badge counts are app-memory, not on disk.

## Companion files (optional, app-owned — not part of the hook schema)
- `~/.claude/monkey/limits.json` — usage %, written by the statusline wrapper.
- `~/.claude/monkey/names.json` — custom session names set in Monkey.app's popover.
  Shape: `{ "<session_id>": { "name": "…", "cwd": "…", "ts": <unix seconds> } }`.
  Written atomically by the app; read by the app at launch and by the Monkey OS console
  (read-only). Entries whose session no longer exists are pruned after 7 days. Display
  name resolution: custom name → Claude Code `/rename` title (`custom-title` entry in
  `~/.claude/projects/<cwd sanitized>/<session_id>.jsonl`) → cwd basename.
