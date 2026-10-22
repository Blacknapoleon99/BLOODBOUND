# Full 3D conversion — plan and scope

The user decided to rebuild BLOODBOUND as a full 3D action platformer. This plan sizes that, lists what carries over, and sets the order of work. Nothing is converted until the user approves it.

## How hard is it?

Medium-large, but far from a restart. The project was built 3D under the hood: CharacterBody3D, 3D physics, 3D models. The 2.5D part is a set of rules that lock everything to one line (Z = 0) and read only the x axis. The optional Reality Fracture arena already runs free X/Z movement and combat, which proves the core works in 3D.

Inventory (2026-10-22, ~13k lines of GDScript plus ~3k of tests):

| Area | Lines | 3D impact |
|---|---|---|
| Combat contracts (health, hitbox, hurtbox, melee phases, damage, strike zones, hit feedback) | ~550 | **Keeps.** Already 3D volumes; melee hitboxes already place along a 3D facing. |
| Cards, relics, items, Armory, run state, profile, shop, shards | ~1,900 | **Keeps.** Card targeting becomes "nearest/locked target in range". Card *effects* that assumed a line (Ossuary Bridge, Shadow Step's direction, Grave Hook's pull) get small 3D updates. |
| UI, menus, draft, HUD, audio, settings | ~1,800 | **Keeps.** The HUD gains a lock-on marker; co-op may become split-screen. |
| Art: models, animator, sword, cloth | ~800 + assets | **Keeps.** The animator already uses ground speed, which works the same in 3D. Facing becomes a full yaw. |
| Player controller (2.5D motor, Z lock, x-facing) | ~580 | **Rewrite movement and facing** (keep jump, dodge, combo, stun, shield logic). Adds camera-relative movement and lock-on. |
| Camera (side view) | ~150 in main | **Replace:** a third-person camera with collision, lock-on framing, and per-room cinematic angles where useful. |
| 8 enemy types' movement and AI (x-only chase, x bounds, x leash) | ~1,800 | **Rework movement:** chase on X/Z with NavigationAgent3D, bounds become areas, and "facing" becomes yaw. Attack logic, telegraphs and poise keep. |
| Hollow Bishop and its attacks | ~1,300 | **Redesign around a 3D arena:** the slam targets a marked ground circle (its real arm reaches in 3D), sweeps and beams cross the arena floor, lances rain at positions. Phases, the secondary channel and voice keep. |
| Levels: opening, 12 rooms, hazards, ambushes, secrets, shortcuts, merchant, layout shuffle | ~2,000 | **Rebuild geometry as 3D spaces.** The shuffle, room contract, checkpoints, ambush waves, secrets and shortcuts keep. Each room becomes a 3D layout (paths, ledges, pits, verticality). The reachability validator gets a 3D jump model. |
| main.gd level rules (respawn, interactions, co-op leash, camera, offsets) | ~1,300 | **Partly rework:** the camera, leash and x-based triggers become area triggers; the rest keeps. |
| Tests (gameplay smoke, 452 checks) | ~3,000 | **About 40% rewrite.** The checks that drive x positions and side-view assumptions change; data, cards, items, relics and shop checks keep. |

**Rough share:** about 60% of the code carries over unchanged or nearly unchanged, and about 40% is rewritten or reworked.

## Decisions (made by the user, 2026-10-22)

- **Camera: A, third-person orbit camera with lock-on.**
- **Co-op: postponed.** Not converted in these phases. When it returns (after the game is complete) it will be **one shared camera + online co-op**. The local co-op code stays in the repo but isn't ported now.

## Options that were considered

1. **Camera style.** This decides the controls and level design:
   - **A. Third-person orbit camera** behind the player, mouse/right-stick look, with lock-on (Souls-like, the strongest "3D action" feel). *Recommended* for a melee/boss game.
   - **B. Fixed three-quarter action camera** (Hades/Diablo-like). Simpler controls with no camera fighting, but less "platformer".
   - **C. Over-the-shoulder,** tighter and more cinematic. It's harder for platforming and for reading crowds.
2. **Co-op camera.** With an orbit camera, two players need **split-screen**. Alternatively, keep one shared camera, which works best with option B.

## Phases (each ends playable, tested and committed)

1. **3D core (prototype room):** the new player controller (camera-relative run, jump, dodge, combo), third-person camera with collision, and lock-on (nearest, cycle, break). A test room with the soldier. *Goal: it feels right before anything else moves.*
2. **Enemies in 3D:** NavigationAgent3D chase, attack arcs and spacing for all 8 types, plus the Gravewarden. Telegraphs shown as 3D ground decals. **Done 2026-10-22 (DEC-045, build run16).**
3. **Rooms in 3D:**
   - the LevelSection 3D helpers and a 3D reachability validator;
   - rebuild the opening plus the 10 rooms, the elite hall and the merchant as 3D spaces;
   - hazards, secrets, shortcuts and ambushes in 3D.
   **Done 2026-10-22 as walled halls from the same room scripts (DEC-046, build run17). The Bishop is still reached in the side view until phase 4.**
4. **The Bishop in 3D:** arena layout, slams with its real arm, attacks on the arena floor, phases, music and voice. Retune the fight.
5. **Systems and polish:**
   - card effects in 3D;
   - lock-on HUD;
   - menus;
   - rewrite the remaining tests;
   - performance pass and builds.

**Safety:** the current 2.5D game is tagged `v-2.5d-final` before Phase 1 starts. Every phase keeps the build green. If the 3D feel isn't right after Phase 1, we can stop there and lose nothing.

## Out of scope (unchanged decisions)

Online co-op (deferred until the game is complete). New content beyond what exists today. That comes after the conversion.
