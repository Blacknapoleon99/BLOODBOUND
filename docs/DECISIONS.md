# Architecture decisions

## DEC-001 — Godot 4.7 with GDScript / Compatibility

Reason: human-readable scenes and scripts suited to agentic editing, native 3D physics and camera control, reasonably straightforward browser/WebGL2 export. Unreal would be more demanding for this lightweight prototype. Revisit only after real browser/performance benchmarks.

## DEC-002 — Gameplay first, external models later

Tripo/Blender pipeline is designed, not run. Placeholder assets enable continuous progress even with no external API access or budget.

## DEC-003 — Arena uses shared player

2.5D side view and 3D arena will use the same body/health/combat identity, with different movement constraints and camera modes.

## DEC-004 — Jev AI identity pending

No uniquely verified integration endpoint found at packaging time. Ask the user for the official service link before connecting it.

## DEC-005 — Input actions registered by `InputBindings`

Gameplay reads only action names (`move_left`, `jump`, `dodge`, …). `scripts/input_bindings.gd` registers keyboard and gamepad defaults at runtime, but only for actions that Project Settings does not already define. A rebinding menu can then edit `InputMap` directly, and editor-defined bindings always win. Keys use `physical_keycode`, so the WASD layout holds on non-QWERTY keyboards.

## DEC-006 — Automated input-driven smoke test as the gameplay gate

`tests/gameplay_smoke.gd` drives the real main scene with `Input.parse_input_event` and asserts outcomes. Every milestone extends it, and `tools/run_checks.ps1` runs it. This makes "playable" claims reproducible without an MCP or desktop-control dependency. It does not replace hand-play for feel.

## DEC-007 — Second causeway gap widened to 1.5 m

The starter's second gap was 0.5 m, narrower than the 0.7 m player capsule, so it was not a real hazard. Widening it gives the M1 checkpoint (on the broken span) a meaningful job.

## DEC-008 — Jev identified; not part of the asset pipeline (supersedes DEC-004)

The user identified "Jev AI" as TypeSafe AI's Jev (https://typesafe.ai/blog/introducing-system-one-models-and-jev). It is an early-access "System One" model that returns typed decisions with calibrated probabilities (classify, route, score, extract). It does not generate images, animation, 3D or audio. Access is API-only (docs.typesafe.ai, console.typesafe.ai), waitlisted, and billed per input token. The asset pipeline stays Tripo3D + Blender. Jev is not integrated. Any later experiment (for example enemy or boss decision-making) needs explicit user approval, because it costs money and sends data to a third party.

## DEC-009 — One MeleeAttack phase machine for every attacker

The player and the enemies share `MeleeAttack` (STARTUP → ACTIVE → RECOVERY) driven by `AttackData` resources. An enemy's telegraph *is* its STARTUP phase, so the visual warning and the real hit window cannot drift apart. Hitboxes compute knockback per target, pointing away from the attacker. Hurtboxes ask their owner's `is_invulnerable()`, so dodge i-frames and post-hit i-frames need no special cases. Hit feedback (spray, hitstop, shake) runs from `Hurtbox` through `HitFeedback`, which is presentation-only and respects `GameSettings`.

## DEC-010 — Enemies are leashed to their zone

Soldiers never move beyond `patrol_min/max_x ± leash_margin` and return home if knocked into a pit. The level exit depends on killing the soldier, so an enemy lost in a gap would softlock the run.

## DEC-011 — The Bishop is damaged only through what it pushes into the play plane

The boss stands at z = −22 and is never directly reachable. Every threat it makes (the slam hand, the lances) is telegraphed on the Z=0 plane first and is only dangerous on that plane. The Hand Slam leaves the hand lying on the causeway with an exposed stigmata hurtbox: this is the weak-point window, and later cards (M4 Blood Spear) can target the same hurtbox. Phases follow HP thresholds only (12 → ≤8 → ≤3), so debug HP changes drive the same transitions as real hits.

## DEC-012 — Causeway destruction is state toggling, with rules that guarantee a route

`BreakableSegment` disables collision and drops the visual; there are no physics debris. `BossArena` never breaks the entry or end segment, never breaks next to an existing gap (so every gap is 4 m, under the ~5.6 m running jump), and caps breaks at two. Each gap has a rubble ledge 1 m down as a fallback. Segments reknit after 14 s and on any death or fall.

## DEC-013 — Attack input buffer

An attack pressed while another is still playing is kept for 0.15 s and fires on the first free frame (latest press wins). Without it, hitstop stretches attacks by a few frames and quick follow-ups were silently dropped (found by the M3 boss test).

