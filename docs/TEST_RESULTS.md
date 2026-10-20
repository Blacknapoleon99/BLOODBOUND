# Test evidence — append observed runs only

## Initial packaging checks (2026-10-19)

- Static structure validator: executed by packager. This validates file presence/path references and ZIP layout; it does **not** execute GDScript.
- Godot engine binary: **not available in packaging environment**.
- Actual Godot headless import/boot: **NOT RUN**.
- Visual/manual keyboard check: **NOT RUN**.
- Browser/Web export: **NOT RUN**.

## Template for a future agent run

- Date/time + machine:
- Godot executable + actual version:
- Git commit:
- Commands executed:
- Standard output/exit code:
- Visual checks and observed outcomes:
- Screenshots/recording links (if any):
- Known failures and fixes:
- Milestone acceptance items verified:

## M0 verification run (2026-10-20)

- Machine: Windows 11 Pro 10.0.26200, Godot `4.7.2.stable.official.ed1daf0bf` (official winget build, Compatibility renderer).
- Baseline commit: starter imported unchanged as the first commit.
- Commands and observed results:
  - `python tools/validate_template.py` → passed (16 files).
  - `python tools/doctor.py` → Godot found, version reported.
  - `godot_console --headless --path . --import` → first run: import completed, then exit `0xC0000005` on shutdown; rerun exit 0 (not reproducible).
  - `godot_console --headless --path . --quit-after 120` → exit 0, no script errors.
  - `godot_console --headless --path . -s res://tests/gameplay_smoke.gd` → **28/28 checks passed**, exit 0.
  - Same test in a visible window (`godot_console --path . -s res://tests/gameplay_smoke.gd`) → 28/28, screenshots saved.
  - `tools/run_checks.ps1 -Godot godot_console` (all of the above) → exit 0.
- What the automated gameplay test does: sends real `InputEventKey` events through `Input.parse_input_event`, so `player.gd` and `main.gd` get them the same way as from a keyboard. It covers:
  A/D movement and facing; Space jump height; holding Space does not bunnyhop; gap fall → respawn at start; real traversal from spawn across both gaps and the raised step to the dummy; J kills the dummy only while facing it in range; walking to the amber gate; E → 3D mode with arena camera framing; W/S depth movement; E → back to 2.5D with Z restored to 0 and side camera framing; reaching EXIT → victory + frozen player; R → fresh restart at spawn; max |Z| drift in 2.5D = 0.0000.
- Screenshots: `docs/screenshots/01_boot.png`, `02_at_dummy.png`, `03_arena.png`, `04_victory.png` (visible run).
- Limitations: the gap-death check places the player above the gap instead of walking into it. Nobody has played it by hand yet, so feel and tuning are unjudged. No web export yet.
- Observed issues to fix later (not M0 blockers): arena obelisks have no collision (the player walks through them); attacking in 3D only shows a "planned" message.
- M0 acceptance items verified: Baseline smoke 1–9 (item 1 via headless editor import plus visible game window; editor GUI not opened by hand).
