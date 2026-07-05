#!/usr/bin/env bash
# setup-squish.sh — pre-wire Squish (https://getsquish.app) into this Hermes install.
#
# Fork add-on (v1b3x0r/hermes-agent-plus), deliberately separate from upstream's
# setup-hermes.sh so upstream syncs stay clean. Idempotent: safe to re-run any time.
#
# What it does:
#   1. Installs the `squish-video` skill into ~/.hermes/skills/media/squish-video/ — always.
#   2. If a local Squish engine is available (repo + node + ffmpeg), wires the `squish` MCP
#      server into ~/.hermes/config.yaml. Without one, the skill still works out of the box
#      via the hosted API (free daily allowance for never-paid accounts — no card needed).
#
# Env overrides: HERMES_HOME (default ~/.hermes) · SQUISH_REPO (default ~/_dev/squish)
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
SQUISH_REPO="${SQUISH_REPO:-$HOME/_dev/squish}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 1) The skill — always installed. Prefer the live copy from a local squish checkout
#     (fresher than this fork's snapshot); fall back to the vendored one.
LIVE_SKILL="$SQUISH_REPO/docs/integrations/hermes/skills/media/squish-video/SKILL.md"
SKILL_SRC="$SCRIPT_DIR/squish-integration/SKILL.md"
[ -f "$LIVE_SKILL" ] && SKILL_SRC="$LIVE_SKILL"

mkdir -p "$HERMES_HOME/skills/media/squish-video"
cp "$SKILL_SRC" "$HERMES_HOME/skills/media/squish-video/SKILL.md"
echo "✓ skill installed → $HERMES_HOME/skills/media/squish-video/SKILL.md"
echo "  source: $SKILL_SRC"

hosted_mode() {
  cat <<EOF

✓ Setup complete — hosted mode.
  $1
  The squish-video skill works out of the box through the hosted API:
    1. Sign in at https://getsquish.app/api-keys (email OTP) and create a key.
       Accounts that have never purchased get a FREE daily allowance, applied
       automatically on the first request — no card needed.
    2. export SQUISH_API_KEY=sq_live_...
  The local engine ships with the @getsquish npm release — re-run this script after
  installing it and everything below happens automatically.
EOF
  exit 0
}

# --- 2) Local engine detection — every miss is hosted mode, not a failure.
[ -d "$SQUISH_REPO/cli" ] || hosted_mode "No local Squish engine at: $SQUISH_REPO (override with SQUISH_REPO=...)."
command -v node >/dev/null 2>&1 || hosted_mode "Found $SQUISH_REPO but 'node' is not on PATH (need Node >= 20)."
command -v ffmpeg >/dev/null 2>&1 || hosted_mode "Found $SQUISH_REPO but 'ffmpeg' is not on PATH (brew install ffmpeg)."

if [ ! -d "$SQUISH_REPO/cli/node_modules" ]; then
  echo "· installing squish cli deps (first run)..."
  npm --prefix "$SQUISH_REPO/cli" install --silent
fi

# --- 3) Wire the MCP server. Config-edit policy: user configs carry comments, so this script
#     NEVER rewrites existing YAML structure — it appends a whole block when mcp_servers: is
#     absent, and otherwise tells you exactly what to paste.
CONFIG="$HERMES_HOME/config.yaml"
mkdir -p "$HERMES_HOME"
touch "$CONFIG"

SQUISH_BLOCK="mcp_servers:
  squish:
    command: npm
    args:
      - --prefix
      - $SQUISH_REPO/cli
      - run
      - --silent
      - mcp
    env: {}"

if grep -qE '^[[:space:]]+squish:' "$CONFIG"; then
  echo "✓ mcp_servers.squish already configured — left untouched"
elif grep -qE '^mcp_servers:' "$CONFIG"; then
  cat <<EOF

! Your config already has an mcp_servers: section — paste this under it (this script never
  edits existing YAML structure):

$(printf '%s\n' "$SQUISH_BLOCK" | tail -n +2)
EOF
else
  cp "$CONFIG" "$CONFIG.bak.squish"
  { echo ""; echo "# Squish MCP server — added by setup-squish.sh ($(date +%Y-%m-%d))"; printf '%s\n' "$SQUISH_BLOCK"; } >> "$CONFIG"
  echo "✓ mcp_servers.squish added to $CONFIG (backup: $CONFIG.bak.squish)"
fi

cat <<'EOF'

Done. Verify the wiring:
  hermes mcp test squish        # expect: Connected + tool squish_video
Then try it:
  hermes chat -q "What happens in this video? /path/to/clip.mov" -Q
EOF
