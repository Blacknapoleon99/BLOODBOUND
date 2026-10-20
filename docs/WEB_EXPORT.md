# Browser and Windows export

Status (2026-10-20): **Windows release and Web builds export and pass the in-game export probe.** Evidence is in `docs/TEST_RESULTS.md` (M6). Firefox, mobile and touch have not been tested.

## Presets (`export_presets.cfg`)

| Preset | Output | Notes |
|---|---|---|
| Windows Desktop | `build/windows/Bloodbound.exe` | Release, game data embedded in the exe, tests/tools excluded, `modify_resources=false` (no rcedit needed) |
| Windows Desktop (QA) | `build/windows-qa/BloodboundQA.exe` + `.console.exe` | Debug build with the console wrapper so probe output is visible |
| Web | `build/web/index.html` | **No-threads** variant (`variant/thread_support=false`), so no COOP/COEP headers are needed. Compatibility / WebGL 2 |

Export templates for 4.7.2 must be installed (`%APPDATA%\Godot\export_templates\4.7.2.stable`). `build/` is git-ignored.

## One-command export and probe (Windows)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/export_and_probe.ps1
```

This exports all three presets, then runs `scripts/qa/export_probe.gd` in the QA build (printed) and in the release build (exit code only, because a GUI-subsystem exe has no console).

The export probe exists because `--script` is an editor-only option: exported templates ignore it, so the full `tests/gameplay_smoke.gd` cannot run inside a packaged build. The probe starts the game from the title screen and drives move, jump, attack, card hand, level objects and pause through real input events.

## Web smoke test

1. Export (above), then serve over HTTP, never `file://`:
   ```powershell
   python -m http.server 8060 --bind 127.0.0.1 --directory build/web
   ```
2. Open `http://127.0.0.1:8060/index.html`. Expect the console to show `WebGL 2.0 … Compatibility` and `single-threaded`, with no errors. The title shows Start and Settings (Quit is hidden on web).
3. Open `http://127.0.0.1:8060/index.html?export-probe`. The probe runs automatically and logs `EXPORT PROBE RESULT: 10/10` to the browser console.
4. Known: after the probe calls `quit()`, Godot logs a `PagedAllocator … WorkerThreadPool` error during engine teardown. A normal page load logs no errors.

## Web-specific constraints found

- The web build ships only Godot's default font, so non-ASCII symbols like ■ and ◆ render as missing-glyph boxes. HUD text is kept ASCII; bundle a font before using symbols.
- Keep shading within Compatibility: no volumetric fog, no SDFGI.
