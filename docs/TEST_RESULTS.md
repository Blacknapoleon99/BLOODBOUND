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

## M1 verification run (2026-10-20)

- Godot `4.7.2.stable.official.ed1daf0bf`, Windows 11.
- `tools/run_checks.ps1 -Godot godot_console` → exit 0. `tests/gameplay_smoke.gd` → **44/44** headless and 44/44 in a visible window.
- New M1 measurements (frame = 1/60 s physics tick):
  - Variable jump: holding Space rises 2.13 m; a 2-frame tap rises 0.54 m.
  - Coyote time (0.10 s): a jump 3 frames after walking off the ledge succeeds; at 12 frames it is ignored.
  - Jump buffer (0.12 s): pressing 5 frames before landing re-jumps on landing; at 14 frames it is ignored.
  - Holding Space through a landing gives exactly 1 takeoff (no bunnyhop).
  - Dodge: 3.95 m burst along facing with no input. Invulnerable right after the press, not after ~0.33 s. A second press during the 0.45 s cooldown is ignored; one after the cooldown works. In 3D the dodge follows input (W → −3.5 m in Z).
  - Checkpoint: inactive at start. Real traversal across the broken span activates it. A fall into the second (now 1.5 m) gap respawns at the checkpoint (−4.5, 1.2, 0). The route from the checkpoint to the dummy can be traversed.
  - All M0 checks still pass. Max Z drift in 2.5D = 0.
- Screenshot: `docs/screenshots/02_at_dummy.png` shows the active checkpoint banner and HUD.
- Limitations: the gap falls are set up by teleporting above the gap. Gamepad bindings are registered but untested (no pad connected). Nobody has hand-tuned the feel yet.

## M2 verification run (2026-10-20)

- Godot `4.7.2.stable.official.ed1daf0bf`, Windows 11.
- `tools/run_checks.ps1 -Godot godot_console` → exit 0. `tests/gameplay_smoke.gd` → **76/76** headless and 76/76 in a visible window. No script errors or warnings in the output.
- Combat checks (frame = 1/60 s):
  - Light attack phases match `player_light.tres` exactly: 6/6/14 frames. The hitbox is live only in ACTIVE (0 wrong frames). A whiff out of reach deals 0 damage.
  - Heavy startup is 20 frames (matches data, over twice the light wind-up). Heavy deals 2 damage.
  - Cancel rules: a dodge during STARTUP is ignored; a dodge during light RECOVERY cancels into the dodge.
  - Soldier AI: patrols at boot → CHASE → ATTACK. The telegraph (glow plus red floor marker) starts 32 frames before the hit. The slash deals 1 damage, then the player gets hitstun, i-frames and ~1.4 m of knockback. A dodge timed into the next strike absorbs it (HP unchanged).
  - Dying to the soldier revives the player at the checkpoint with full HP. Walking into the soldier deals contact damage (1, at most once per second).
  - The soldier stops at its leash (8.54 vs 8.50) when chasing past its zone.
  - Player hits: attacking while facing away misses; a light hit deals 1 damage plus HITSTUN plus knockback; heavy kills. The corpse loses collision and its hurtbox, and the level registers the defeat.
  - Blood spray is red by default; with `GameSettings.reduced_gore` it's ash grey.
- Bugs found and fixed during this run:
  - Each attack phase ran one frame long because of float accumulation (`0.1 − 6/60 ≈ 1e-17`); fixed with an epsilon.
  - The dodge kept 15 m/s after ending and slid ~2 m further (6 m total). It now ends at run speed (3.9 m total), and an M1 check guards it.
  - The soldier could chase into a pit and softlock the exit. A leash plus return-home were added and tested.
- Screenshots: `docs/screenshots/02_soldier_hit.png` (blood spray, HP pips), `03_soldier_dead.png`.
- Limitations: test setups place combatants by teleport and toggle AI with `set_ai_enabled`, but every hit goes through the real hitbox → hurtbox → health path. The player-death setup lowers HP directly before the real killing blow. Hitstop, camera shake and blood readability are only checked by eye in screenshots. Gamepad is untested. Nobody has tuned it by hand yet.

## M3 verification run (2026-10-20)

