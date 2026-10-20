# Environment status — audited 2026-10-20

Machine: Windows 11 Pro 10.0.26200. Status vocabulary: `absent / installed / configured / connected / smoke-tested / blocked`.

| Component | Version / location | Status | Verified action | Blocker / note |
|---|---|---|---|---|
| winget | user WindowsApps | smoke-tested | used for Godot install | |
| Git | 2.52.0 | smoke-tested | `git init`, baseline commit | |
| Node / npm | 22.23.2 / 11.1.0 | smoke-tested | `npm install -g tripo-cli` | |
| Python | 3.12.6 (+ py launcher 3.13) | smoke-tested | `tools/doctor.py`, `tools/validate_template.py` | |
| uv / uvx | 0.7.12 | installed | runs Blender MCP server | |
| **Godot 4.7.2 stable (standard)** | winget `GodotEngine.GodotEngine` 4.7.2, user scope, `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine…`; aliases `godot`, `godot_console` on PATH; `GODOT_PATH` user env var set; hard link at `%USERPROFILE%\Godot\Godot.exe` for MCP auto-detect | smoke-tested | `--version` → `4.7.2.stable.official.ed1daf0bf`; import, boot, scripted gameplay | Installed this session (none was present) |
| Godot export templates 4.7.2 | `%APPDATA%\Godot\export_templates\4.7.2.stable` (Windows + Web) | installed | SHA-512 matched official `SHA512-SUMS.txt` | No export preset yet; no export run |
| Blender | 5.2.0 LTS (Steam install) | installed | `blender --version`; added to user PATH | |
| Claude Code / Codex | 2.1.303 / 0.160.0 | connected | this session | |
| **Playwright MCP** | configured in Claude desktop | smoke-tested | navigated `demo.playwright.dev/todomvc`, got snapshot | No web build to test yet |
| **Godot runtime MCP** (`godot-mcp-runtime`, run/screenshot/input/scene edit) | configured in Claude desktop | connected, **blocked** | server answers, but cached "no Godot" at startup | Needs MCP server restart/reconnect now that Godot exists |
| Godot editor MCP (`godot-mcp-server` 0.5.0, tomyud1/godot-mcp, websocket 6505) | configured in Claude desktop | connected, not linked | `get_godot_status` → editor not connected | Needs its editor addon in `addons/` (not bundled with npm package); deferred — runtime MCP + CLI cover current needs |
| Godot Forge MCP (Tann2019) | — | absent | — | Not installed: overlaps with the two Godot MCPs above; revisit only if editor-live control is needed |
| **Blender MCP** (`blender-mcp` via uvx) | configured, server process running | connected, **blocked** | `get_addon_status` → cannot reach Blender | Blender must be open with the "MCP for Blender" addon started (user action) |
| **Tripo CLI** | `tripo-cli` 0.7.1 (npm, publisher repo `vast-enterprise/Tripo-API-CLI`, no install hooks) | smoke-tested (no spend) | `tripo doctor`: key present in user profile (not in repo), API reachable | **0 credits** — any generation needs top-up + explicit approval |
| Windows desktop control | Anthropic `computer-use` MCP available in this app | connected | not used | Per-app approval prompts on first use; not exercised yet |
| Chrome DevTools MCP | 1.11.0 plugin | connected | not used | |
| fal.ai MCP (plugin) | — | blocked | — | `FAL_KEY` env var unset; optional |
| Jev AI | — | NOT VERIFIED | — | Exact provider unknown; ask user for link |

## Known quirk

- The very first `godot --headless --import` on a fresh `.godot/` cache completed all import steps, then exited with `0xC0000005` (access violation during shutdown). All subsequent imports exit 0. Recorded; not reproducible.

No API keys, credentials or private screen contents are recorded here.
