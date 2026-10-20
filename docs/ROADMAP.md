# Milestone roadmap — track evidence, not promises

This list reflects **planned** work. Mark `[x]` only after tests recorded in `docs/TEST_RESULTS.md`.

## M0 — Verify included greybox
- [x] Godot 4.7 editor opens this exact project without parse/import failures. *(2026-10-20, TEST_RESULTS M0)*
- [x] Game launches visibly and controls (A/D, Space, J, E, W/S in arena, R after victory) behave as described. *(2026-10-20, TEST_RESULTS M0)*
- [x] Gap death resets player to a safe location. *(2026-10-20, TEST_RESULTS M0)*
- [x] Agent documents platform, engine version, tests and observed results. *(2026-10-20, TEST_RESULTS M0)*

## M1 — Platformer quality
- [x] Dedicated input map / rebinding-ready input abstraction. *(2026-10-20, TEST_RESULTS M1)*
- [x] Coyote time, jump buffer, variable jump height, acceleration and air control. *(2026-10-20, TEST_RESULTS M1)*
- [x] Dodge with clear invulnerability semantics. *(2026-10-20, TEST_RESULTS M1)*
- [x] At least one solid checkpoint and stable death/respawn. *(2026-10-20, TEST_RESULTS M1)*
- [x] One coherent traversal route, no softlocks. *(2026-10-20, TEST_RESULTS M1)*

## M2 — Combat
- [ ] Modular hitbox/hurtbox/health/damage interface and state-driven attacks.
- [ ] One real mobile enemy AI with readable telegraph, contact damage, damage reaction, defeat.
- [ ] Blood, hit effects and optional reduced-gore switch.

## M3 — Hollow Bishop boss
- [ ] Giant true 3D background presence.
- [ ] At least two distinct, readable, damaging attacks traveling into the player plane.
- [ ] One attack temporarily or permanently modifies traversable geometry with recoverable path.
- [ ] Boss phases, vulnerability window, HUD, defeat and restart.

## M4 — Cards
- [ ] Cards defined via Godot Resource data.
- [ ] Blood energy cost, recharge, target legality, cooldown, hand UI.
- [ ] Blood Spear actually damages exposed boss target.
- [ ] Grave Shield blocks an attack category.
- [ ] Ritual Chains interrupts an interruptible boss animation.
- [ ] Invalid activations cannot spend energy or apply effects.

## M5 — Real third-person arena
- [ ] Smooth mode/camera transition with shared player state.
- [ ] Free X/Z character locomotion, dodging, facing and depth-safe combat.
- [ ] Enemy encounter with win/exit and return to correct 2.5D location.

## M6 — Vertical slice and shipping paths
- [ ] Main menu, settings, pause, checkpoint, progression, 5–10 minute beginning-to-end flow.
- [ ] Windows test build and at least one real browser compatibility/export smoke test.
- [ ] Accessibility settings for gore/shake; performance measurements, no fatal logs.

## M7 — Production art integration
- [ ] Asset manifest and audited provider licensing.
- [ ] One approved Tripo-generated/other externally sourced model integrated through Blender to GLB and Godot.
- [ ] Swappable assets with preserved skeleton/scale/collisions; documented model performance costs.
