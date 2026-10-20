# BLOODBOUND — Agentic Game Development Starter

**An original, dark, visceral 2.5D action-platformer with giant background bosses, tactical combat cards, and brief third-person 3D arena encounters.**

This archive is a **ready-to-open Godot project plus development instructions** for Claude Code and OpenAI Codex. It is **not** a completed combat game. The included minimal greybox is an initial foundation: it demonstrates 2.5D movement, jumping, one melee target, gap/respawn, a basic win condition, and switching to a small 3D movement arena. Boss AI, actual card mechanics, and production assets are planned work.

## Start in under five minutes

1. Extract this ZIP somewhere writable; do not run the agents on the ZIP itself.
2. On Windows 11, Claude Code can install **missing** Godot/Blender/Node/uv and prepare the project for you. You must already have Claude Code (or Codex) installed and authenticated before asking it to perform setup. Use `prompts/AUTONOMOUS_BOOTSTRAP.md` for autonomous installation; its target is compatible Godot 4.7.x stable standard/GDScript. Open `project.godot` in Godot and press **F5** to run once setup is complete.
3. From the extracted project root, run **`claude`** (Claude Code) or **`codex`** (Codex CLI).
4. For a new PC setup, paste `prompts/AUTONOMOUS_BOOTSTRAP.md`, or tell Claude: **“Execute prompts/AUTONOMOUS_BOOTSTRAP.md end to end, install and test missing tools, then continue prompts/FIRST_RUN.md.”** After installation, use `prompts/FIRST_RUN.md` for ongoing development.
5. Read `MASTER_PROMPT.md` for the complete creative and engineering mission.

### Prototype controls

| Key | Behavior |
|---|---|
| A / D or Left / Right | 2.5D move |
| Space | Jump (edge-triggered) |
| J | Attack the crimson dummy if in range and facing it |
| E | Enter/leave the 3D training arena at the amber gate (3D: E anywhere to leave) |
| W / S | 3D depth movement **only while in arena** |
| R | Restart after victory |

The world is generated procedurally by `scripts/main.gd`, so geometry is intentionally simple and entirely replaceable.

## Project orientation

- `AGENTS.md` — **Codex** project instructions; shared, compact constraints.
- `CLAUDE.md` — **Claude Code** project instructions; reads shared rules and directs the initial session.
- `MASTER_PROMPT.md` — detailed multi-phase implementation mission.
- `prompts/AUTONOMOUS_BOOTSTRAP.md` — **first launch prompt** to audit/install missing tools and configure MCPs.
- `tools/windows_preflight.ps1` — non-destructive environment diagnostics.
- `prompts/FIRST_RUN.md` — development task after tool bootstrap.
- `docs/TOOL_INTEGRATIONS.md` — safe setup/workflows for Tripo3D, Blender MCP, Jev AI, other tools.
- `docs/ASSET_PIPELINE.md` — GLB/Blender/Godot standards.
- `docs/ROADMAP.md`, `docs/ACCEPTANCE.md` — milestones and proof required.
- `.claude/agents/` — optional role descriptions for Claude Code subagents.
- `scenes/`, `scripts/` — Godot foundation; no third-party asset dependencies.
- `tools/doctor.py`, `tools/validate_template.py` — setup diagnosis and static structure checks.
- `assets/incoming`, `assets/processed` — external-asset drop zones.

## Testing

```powershell
python tools/doctor.py
python tools/validate_template.py
# Replace "godot" with your actual executable if it is not on PATH
# These are not interchangeable: import/parse != actual gameplay testing
godot --headless --path . --import
godot --headless --path . --quit-after 30
```

`godot` may be named `godot4` or `Godot_v4.7-stable_win64_console.exe` on Windows. Use `where.exe godot` or an explicit path if necessary.

**Validation status at packaging:** source and archive static checks performed; **the Godot runtime was not installed in the packaging environment**, so live engine execution is **unverified**. The recipient agent's first job is to run Godot, fix any imports or script issues, and record exact test evidence. Do not state that the build was runtime-tested based on the file checks.

## Development approach

1. Keep the game launchable at every milestone.
2. Prioritize fun movement and clear combat feedback before generating expensive assets.
3. Do not execute paid API calls or external uploads without explicit permission.
4. Never commit API keys, raw credentials, or licensed assets with unclear redistribution rights.
5. Prefer reusing the same 3D movement/combat entities when the camera unlocks for 3D encounters.

## Source links for integration documentation

- [Godot 4.7 stable](https://godotengine.org/download/archive/4.7-stable/)
- [Godot command-line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [Godot web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
- [Tripo v3 API quick start](https://developers.tripo3d.ai/en/docs/quick-start)
- [Tripo v3 API overview](https://developers.tripo3d.ai/en/docs/introduction)
- [Blender MCP community implementation](https://github.com/ahujasid/blender-mcp)
- [Godot Forge editor MCP](https://github.com/Tann2019/godot-mcp-server)
- [Microsoft Playwright MCP](https://github.com/microsoft/playwright-mcp)
- [Claude Code official MCP documentation](https://code.claude.com/docs/en/mcp)

**Reference:** Tidebreaker on Wavedash is an *inspiration for the 2.5D depth/boss concept*, not a source of copyrighted gameplay assets, art, or code.
