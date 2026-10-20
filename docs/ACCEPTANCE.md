# Acceptance tests / verification policy

**Never pass this file by imagination.** Record actual steps, outputs and timestamps in `docs/TEST_RESULTS.md`.

## Baseline smoke

1. Fresh project opens in Godot 4.7 standard.
2. Launch `scenes/main.tscn`; camera frames the player and traversal corridor.
3. Press D, move right; press A, move left; in both cases player remains constrained to depth Z=0.
4. Jump with Space and land on a platform. Holding Space must not cause auto-bunnyhop every landing.
5. Fall through the gap: respawn at the safe start; no eternal fall or error.
6. Approach enemy from correct direction, press J in range: enemy disappears and HUD reflects defeat.
7. Stand at amber gate and press E: enter 3D arena; now W/S changes Z while A/D changes X. Press E again to return to the corridor with Z=0.
8. Reach exit after defeating enemy: victory message appears; R resets.
9. No script exception observed in the engine log.

## Future mechanic gates

- M1: measured coyote/buffer edge cases and repeatable airborne controls.
- M2: attacks only damage during active frames; invulnerability prevents repeated damage; enemy can die cleanly and respawn rules are explicit.
- M3: depth-axis boss attack collision works; avoiding telegraphed volume works; environmental destruction cannot permanently softlock player; defeat resolves.
- M4: each of three cards has demonstrable cost and effect. Test insufficient energy, target out of range, cooldown, invalid phase, and interrupt window.
- M5: shared HP/inventory persist across 2.5D/3D transitions; third-person enemy attacks work; camera never loses player; return does not clip into terrain.
- M6: clean win/fail/restart from menu, real Windows package, browser served via local HTTP with console checked, memory/performance numbers.

## What counts as evidence

- **Static:** source checked; syntax likely, cannot claim the game runs.
- **Headless import:** Godot parsed/imported resources; cannot claim inputs/UI worked.
- **Headless boot:** engine scene starts without headless errors; cannot claim it visually plays.
- **Visible manual:** observed camera, interaction and controls; include screenshot/video if possible.
- **Automated gameplay:** scripted test executes state/action and asserts results; record executable version and reproducible command.
