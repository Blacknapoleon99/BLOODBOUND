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

## 2026-10-20 — M1 platformer quality closed

- Changed: `scripts/player.gd` (rewritten motor: actions, coyote, buffer, variable jump, ground/air acceleration, dodge with i-frames and cooldown, `teleport_to`), `scripts/main.gd` (action-based interact/restart, checkpoint respawn, wider gap, HUD), new `scripts/input_bindings.gd` and `scripts/checkpoint.gd`, `tests/gameplay_smoke.gd` (44 checks), `docs/.gdignore`.
- Evidence: `docs/TEST_RESULTS.md` (M1 run).
- Blockers for later milestones: Blender MCP needs Blender + addon running; the Godot runtime MCP needs a reconnect; Tripo has 0 credits.

### Next action
M2 combat: hitbox/hurtbox/health components, a state-driven player attack with startup/active/recovery windows, and one patrolling enemy (plagued soldier) with telegraph → attack → recover → death. The enemy replaces the dummy, and the smoke test grows to match.

## 2026-10-20 — M2 combat closed

- New: `scripts/combat/` (Health, Hurtbox, Hitbox, DamageInfo, AttackData, MeleeAttack, HitFeedback), `scripts/game_settings.gd`, `resources/attacks/*.tres`, `scenes/enemies/plagued_soldier.tscn` + `scripts/enemies/plagued_soldier.gd`.
- Changed: `scenes/player.tscn` (combat nodes), `scripts/player.gd` (light J / heavy L, hit reactions, death, dodge exit-speed fix), `scripts/main.gd` (soldier replaces the dummy, death → checkpoint revive, HP HUD, camera shake, solid arena obelisks), `scripts/input_bindings.gd` (heavy_attack), `tests/gameplay_smoke.gd` (76 checks).
- Jev identified as TypeSafe AI's decision model, which is not an asset tool (DEC-008).
- Evidence: `docs/TEST_RESULTS.md` (M2 run).

### Next action
M3 Hollow Bishop: a giant background boss with a phase state machine and deterministic debug triggers. It needs two depth attacks that travel into the Z=0 plane with telegraphed threat volumes, one causeway-breaking attack with a recoverable route, a weak-point window, and a boss HP bar. Asset generation stays blocked (Tripo has 0 credits), so it uses greybox geometry.

## 2026-10-20 — M3 Hollow Bishop closed

- New: `scripts/boss/` (HollowBishop, BishopHand, BoneLance), `scripts/level/` (BreakableSegment, BossArena).
- Changed: `scripts/main.gd` (portcullis, boss arena and checkpoint, boss HP bar, victory on boss defeat, hazard reset on death or fall, 3D practice arena moved to z = 60, boss camera framing), `scripts/player.gd` (attack input buffer), `tests/gameplay_smoke.gd` (113 checks; traversal now jumps by ray probe).
- Evidence: `docs/TEST_RESULTS.md` (M3 run).

