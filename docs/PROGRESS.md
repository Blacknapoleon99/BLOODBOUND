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