## DEC-014 — Cards validate before they touch anything

`CardSystem.play_slot` checks, in order: card present → player can act → cooldown → target legality (weak point exposed and in range / boss action interruptible) → energy. Energy is spent, the cooldown starts, the card is discarded and the effect applies only after every check passes. Failures return a reason (`empty`, `blocked`, `cooldown`, `no_target`, `out_of_range`, `energy`) that the UI flashes on the slot. Effects reuse the combat contracts:
- Blood Spear is a real moving `Hitbox`, so a weak point that closes mid-flight rejects it.
- Grave Shield uses a `try_block` hook on `Hurtbox` that filters by damage category (`heavy`).
- Ritual Chains calls the Bishop's `interrupt_with_chains`, which is only legal before the slam's descent.

## DEC-015 — Seeded deck with stable slots

`CardDeck` is a draw/hand/discard model with its own seeded RNG (Fisher–Yates). A played card's slot refills from the draw pile, and the discard pile reshuffles when the draw pile is empty. With the three-card starter deck, each card returns to its own slot, so hand positions stay stable. The seeded deal currently puts Grave Shield on 1, Ritual Chains on 2 and Blood Spear on 3. Larger decks work unchanged when deckbuilding arrives.

## DEC-016 — Reality Fracture as a level node with a fade-covered mode swap

`RealityFracture` owns the free-movement chapel, its guardian, the return portal and the transition. Entering and exiting run as a timed sequence: fade to black → teleport and flip `in_3d_mode` (camera snaps while the screen is black) → fade in, while the camera eases into its framing. Player input is frozen throughout, so nothing can act mid-teleport.
- HP, blood energy, card hand and cooldowns carry across with no copying, because the same player node crosses over.
- The return point is wherever the player pressed E, on Z=0.
- Death inside expels the player there at full HP and resets the guardian, so the encounter can always be retried.
- Clearing it heals the player, grants +3 blood and seals the fracture.
- A dark veil behind the chapel hides the main level.

## DEC-017 — 3D combat reuses 2.5D combat; two additions only

The guardian is a stock Plagued Soldier with `plane_locked = false`. It is leashed by radius around its home instead of by an X range. Hitboxes, telegraph markers and knockback already worked on X/Z. The player gains a soft lock-on in 3D only: an attack with no movement input turns toward the nearest living enemy within 3.5 m. In 2.5D, facing remains fully manual.

## DEC-018 — Pursuit Approach before the boss arena

The vertical-slice spec calls for collapsing/moving sections and a pursuit sequence, so a 40 m approach was inserted between the portcullis and the arena:
- three collapsing slabs over a pit;
- a moving "bone ferry" across a 10 m gap;
- the Bishop rising early into a PURSUIT phase, where it follows the player and throws single telegraphed lances every 3.2 s. In PURSUIT it cannot be damaged and shows no HP bar.

Reaching the arena calls `begin_fight()`. The arena moved by +40 m; boss tests express positions through `_bx()`, relative to the arena's real left edge, so future layout moves don't break them.

## DEC-019 — Export probe for packaged builds

`--script` is editor-only, so packaged builds cannot run `tests/gameplay_smoke.gd`. `ExportProbe` is a dormant node that the title screen adds only when it sees `--export-probe` (desktop user argument) or `?export-probe` (web URL). It drives real input through the packaged build and exits 0 or 1. Normal players never trigger it.

## DEC-020 — Settings persistence and test isolation

`GameSettings` saves to `user://settings.cfg`. `persistence_enabled = false` makes the default path a no-op, so automated tests never read or overwrite a player's real settings; the round-trip test uses its own file. The pause menu pauses the whole tree; the menu itself and the settings panel run with `PROCESS_MODE_ALWAYS`.

## DEC-021 — Damaging abilities: target any enemy, buffer through hitstun, Bishop retuned (playtest 2026-10-20)

User playtest: "the damaging abilities don't seem to work". Diagnosed with `tests/diag_abilities.gd`, which plays with real keys and the AI on. Three root causes:
1. Blood Spear only targeted the Bishop's exposed stigmata, so it refused (`no_target`) against every ordinary enemy. It now uses `Targeting.ENEMY`: the nearest living enemy hurtbox within range, with exposed weak points preferred. In 2.5D, targets must be within 2.5 m of the play plane. (New enum values go at the end, because `.tres` files store the integer.)
2. Cards and attacks pressed during hitstun were dropped. The most natural moment to spear, right after the slam lands on you and opens the stigmata, failed as `blocked`. Both are now held until the stun ends, plus 0.15 s.
3. Tuning: optimal melee did about 6 damage per weak window against 12 HP, so the Bishop died in about 2 windows (11 s). New values: Bishop 36 HP (Collapse ≤24, Covenant ≤10), 0.5 blood per melee hit, Blood Spear 3 damage. A test bounds optimal melee to at most 1/5 of the Bishop per window.

