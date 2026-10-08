#!/bin/bash
# install.sh — one-shot setup: registers Monkey's hooks with Claude Code, then
# builds and installs the app.
#
# Safe to re-run any time (e.g. after `git pull`) — every step here is idempotent.
#
#   ./install.sh          hooks + build + install to /Applications
#   ./install.sh --dock   same, and pin Monkey.app in the Dock (once; checks first)

set -euo pipefail
cd "$(dirname "$0")"
REPO_DIR="$(pwd)"
PIN_DOCK=false
for arg in "$@"; do
  case "$arg" in
    --dock) PIN_DOCK=true ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

echo "==> checking dependencies"
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not found." >&2
  echo "Install it with: brew install jq" >&2
  echo "(if you don't have Homebrew: https://brew.sh)" >&2
  exit 1
fi
if ! command -v swift >/dev/null 2>&1; then
  echo "Swift is required but not found." >&2
  echo "Install the Xcode Command Line Tools with: xcode-select --install" >&2
  exit 1
fi

# --- 1. Install the hook script somewhere stable -----------------------------
#
# Deliberately NOT the repo's own hooks/ directory: settings.json will point at
# this path, so if it pointed at the repo directly, moving or deleting the repo
# after install would silently break every hook. Copying it into ~/.claude/monkey
# decouples the two — the repo can move or be deleted once this step is done.

HOOK_DIR="$HOME/.claude/monkey/hooks"
HOOK_SCRIPT="$HOOK_DIR/monkey-state.sh"

echo "==> installing hook script"
mkdir -p "$HOOK_DIR"
cp "$REPO_DIR/hooks/monkey-state.sh" "$HOOK_SCRIPT"
chmod +x "$HOOK_SCRIPT"

# --- 2. Register hooks in ~/.claude/settings.json -----------------------------
#
# Merged in, not overwritten: your settings.json may already have other hooks
# (yours or another tool's) registered on these same events, especially
# PostToolUse/PreToolUse which are common. Each event below keeps every existing
# entry that isn't one of Monkey's own (matched by the hook script's path), then
# adds Monkey's fresh entry — so this is safe to run once, twice, or after an
# upgrade, and never touches anything that isn't Monkey's.

SETTINGS="$HOME/.claude/settings.json"
echo "==> registering hooks in $SETTINGS"

mkdir -p "$(dirname "$SETTINGS")"
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi
cp "$SETTINGS" "$SETTINGS.monkey-backup"

TMP="$(mktemp)"
jq \
  --arg hook "$HOOK_SCRIPT" \
  '
  def entry(state): {"hooks": [{"type": "command", "command": ($hook + " " + state)}]};
  def entryMatcher(matcher; state): {"matcher": matcher, "hooks": [{"type": "command", "command": ($hook + " " + state)}]};
  # Match on the script basename, not the full path: an install from before
  # this script existed (or a previous checkout at a different location) would
  # have registered monkey-state.sh under a different path, and a full-path match
  # would fail to recognize it as "ours" -- leaving a stale duplicate hook running
  # alongside the fresh one instead of replacing it.
  def isOurs: (.hooks[0].command // "") | contains("monkey-state.sh");
  def replaceEvent(name; newEntry):
    (.hooks[name] // []) as $existing
    | ($existing | map(select(isOurs | not))) as $kept
    | .hooks[name] = ($kept + [newEntry]);

  .hooks = (.hooks // {})
  | replaceEvent("SessionStart"; entry("idle"))
  | replaceEvent("UserPromptSubmit"; entry("working"))
  | replaceEvent("PreToolUse"; entryMatcher("AskUserQuestion"; "asking"))
  | replaceEvent("PostToolUse"; entryMatcher("*"; "working"))
  | replaceEvent("Notification"; entry("notify"))
  | replaceEvent("Stop"; entry("done"))
  | replaceEvent("SessionEnd"; entry("end"))
  ' \
  "$SETTINGS" > "$TMP"

if jq empty "$TMP" 2>/dev/null; then
  mv "$TMP" "$SETTINGS"
  echo "    done (backup at $SETTINGS.monkey-backup)"
else
  echo "    FAILED to produce valid JSON — leaving $SETTINGS untouched." >&2
  echo "    See $TMP for what went wrong." >&2
  exit 1
fi

# --- 3. Build and install the app --------------------------------------------

echo "==> building and installing Monkey.app"
"$REPO_DIR/make-app.sh"
APP_PATH="${MONKEY_APP_DIR:-/Applications}/Monkey.app"

# --- 4. Optional: pin in the Dock -------------------------------------------
#
# Opt-in (--dock). Adds a persistent-apps tile only if none points at the app
# already, then restarts the Dock so it shows up.

if $PIN_DOCK; then
  echo "==> pinning in the Dock"
  if defaults read com.apple.dock persistent-apps 2>/dev/null | grep -q "$APP_PATH"; then
    echo "    already pinned"
  else
    defaults write com.apple.dock persistent-apps -array-add \
      "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$APP_PATH/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>"
    killall Dock
    echo "    pinned"
  fi
fi

echo
echo "Setup complete."
echo "  - New Claude Code sessions will be tracked automatically."
echo "  - Sessions already running won't be tracked until restarted."
echo "  - Open Monkey from /Applications, or: open -a \"$APP_PATH\""
