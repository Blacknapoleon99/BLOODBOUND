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