Readability: enemy hits show floating damage numbers (gold for weak points), and a refused card prints the reason in the HUD ("Blood Spear: no enemy or exposed stigmata within 14 m").

## DEC-022 — Mouse play for cards: click a card, then click the target

Second playtest report: the cards show READY but say "no target", even though the player clicked the target. Root cause: the game had no mouse input at all (no `InputEventMouse*` handling). Cards were keyboard-only and auto-targeted, so the playtester's clicks did nothing.
- `CardHandUI` slots are clickable. `CardTargeting` arms enemy-targeting cards: the slot gets a white outline and "AIM: CLICK TARGET", and the cursor becomes a crosshair.
- The next left-click picks the enemy hurtbox nearest the cursor (within 90 px on screen), and `CardSystem.play_slot(slot, chosen_target)` validates that exact target. Self and telegraph cards play on click.
- Right-click, clicking the same card again, or 8 s idle cancels. A miss keeps the card armed and says so.
- Clicking the Bishop's body explains that only the stigmata can be wounded. Clicking a sealed stigmata returns the new reason `not_exposed`.
- Keys 1–3 keep auto-targeting (nearest enemy, exposed weak point first).
- Testing: Godot's headless display server drops mouse input, so headless runs route clicks to the same signal and handler; the visible run uses real mouse events.

## DEC-023 — Combat feel: 3-hit combo, hold-to-chain, auto-attack, poise, hit reactions (playtest 2026-10-20)

Playtester: melee too slow, wants an auto/filler attack to earn blood, and hit reactions on both sides.
- **Light combo:** `player_light` → `player_light_2` → `player_light_finisher` via `AttackData.next_combo`. Pressing again, or just holding J, within 0.35 s chains the next step. Each light step takes 0.28 s; the finisher takes 0.44 s, deals 2 damage and 2 poise.
- **Auto-attack:** `GameSettings.auto_attack`, default on, toggle in Settings. With no attack pressed, the player swings at the nearest hittable enemy hurtbox within 1.8 m and turns to face it, but never while moving away from it.
- **Lunge gating:** a swing doesn't lunge when an enemy body is within 1.3 m ahead. Lunging into the soldier triggered its contact damage, which broke the combo before the finisher (found by diagnostic).
- **Poise:** every hit flashes the soldier white and makes it flinch. Only breaking poise (3 points; light 1, finisher/spear 2, heavy 3) cancels its attack and staggers it. Poise refills after 1.5 s without hits, so combos can't stun-lock it. Soldier HP 3 → 6.
- **Player reactions:** a red flash, a recoil lean, and a red screen-edge vignette when hurt. Swings lean forward. The Bishop's stigmata flares white per hit.
- **Bishop HP 36 → 60** (Collapse ≤40, Covenant ≤18). Held-combo spam deals about 9 per weak window, and a test bounds that at ≤1/5 of max HP.
- The dormant Bishop is hidden until it rises; its sunk silhouette was poking into early shots.
- Tests disable auto-attack (`_test_defaults`), except in the checks written for it.

## DEC-024 — Roguelike run loop: draft, altars, eight cards (playtest 2026-10-20)

Playtester wants a roguelike side-scroller: choose cards before the run from a random offer, more cards, and more happening between the set-pieces.
- `RunState` (static): run seed, the drafted deck, and a seeded RNG for every offer in that run. `CardPool.offer()` gives a weighted sample without replacement, preferring cards not already owned.
- **Draft** (`scenes/draft.tscn`): three rounds of "pick 1 of 3"; the result is the starting deck. Start, Restart run (pause menu) and R after victory all begin a new run through the draft. Opening `main.tscn` directly (tests) uses the default three cards.
- **Blood Altars** (x 16.8 and 40.7) and a cleared Reality Fracture open `CardOfferOverlay`: pause, pick 1 of 3 or take nothing. The card is added at a random point in the draw pile. The hand stays 3 slots and rotates through the growing deck.
- **New cards:** Hemorrhage Pact (HP for blood; answers blood starvation), Epitaph (delayed spike, 4 damage, breaks poise), Ashen Choir (summoned shard phantom), Bell of Silence (cancels wind-ups, blocks new attacks for 4 s; the Bishop is always in reach), Transfusion (heal). New refusal reasons: `too_weak` and `full_health`.
- Player-facing reference: `docs/CARDS.md`.
