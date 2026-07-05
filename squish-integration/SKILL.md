---
name: squish-video
description: See what happens in a local video via timestamped frames. Turns video into contact sheets you can vision_analyze — use for "what happens in this clip", finding a moment, or citing timecodes.
---

<!-- VENDORED SNAPSHOT (2026-07-06) — canonical lives in the squish-app repo at
     docs/integrations/hermes/skills/media/squish-video/SKILL.md. setup-squish.sh prefers the
     live copy from a local squish checkout; this snapshot serves machines without one. -->

<!-- Deliberately NOT gated on requires_toolsets ["mcp-squish"]: the hosted-API fallback below
     must be reachable exactly when the local MCP is absent or failed to connect — a gated skill
     vanishes in that scenario together with the tool (Codex P2, PR #24). Installing this skill
     is the opt-in; the body branches on tool availability. -->

# Squish: video → timestamped contact sheet → your eyes

You have vision but cannot ingest video. When a user asks about a **local video file**, do not
guess and do not refuse — compress it into **timestamped contact sheets** (one image per window
of the clip, frames sampled evenly, each cell stamped with its timecode) and read those.

The reasoning primitive: **video → contact sheet → look at the grid → answer with timestamps.**

## When to use

- "What happens in this video / screen recording?" — and the file is on this machine.
- The question spans time: before/after, a scene change, progress, "find the moment when…".
- The answer needs precise citations ("at 0:07 the press comes down").

Skip it when the user needs one specific frame only, or the question isn't about the video's
visual content. Scope: **local video file paths only** — if the video lives elsewhere (a chat
attachment, a URL), ask the user for a local path first.

## Choosing the path

- `mcp_squish_squish_video` **is among your tools** → use the local path below. Nothing leaves
  the machine.
- The tool is **not available** (no squish MCP on this machine, or it failed to connect), or a
  call fails and one retry doesn't recover → use the **hosted API fallback** at the bottom.

## Primary path (local, nothing leaves the machine)

1. Call `mcp_squish_squish_video` with `{ "video_path": "<absolute path>" }`.
   Optional: `density` (`3x3` default; `4x4`–`6x6` pack more frames per sheet — use for long or
   fast-moving clips, or "how exactly did X happen" questions) and `out_dir`.
2. The result is JSON: `files[]` (sheet JPG paths, `.sheet-1.jpg`, `.sheet-2.jpg`, … in time
   order) and `timecodes[][]` (per-sheet, per-cell timecode strings).
3. Call `vision_analyze` on each sheet **in order** — each covers a consecutive window of the
   clip.

## Reading a sheet

- Cells run in time order, left→right, top→bottom.
- The pill in each cell's corner is that frame's timecode — cite those exact values.
- Adjacent cells that look alike = little changed in that window; a hard visual break between
  cells is where an event happened. Zoom your attention there.

## Answer shape

Never answer with just a file path. Give the user:

1. **Summary** — what the clip shows, one or two sentences.
2. **Key moments with timestamps** — the events that matter, each cited to a cell's timecode.
3. **Notable frames / anomalies** — anything odd, out of place, or worth a second look (and its
   timecode), or say there were none.

If the user's question was specific ("find the moment when…"), lead with that answer + timestamp.

## Fallback: hosted API (only when the local tool cannot run)

If `mcp_squish_squish_video` fails and retrying once doesn't recover (server gone, ffmpeg
missing, machine can't process the file), the hosted API does the same job remotely.
**This uploads the video** — unlike the local path, so say so to the user before using it. The
uploaded video is deleted when the job ends; sheet URLs live ~24 h.

```bash
curl -s -X POST https://api.getsquish.app/v1/squish \
  -H "Authorization: Bearer $SQUISH_API_KEY" \
  -F "video=@<path>" -F "density=3x3"
```

The JSON response mirrors the local contract: `files[]` are temporary sheet URLs (pass them to
`vision_analyze`), plus `timecodes[][]`, `credits_charged`, `credits_remaining`.

- **No `SQUISH_API_KEY` set?** Tell the user to sign in at https://getsquish.app/api-keys
  (email OTP) and mint a key — accounts that have never purchased get a **free daily allowance
  applied automatically on the first request**, so trying it costs nothing and needs no card.
- `402 insufficient_credits` means even that allowance is spent — lower `density`, or top up on
  the same page. Full error/retry contract: https://getsquish.app/llms.txt

## Provenance

First light 2026-07-05 (Hermes session `20260705_150943_55139e`): gemini-3.5-flash squished a
real clip and narrated it with correct timecodes from the sheets alone. Web (no-install) path
for humans: https://getsquish.app