- Godot `4.7.2.stable.official.ed1daf0bf`, Windows 11.
- `tools/run_checks.ps1 -Godot godot_console` → exit 0. `tests/gameplay_smoke.gd` → **113/113** headless and 113/113 in a visible window. No script errors or warnings in the output.
- Boss checks:
  - Level flow: the portcullis blocks the player while the soldier lives and opens on its death. Entering the arena activates the arena checkpoint and awakens the Bishop (DORMANT → INTRO → PROCESSION after 1.8 s). The HP bar shows 12/12 and the phase title.
  - Hand Slam: the telegraph plate shows 92 frames before impact, at the exact strike x. The hand travels from z = −18.5 to z = 0.00. A player who stays takes 2 damage; one who steps off the plate during the telegraph takes 0.
  - Weak point: the stigmata is closed while the hand is raised and opens when it lands. A light hit takes the Bishop 12 → 11; a buffered heavy takes 11 → 9. The window lasts 2.50 s in phase I and 4.00 s in phase III. Once it closes, hits are ignored.
  - Bone Lance: it starts at z < −15 with a red lane column at the target x. It hits a player standing in the lane at z = −0.73 (1 damage). Jumping over it takes 0 damage, and so does dodging out of the lane.
  - AI: with AI on, the Bishop alternates Hand Slam and Bone Lance volley within 10 s.
  - Phase II at HP 8; the bar title updates. Sunder breaks the struck segment and enables its rubble ledge. Neighbours of a gap and the entry segment refuse to break. The player can jump the 4 m gap. The rubble catches a player who drops in (y = −0.15), and the player can climb back out. A fall respawns at the arena checkpoint and reknits the causeway.
  - Phase III at HP 3. Light + heavy stigmata hits defeat the Bishop: it stops attacking, the run is won, and R restarts.
