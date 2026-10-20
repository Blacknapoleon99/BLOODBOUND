# Progress log

## 2026-10-19 — Initial package

- Complete: requirements and agent prompts; core docs; procedural Godot project files; package structure and Python structural validator.
- Not complete: any production-quality gameplay milestone, The Hollow Bishop, Bloodbound Cards, UI menus, sound, finished assets, browser export.
- Not verified here: actual running Godot/editor, visual controls or engine log. See `docs/TEST_RESULTS.md`.

## Next action

Agent: execute `prompts/FIRST_RUN.md`, run real Godot checks on the user's machine, fix any errors, document evidence, and close milestone M0.

## 2026-10-20 — Bootstrap + M0 closed

- Installed: Godot 4.7.2 stable (winget, official, user scope) + 4.7.2 export templates (SHA-512 verified); tripo-cli 0.7.1. Blender 5.2 was already installed and is now on the user PATH. `GODOT_PATH` is set.
- MCP: Playwright smoke-tested. Godot runtime MCP needs a reconnect so it picks up Godot. Blender MCP needs Blender open with the addon server started. Tripo has 0 credits. See `docs/ENVIRONMENT_REPORT.md`.
- Git: repo initialized; the untouched starter is the baseline commit.
- Added `tests/gameplay_smoke.gd` (28 input-driven checks) and wired it into `tools/run_checks.ps1`. M0 is closed with evidence in `docs/TEST_RESULTS.md`.
- No game code changed for M0: the starter needed no repairs.

### Next action
M1 platformer quality: input map actions, coyote time, jump buffer, variable jump, dodge with i-frames, checkpoint. Extend the smoke test for each item.