### Next action
M4 Bloodbound Cards: an AttackData-style `CardData` Resource; a blood-energy resource; hand UI; and Blood Spear (projectile that damages the exposed stigmata), Grave Shield (blocks the `heavy` category, e.g. the slam) and Ritual Chains (interrupts the Bishop's telegraph). Invalid or unaffordable plays must spend nothing.

## 2026-10-20 — M4 Bloodbound Cards closed

- New: `scripts/cards/` (CardData, CardDeck, BloodEnergy, CardSystem, BloodSpearProjectile), `resources/cards/*.tres`, `scripts/ui/card_hand_ui.gd`.
- Changed: `scripts/combat/hurtbox.gd` (`try_block` hook, `hit_blocked`), `scripts/player.gd` (Grave Shield ward), `scripts/boss/` (weak-point group, `can_be_interrupted`/`interrupt_with_chains`, chained state), `scenes/player.tscn` (BloodEnergy + Cards nodes), `scripts/input_bindings.gd` (cards on 1/2/3 and the D-pad), `scripts/main.gd` (hand UI, narrower boss bar), `tests/gameplay_smoke.gd` (143 checks).
- Evidence: `docs/TEST_RESULTS.md` (M4 run).

### Next action
M5 real third-person arena: shared HP, energy and cards across the 2.5D↔3D transition; a smooth camera transition; free X/Z combat with an enemy (a Plagued Soldier with `plane_locked = false`); win, exit and return to the correct 2.5D spot.

## 2026-10-20 — M5 Reality Fracture closed

- New: `scripts/level/reality_fracture.gd` (chapel, guardian, portal, fade transitions, fail/clear rules).
- Changed: `scripts/main.gd` (arena logic moved into the fracture, camera goal/snap helpers, fracture HUD), `scripts/enemies/plagued_soldier.gd` (`enemy` group, radius leash, `revive_at_home`, patrol z fix), `scripts/player.gd` (3D soft lock-on), `tests/gameplay_smoke.gd` (161 checks).
- Evidence: `docs/TEST_RESULTS.md` (M5 run).

### Next action
M6 vertical slice: main menu (Start / Settings / Quit), pause, a settings screen (reduced gore, camera shake, hitstop), a real level progression pass toward 5–10 minutes, a Windows export preset and build, and a first Web export smoke test served over local HTTP and checked with Playwright.

## 2026-10-20 — M6 vertical slice (partially closed)

- New: title screen (`scenes/main_menu.tscn`, now the main scene), `scripts/ui/` (main_menu, pause_menu, settings_panel, menu_style), settings persistence, `scripts/level/` (collapsing_slab, moving_platform), the Pursuit Approach and the Bishop PURSUIT phase, `export_presets.cfg`, `scripts/qa/export_probe.gd`, `tools/export_and_probe.ps1`, `docs/WEB_EXPORT.md` rewrite.
- Builds: the Windows release, Windows QA and Web builds all pass the export probe (the Web build in Chromium through Playwright).
- Open M6 items: timing the 5–10 minute flow with a human player, and a representative mid-range performance benchmark.
- Evidence: `docs/TEST_RESULTS.md` (M6 run).

### Next action
User playtest pass (feel, difficulty, slice length). Then M7: asset pipeline. Blender MCP needs Blender open with its addon started; Tripo needs credits and explicit approval per batch.

## 2026-10-20 — Playtest fix: damaging abilities

- Blood Spear now hits any enemy, attacks and cards buffer through hitstun, the Bishop is retuned (36 HP), and damage numbers plus refusal reasons were added. See DEC-021 and TEST_RESULTS.
- Fixed build: `build/windows-fix1/Bloodbound.exe` (the original exe was in use during the playtest).

## 2026-10-20 — Playtest round 3: combat feel + roguelike loop

- Step 1 (committed 187f5c4): 3-hit combo, hold-to-chain, auto-attack, poise, hit reactions; Bishop 60 HP.
- Step 2: draft before every run, 8-card pool (5 new cards), Blood Altars and a fracture relic, restart → new draft. Card reference: `docs/CARDS.md`.
- Build: `build/windows-run1/Bloodbound.exe`.

### Next action
Step 3: bigger Bishop (more attacks, abilities and phases). Step 4: more mid-run content (enemy variety, encounters between set-pieces).

## 2026-10-21 — Steps 3 and 4

- Step 3 (e868e1c): Hollow Bishop at 90 HP, four phases with roars and banners, Censer Sweep, Requiem Beam, Grasping Dead.
- Step 4: Bone Archer enemy and two ambush rooms (gate ossuary, landing), each rewarded by its Blood Altar.
- Build: `build/windows-run2/Bloodbound.exe`.

### Next action
Playtest the full run (draft → ambushes → fracture → pursuit → four-phase Bishop) and retune from the report: Bishop HP, card costs, ambush density.

## 2026-10-21 — Sound & music

- Added synthesized SFX and music (`tools/generate_audio.gd`, `assets/audio/`), the `Audio` service, Music/SFX volume sliders, and hooks for combat, cards, the Bishop, archers, ambushes, altars and UI.
- Fixed: the player's `landed` signal never fired.
- Evidence: 276/276 smoke checks; build `build/windows-run3/Bloodbound.exe`.

### Next action
Relics & card upgrades (passive run modifiers offered at altars and the fracture reward).

## 2026-10-21 — Relics & card upgrades

- 8 relics plus card upgrades. Altars offer 2 cards + 1 relic. The fracture offers 2 relics + 1 upgrade. Relics are shown in the HUD and carried in RunState.
- Evidence: 297/297 smoke checks; build `build/windows-run4/Bloodbound.exe`.

### Next action
User playtest of `build/windows-run4` (draft → altars → fracture → Bishop) for feel, sound mix, relic balance and run length.

## 2026-10-21 — Playtest feedback: manual melee, pace, abilities, hazards, equipment

- **Melee:** left click light / right click heavy; no auto-attack.
- **Pace:** faster everything, and a harder Bishop.
- **Bishop:** new Bone Rain and Marrow Geyser attacks.
- **Enemies:**
  - soldier Lunge and Frenzy;
  - Husk burst;
  - archer Grave Arrow and Bone Hop;
  - new Crypt Hound.
- **Route:** spike traps, a pendulum blade, faster slabs and ferry.
- **Equipment:** 13 items, 4 attributes, and the Armory between runs with spoils.
- **Evidence:** 347/347 smoke checks; build `build/windows-run5/Bloodbound.exe`.

### Next action
- ElevenLabs sound pass. This needs the user's go-ahead for the credit cost.
- User playtest of windows-run5.

## 2026-10-21 — ElevenLabs audio

- All 38 SFX and both music loops replaced with ElevenLabs generations (808 credits). See DEC-034 for the tool, cache and licensing note.
- Build: `build/windows-run6/Bloodbound.exe`.

### Next action
User playtest of windows-run6: listen pass on the new audio, plus feel of the new pace, abilities, hazards and the Armory.

## 2026-10-21 — Faster Bishop, overlapping attacks, reliquary, 5 utility cards

- Evidence: 369/369; build `build/windows-run7/Bloodbound.exe`.

### Next action
- ElevenLabs regeneration with the user's new key (needs cost approval).
- Start the art/asset phase (see the plan in chat).