- Bug found and fixed: attack presses during hitstop-stretched recovery were dropped. A 0.15 s attack buffer was added, tested in both directions (inside the window it fires; outside it's dropped).
- Screenshots: `docs/screenshots/05_bishop_awake.png`, `06_weak_point.png` (hand on the causeway, stigmata lit), `07_causeway_broken.png` (gap plus rubble, phase II bar), `08_victory.png`.
- Limitations: phase II and III are reached by applying boss HP damage directly (a debug path). Each threshold transition still runs the real logic. Attacks are triggered through `debug_attack` except in the 10 s AI check. Nobody has played the fight by hand yet, so its difficulty and pacing are unjudged. All boss and arena visuals are greybox primitives.

## M4 verification run (2026-10-20)

- Godot `4.7.2.stable.official.ed1daf0bf`, Windows 11.
- `tools/run_checks.ps1 -Godot godot_console` → exit 0. `tests/gameplay_smoke.gd` → **143/143** headless and 143/143 in a visible window. No script errors or warnings in the output.
- Card checks (passive regen is disabled during them so energy can be compared exactly):
  - Data: costs 2/2/3 and targeting rules load from `resources/cards/*.tres`. The starting hand holds the three starter cards.
  - Deck: the same seed deals an identical sequence and a different seed a different one. Every card in a 10-card deck is dealt once before any repeats. Draw/discard/reshuffle conserves all 10 cards. Played starter cards return to the same slots.
  - Invalid plays spend nothing and apply nothing:
    - Spear with no exposed weak point → `no_target` (no projectile, no cooldown).
    - Chains with nothing to interrupt → `no_target`.
    - Shield with 1 blood → `energy` (no shield).
    - Shield replayed during cooldown → `cooldown`.
    - Spear from 19 m → `out_of_range`.
    - The UI dims unaffordable or cooling cards, flashes NEED BLOOD and COOLING, and shows the cooldown timer.
  - Grave Shield (played with its real key): the ward rises and 2 blood is spent. It absorbs a 2-damage slam (HP stays 5) and is used up. A heavy-only ward does not stop a lance (projectile category; HP 5 → 4).
  - Ritual Chains (real key) during the slam's hover: the attack becomes `chained` and 3 blood is spent. The hand never becomes a hitbox, and a player standing under the plate takes 0 damage. The stigmata opens; a light hit damages the Bishop and earns +1 blood.
  - Blood Spear in range of the exposed stigmata: 2 blood spent, one projectile launched, and it deals 2 (8 → 6). The spent spear is removed.
- Screenshot: `docs/screenshots/07_chained.png` (card hand, energy bar, chained hand with the stigmata exposed).
- Limitations: test setups set blood energy directly with `BloodEnergy.set_amount`, but earning energy from melee hits is checked separately. Shield and Chains go through their key bindings; Spear is played through `CardSystem.play_slot`, which is the same call the key binding makes. Gamepad D-pad bindings are untested. Cards have no authored VFX yet, only the greybox spear and ward meshes.

## M5 verification run (2026-10-20)

- Godot `4.7.2.stable.official.ed1daf0bf`, Windows 11.
- `tools/run_checks.ps1 -Godot godot_console` → exit 0. `tests/gameplay_smoke.gd` → **161/161** headless and 161/161 in a visible window (re-run after the veil was added). No script errors or warnings in the output.
- Reality Fracture checks:
  - Transition in: E at the gate starts the transition and freezes input. The fade reaches alpha 1.00 over the teleport and returns to 0. Control is restored in 3D.
  - HP 4, blood 2.0 and the Grave Shield cooldown (5.3 s left) carry across unchanged. The camera eases to the 3D framing (offset y 5.81, z 11.50).
  - Movement: W/S move in depth (−2.90 / +3.30 m), the depth position persists while strafing, and the 3D dodge follows input (−3.51 m in Z). E cannot leave while the guardian lives.
  - Guardian AI on X/Z: PATROL → CHASE → ATTACK, chasing up to 2.96 m in depth. Its slash deals 1 damage, and knockback moves the player on both axes (Δx −0.96, Δz +0.72).
  - Failure path: dying inside expels the player to the exact entry spot (x 13.21 → 13.21, z 0.000), healed. The guardian resets to full HP, the portal re-seals, and the fracture can be re-entered.
  - Soft lock-on: with no input after facing +X, a light attack turns to face (0.21, 0, −0.98) and hits the guardian standing to the side. A heavy hit kills it and the portal opens.
  - Exit: walking into the open portal returns the player to the exact entry spot, at full HP and +3 blood (1.0 → 4.0). The camera returns to side framing (z 22.0). The cleared fracture stays sealed.
  - Z drift during 2.5D play stays 0 across all transitions.
- Screenshots: `docs/screenshots/04_fracture.png` (chapel, shield ward, card cooldowns carried across), `05_fracture_cleared.png` (guardian down, portal lit).
- Limitations: the death setup lowers player and guardian HP directly before the real killing blow, and combat test positions are set up by teleport. The camera has a fixed angle (no orbit or mouse look). Gamepad is untested. Nobody has hand-tested the camera for comfort.

## M6 verification run (2026-10-20)

- Godot `4.7.2.stable.official.ed1daf0bf`, Windows 11, export templates 4.7.2.
- `tools/run_checks.ps1 -Godot godot_console` → exit 0. `tests/gameplay_smoke.gd` → **184/184** headless and 184/184 in a visible window. No script errors or warnings in the output.
- Menus and settings: the title screen shows Start (focused), Settings and Quit. Settings changes to gore, shake and hit-stop apply immediately and survive save + reload (separate test file; the player's real settings are untouched). Esc returns from Settings. Enter on Start loads the game.
- Pause: Esc pauses and the player does not move while paused. Settings opens from pause and Esc goes back. Esc resumes. Pause → Main menu returns to the title screen, unpaused.
- Pursuit Approach:
  - The Bishop is dormant until the approach, rises (INTRO), then enters PURSUIT with no HP bar. It throws a lance at the player's lane (dx 0.00).
  - The player runs the collapsing slabs; slabs crumble behind and return after 4 s. Standing still drops the player, and the respawn at the approach checkpoint restores the slabs.
  - The bone ferry carries the player over the 10 m gap (x 52.51).
  - Reaching the arena turns the pursuit into PROCESSION. All M3/M4 boss and card checks pass at the new arena position.
- **Windows release build** (`build/windows/Bloodbound.exe`, 109 MB, data embedded): export exit 0. Export probe 10/10 (exit 0) both headless and in a visible window. Screenshot: `docs/screenshots/10_windows_release_build.png`.
- **Windows QA build** (debug, console): export probe printed 10/10.
- **Web build** (`build/web`, no-threads, 39.5 MB wasm), served with `python -m http.server` on 127.0.0.1:8060 and driven by the Playwright MCP (Chromium):
  - Console: `WebGL 2.0 … Compatibility`, `single-threaded`, 0 errors and 0 warnings on a normal load.
  - The title renders and Quit is hidden on web. Browser Enter starts the game, and the causeway, HUD and card hand render. Screenshots: `11_web_title.png`, `12_web_gameplay.png`.
  - `index.html?export-probe` → **10/10 in the browser** (move dx 2.90, jump 2.13, attack, cards, level objects, pause/resume).
  - The only console errors appear after the probe calls `quit()` (engine teardown: PagedAllocator/WorkerThreadPool).
- Bug found and fixed: on web, the ■/□ HP pips and the ◆ cost symbol showed as missing-glyph boxes (no system font fallback). The HUD now uses ASCII (`HP 5/5`, `Cost 2`).
- Test bug fixed: the fracture transition wait counted frames; at 240 fps in the visible run it timed out. It is now time-based.
- Performance (this PC, visible run, vsync on): 223–240 fps at every screenshot point. Process time is 4.2–4.5 ms in steady play, with spikes of 24.9 ms at the first frame after load and 28.8 ms on entering the fracture (scene and shader setup). Draw calls 46–102, about 2,150 objects, about 45 MB static memory. These are **not** representative mid-range numbers; that benchmark is still open.
- Not verified: Firefox and Safari, mobile and touch, gamepad, clean-machine install, a human playthrough timing the 5–10 minute target.

## Playtest fix — damaging abilities (2026-10-20)

- Report (user playtest of `build/windows/Bloodbound.exe`): damaging abilities don't seem to work.
- Reproduction (`godot_console --headless --path . -s res://tests/diag_abilities.gd`, real keys, AI on):
  - Blood Spear vs a living Plagued Soldier (6 blood, 1.8 m away) → `no_target`.
  - In the Bishop fight, the spear pressed as the stigmata opened → `blocked` (player in slam hitstun).
  - Melee spam at the fallen hand killed the 12-HP Bishop in 11.1 s, across two windows.
  - Instrumented window: 6 attacks / 6 damage per 2.72 s window, about 29 frames per attack.
- New tests (failed before the fix, pass after):
  - Spear fires at the soldier and deals 3 (3 → 0), with a floating damage number.
  - J pressed during hitstun lands after the stun (23 → 22).
  - Spear pressed during hitstun fires after the stun (22 → 19, no failures).
  - One window of optimal melee deals 6 of 36 (bound: at least 3, at most 1/5 of max HP).
  - The HUD explains a refused spear.
- Same diagnostic after the fix: the spear one-shots the soldier and fires in every Bishop window. A superhuman bot (stands on the impact spot, blood refilled every window) needs 4 windows / 31 s through all three phases. A real player should take longer.
- Also fixed in the test: the 3D dodge check could be blocked by the patrolling guardian, depending on run timing. The guardian is now parked off the lane.
- `tools/run_checks.ps1` → **193/193**, exit 0. Visible run 193/193.
- Builds:
  - `build/windows-fix1/Bloodbound.exe` export probe 10/10 (exit 0). Written to a new folder because the playtest copy in `build/windows/` was running and locked.
  - QA build probe 10/10.

## Playtest fix — mouse card targeting (2026-10-20)

- Report: cards show READY but say "no target" even after clicking the target.
- Evidence: there was no mouse handling in `scripts/` (grep for `InputEventMouse`, `gui_input`, `MOUSE_BUTTON` found nothing). Clicks were never read.
- Click diagnostic: headless, a click on a card slot reaches no Control (`gui_get_hovered_control()` is null for both `Input.parse_input_event` and `Viewport.push_input`). With a window, the same click reaches `CardSlot1` and emits `slot_clicked`. So headless Godot drops mouse input.
- New checks (`_fix_mouse_cards_vs_soldier`, `_fix_mouse_cards_vs_bishop`):
  - Clicking the Blood Spear card arms it.
  - Clicking empty space spends nothing; the card stays armed and the HUD says why. Right-click cancels.
  - Clicking the soldier spears it (3 → 0).
  - Clicking Grave Shield plays it immediately.
  - Clicking the Bishop's body refuses and points to the stigmata.
  - Clicking the exposed stigmata spears it (19 → 16).
- `tools/run_checks.ps1` → **202/202** headless (clicks routed to the same handlers) and **202/202 in a visible window** (real mouse events through Godot input and GUI picking).
- Build: `build/windows-fix2/Bloodbound.exe`, export probe exit 0. QA build probe 10/10.

## Playtest request — combat feel (2026-10-20)

- Combo diagnostic before the lunge fix: held J went light → light_2 → (player hit by soldier contact, dist 0.97) → combo reset to light, and the finisher never landed. After the fix: light, light_2, finisher, light…, 1.5 blood in 1.2 s.
- New checks:
  - Holding J chains light → light_2 → finisher and repeats (5 attacks in 1.6 s); releasing J stops it.
  - Auto-attack turns to and hits a soldier behind the player (6 → 2). With it off, nothing swings; it never swings at empty air.
  - A single quick hit doesn't interrupt the soldier's wind-up (poise). A light hit flashes the soldier and chips poise (3 → 2). The heavy breaks poise: stagger plus 2.66 m knockback.
  - Being hit flashes the player and pulses the vignette (alpha 0.54).
  - The held combo kills the 2.5D soldier and the 3D guardian.
  - Bishop window bound: 9 of 60 per window.
- `tools/run_checks.ps1` → **212/212**. Visible run 212/212 (screenshot `02_soldier_hit.png` shows the recoil lean, vignette and spray).
- Build `build/windows-fix3/Bloodbound.exe`, export probe exit 0.

## Playtest request — roguelike run loop (2026-10-20)

- `tools/run_checks.ps1` → **242/242** (243 s). Visible run **242/242** (240 s).
- New checks:
  - Start opens the draft; each round offers 3 distinct cards and skips already-picked ones. The drafted cards are the starting hand.
  - The card pool has 8 cards, and the same run seed gives the same offers.
  - Clearing the fracture offers a relic (pick 1 of 3, game paused), and taking nothing resumes play.
  - R after victory starts a new run with a fresh draft.
  - Blood Altar: E offers 3 cards and pauses. Picking adds the card (deck 4) and spends the altar, which then offers nothing more. The new card cycles into the hand when a card is played.
  - Hemorrhage Pact is refused at 1 HP, otherwise HP 5 → 4 and blood +4.
  - Transfusion is refused at full HP, otherwise +2 HP.
  - Epitaph marks first, then erupts for 4 and staggers (6 → 2).
  - Ashen Choir's phantom fires 3 shards (6 → 3) and then fades.
  - Bell of Silence cancels the soldier's wind-up, and the soldier doesn't attack for 3 s.
- Export probe updated for the draft flow (Start → draft → 3 picks → level): 11/11 in the editor and in the QA build. Release `build/windows-run1/Bloodbound.exe` probe exit 0 on 3 of 3 runs.
  - The first probe of this build crashed (0xC0000005) because the old probe called into a level that wasn't loaded yet (Start now opens the draft); fixed in the probe.
- Screenshots: `docs/screenshots/09_draft.png`, `09_altar_offer.png` (captured with `tests/shot_draft.gd`).

## Step 3 — bigger Bishop (2026-10-21)

- `tests/gameplay_smoke.gd` → **260/260** headless and **260/260** visible.
- New checks:
  - **Censer:** it telegraphs first. Standing costs 1 HP; jumping as it closes (≤5 m) avoids it.
  - **Requiem Beam:** standing costs 2 HP; dodging toward the beam avoids it.
  - Silence cancels a censer still in its telegraph.
  - **Grasping Dead:** 2 Husks on the plane, never more than 2. They die to the combo and feed blood.
  - Phase II brings the roar plus the banner ("THE HOLLOW BISHOP / II · THE COLLAPSE"), and the roar ends after 1.8 s.
  - Phase III AI uses summon and beam. Phase IV (HP 12) brings the roar, the banner and a 5.0 s window (vs 4.0 s in III).
  - The Husks crumble when the Bishop falls.
- Screenshots: `docs/screenshots/11_censer.png`, `12_requiem_beam.png`, `13_husks.png`.

## Step 4 — Bone Archer and ambush rooms (2026-10-21)

- `tools/run_checks.ps1` → **269/269**. Visible run **269/269**. Release `build/windows-run2/Bloodbound.exe` export probe exit 0.
- New checks:
  - The archer draws (aim line) when the player is in range. Jumping the arrow avoids it; standing costs 1 HP.
  - Gate ossuary: walls rise and 2 Husks + an archer spawn. The fracture gate waits while the ambush holds, and the wall keeps the player in (x 9.95 > 9.3). Slaying every foe drops the walls (CLEARED).
  - Landing ambush springs with 3 foes. Dying mid-fight clears it and re-arms it (0 leftover).
- Fixed during testing: `Ambush.alive_count()` touched freed Husks (script errors). It now prunes freed references; archers also free themselves after death.
- Screenshot: `docs/screenshots/14_ambush.png`.

## Sound & music run (2026-10-21)

- `tools/run_checks.ps1 -Godot godot_console` → **SMOKE RESULT: 276/276 checks passed**.
- The first run failed one new check: `land` was never triggered. This exposed the `landed` signal bug (DEC-027). After the fix it passes.
- New checks: all 32 sounds and both music loops load with non-zero length. The level plays `music_level`, which loops (LOOP_FORWARD). The boss track starts with the fight. Victory stops the music and plays `victory`. The Music slider sets the Music bus dB. Volumes persist through save/reload. Every one of the 32 sound ids was triggered by real gameplay during the suite.
- `--export-release "Windows Desktop" build/windows-run3/Bloodbound.exe` → exit 0. Audio is in the pack. The release export probe exits 0.
- Not verified: how the sounds feel when heard by a person (no one has listened to the mix yet).

## Relics & upgrades run (2026-10-21)

- `tools/run_checks.ps1 -Godot godot_console` → **SMOKE RESULT: 297/297 checks passed** (21 new).
- New checks:
  - the pool has 8 distinct relics; the altar offers 2 cards + relic; the fracture offers 2 relics + upgrade; buttons are labelled;
  - an upgrade replaces the card (deck size unchanged), costs 1 less with a shorter cooldown, and is never offered again;
  - each relic's effect was measured in play: Bone Ward 6/6 HP; Vessel 8 max and +2; Wraith Step 0.40/0.30; Seal heavy +1 and jabs unchanged; Rosary cooldown ×0.75 on a real Blood Spear play; Thorned spear hitbox +1; Leech Fang +1 blood on a real kill; Gravebloom heals on the 4th kill only;
  - with all relics held, the altar falls back to cards; the HUD lists relics;
  - relics and upgrades carry from RunState into a freshly loaded level.
- Screenshots: `docs/screenshots/09_altar_offer.png`, `10_fracture_offer.png` (visible run of `tests/shot_draft.gd`). Text fits the 250×230 buttons.
- `build/windows-run4/Bloodbound.exe` exported (exit 0); the release export probe exits 0.
- Not verified by a human: balance of relic values over a full run.

## Playtest-feedback run: manual melee, pace, abilities, hazards, equipment (2026-10-21)

- `tools/run_checks.ps1 -Godot godot_console` → **SMOKE RESULT: 347/347 checks passed**.
- New checks cover:
  - **Melee:** left/right click bindings; a left click starts the light attack; nothing swings without input.
  - **Bishop barrage:**
    - Bone Rain marks rings, then marks a second wave, and hurts a player who stands still;
    - running escapes the Marrow Geyser, while standing still gets hit;
    - silence cancels a barrage.
  - **Enemy abilities:**
    - Plague Lunge; Frenzy, cleared on revive;
    - Husk burst (measured as the lowest HP during the burst);
    - Grave Arrow lands on the player's spot; Bone Hop;
    - the Hound crouches, pounces, hurts a still player, dies in recovery; hounds are in the ambushes.
  - **Hazards:**
    - 3 spike traps and a pendulum exist; a trap cycles through all states and hurts a player standing on it;
    - crossing while the spikes are down is safe; the pendulum hits and sweeps at a jumpable height;
    - respawn resets the traps.
  - **Equipment:**
    - 13 items, at least 3 per slot; starters have no bonuses; Armory base stats match the player;
    - spoils offer 3 unowned items, and claiming one adds and equips it (via key 2);
    - clicking equips one item per slot; attributes and preview add up (Health 7, heavy 6, x0.85);
    - in the level: Vigor, Agility and Devotion apply; heavy deals 6 at ×0.85 swing speed (frame-measured);
    - the profile persists;
  - **Flow:** victory earns a spoil; Start/R → Armory → draft.
- Several checks hard-coded the old tuning and were updated: dodge cooldown wording, Husk cap, arrow reaction distance, Wraith Step numbers, final-hit timing in the faster Unmaking, and patrol measured as max displacement.
- **Bugs caught by the tests during this work:**
  - a leash clamp that pushed soldiers standing outside their range (replaced by a predictive stop);
  - a typed-array assignment error in the Armory.
- Two failures were test choreography and are documented in the test:
  - the Husk-burst check stood in the revived soldier's contact range;
  - the archer was cornered against its wall.
- Build: `build/windows-run5/Bloodbound.exe`, exit 0. The release export probe (now Start → Armory → draft → level) exits 0.
- Screenshot: `docs/screenshots/11_armory.png`.
- Not verified by a human: feel of the new pace, difficulty of the Bishop at 120 HP, hazard timing on a keyboard.

## ElevenLabs audio run (2026-10-21)

- Two single-sound test calls first, to measure the real cost and format. Then the full batch: 40/40 generated, 0 failed, 808 credits in total.
- File check: every WAV is mono 22050 Hz and non-silent (RMS 0.03–0.38, peaks 0.45–0.95). Music is 24.0 s (level) and 16.0 s (boss).
- `tools/run_checks.ps1 -Godot godot_console` → **SMOKE RESULT: 347/347** (every sound loads and is triggered by gameplay; music loops).
- `build/windows-run6/Bloodbound.exe` exported; the release export probe exits 0.
- Not verified: how the sounds actually sound. No human has listened yet, and the loop seams are only as clean as the model's `loop` output.

## Faster Bishop, reliquary, utility cards (2026-10-21)

- `tools/run_checks.ps1 -Godot godot_console` → **SMOKE RESULT: 369/369**.
- New checks:
  - **Bishop:**
    - in a phase III AI window the Bishop has a main attack and a second ability active on the same frame;
    - the second-ability counter rises;
    - it never adds a censer on top of the beam.
  - **Reliquary:** it is in reach after victory; E opens 3 items; the pick lands in the stash and the chest is spent.
  - **Cards:**
    - 13 in the pool;
    - Shadow Step moves 4.5 m through the soldier and is invulnerable, but stops at the sealed portcullis;
    - Grave Hook pulls you to within 1.6 m and deals 1, and from inside the pit it hauls you onto the ledge;
    - Blood Nova deals 2 in range;
    - Ossuary Bridge spawns at foot level, is solid enough to stand on, and crumbles after 5 s;
    - Haste applies ×1.3, covers more ground than normal running, and wears off.
- `build/windows-run7/Bloodbound.exe` exported; the release export probe exits 0.
- Six new sounds are placeholders (synth) until the next ElevenLabs batch: card_step, card_hook, card_bridge, card_nova, card_haste, loot_drop.

## Sound v2 + voices (2026-10-21)

- **Generation:** 46/46 SFX and 20/20 voice lines generated, 0 failed. Files checked: mono 22050 Hz, Bishop lines 1.5–5.8 s, knight cries 0.5–2.6 s, peaks normalised.
- `tools/run_checks.ps1 -Godot godot_console` → **SMOKE RESULT: 373/373**:
  - every SFX (now including player_fall, player_death and player_effort) is triggered by gameplay;
  - all 12 Bishop lines exist;
  - the Bishop speaks at awakening, fight start, phases II–IV and death, plus at least 8 different lines in total;
  - the knight has 4 hurt takes.
- `build/windows-run8/Bloodbound.exe`; the release export probe exits 0.
- Not verified: listening. The demonize settings are a first guess, and the knight's short cries depend on how TTS reads interjections.

## First map run (2026-10-21)

- `tools/run_checks.ps1 -Godot godot_console` → **SMOKE RESULT: 424/424** (51 new).
- **Map:**
  - seed determinism and variety; layout rules over 40 seeds;
  - the validator rejects a 9 m gap and a 2.2 m step, and accepts 3 m and 1.4 m;
  - all 12 rooms are provably completable;
  - the full map builds 8 rooms end to end, with the arena shifted after them;
  - every room's checkpoint stands on solid ground; the HUD names the room; entering a room sets its checkpoint.
- **Enemies:**
  - **Shielded Knight:** frontal block, heavy guard break, hit from behind, shield bash, shard drop.
  - **Flying Wraith:** hovers, then dives and hits.
  - **Bone Crawler:** fuses and bursts; killed early, it still bursts.
  - **Ambush waves:** two waves, then cleared.
- **Gravewarden:**
  - the charge lane telegraph, the charge hitting you, and the wall daze;
  - quake waves hurt; two summons; enrage and the double charge; 40 shards;
  - the hall seals, the HP bar names it, and the relic reliquary works.
- **Merchant:** wares; refusal with no shards; relic purchase and restock; heal refused at full HP, then bought; leaving keeps the stock.
- **Secrets and shortcuts:**
  - the cracked floor holds you, and heavy strikes break it so you drop into the cellar;
  - the cache gives shards; the room stays completable; cards don't target the floor;
  - the shortcut starts closed, the lever opens it, and the bridge is solid.
- Screenshots: `docs/screenshots/12_map_*.png` (visible run of `tests/shot_map.gd`, seed 77).
- `build/windows-run9/Bloodbound.exe`; the release export probe exits 0.
- **Not verified:** time to reach the Bishop (needs a human run), difficulty balance across rooms, and how the new enemies feel.

## Tighten-up + co-op run (2026-10-21)

- `tools/run_checks.ps1 -Godot godot_console` → **SMOKE RESULT: 446/446** (22 new: 21 for co-op, 1 for the niche hop-out).
- **Bug-hunt fixes verified by tests:**
  - the secret is claimed and exited without teleporting;
  - Gravewarden summons stay inside its walls;
  - the solo suite is unchanged (425 → still green).
- **Co-op checks:**
  - two players with separate hands and HUD;
  - arrows/numpad drive only player 2, and D drives only player 1;
  - player 2's card spends player 2's blood;
  - enemies pick the nearest player; the camera centres between them; the leash holds 18 m;
  - down → revive by holding E (2 HP); both down → checkpoint;
  - a pit fall rejoins the partner (−1 HP);
  - relics apply to both, and an altar card goes to the presser;
  - the Fracture is sealed in co-op;
  - the two-player draft builds both decks; player 2 starts with their cards;
  - back in solo, the arrows move player 1 again.
- Screenshot: `docs/screenshots/13_coop.png`.
- `build/windows-run10/Bloodbound.exe`; the release export probe exits 0.
- **Not verified:** a physical second gamepad (pad device mapping is by connected-joypad order), and co-op feel and balance.

## Art pipeline test (2026-10-21)

- **Model:** `causeway_segment_4m.glb`, original Blender work, 1,936 tris, 4 materials.
- **Swap:** it replaces "Starting causeway appearance" through `ArtSwap.apply` (`scripts/art/art_swap.gd`). The greybox mesh is hidden and the collision is unchanged.
- `tools/run_checks.ps1 -Godot godot_console` → **SMOKE RESULT: 446/446** with art enabled.
- `godot_console --path . -s res://tests/shot_art_swap.gd`:
  - with art on: `model=true greybox_visible=false collision=(12, 1, 4)`;
  - with art off: `model=false greybox_visible=true collision=(12, 1, 4)`.
- Screenshots: `docs/screenshots/15_art_causeway.png` and `15_art_causeway_greybox.png`.
- **Not verified:** the Web export render of the GLB, and the `-- --greybox` command-line toggle (the code path is the same as `ArtSwap.enabled = false`, which was exercised).
