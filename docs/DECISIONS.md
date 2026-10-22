

## DEC-046 — Full 3D phase 3: the map's rooms as 3D halls (2026-10-22)

- **A separate 3D run, for now.** The main menu's "Start 3D Run" (`RunState.full_3d`, solo) plays the same draft, seeded map and rooms in 3D. The side-view game stays the default until the 3D game is complete; both share every room script.
- **One design, two builds.** `Lane.full_3d` is set before the level builds, and `LevelSection` helpers read it:
  - each room becomes a hall 10 m deep (`Lane.DEPTH_3D`) with tall side walls (you fall into pits, never off the side);
  - floors, slabs, movers, cracked floors, ambush walls and checkpoint triggers span the hall;
  - floating ledges are 4.5 m deep and zig-zag ±2.5 m from the centre, so every climb is aimed;
  - enemies, spikes and levers on a ledge sit on its actual depth;
  - floor spikes become a bed across the hall; pendulum blades become scythes as wide as the hall.
- **3D reachability.** Platforms record their depth. `can_jump` measures the planar gap between surfaces with the 3D jump (2.3 m apex, 0.43 s rise with the hang, 0.27 s fall; 4.5 m safe reach on the level against 5.1 m in the side view). All 12 rooms pass.
- **Ambushes in 3D** trigger for the free-moving player and spread their foes across three depth lanes. Side-view ambushes still ignore a 3D player (the Reality Fracture), and the reverse holds too.
- **The opening** becomes a walled hall too. Its soldier fights in 3D, and the Reality Fracture is closed in the 3D run.
- **Bishop hand-off (until phase 4):** at the Pursuit Approach the run switches to the side view:
  - the player locks to z = 0 and the side camera and card aim take over;
  - a gate closes behind you, because the zig-zag ledges are off the z = 0 line;
  - later enemies spawn plane-locked.
- **Art:** the 4 m causeway floor tiles would cover only part of a 10 m hall, so the 3D run keeps greybox floors for now.
- **Tests:** 12 new `_m24` checks (495/495). **Build:** `build/windows-run17/Bloodbound.exe`.

## DEC-047 — One title menu: Play and Co-op (2026-10-22)

- **Playtest:** the menu had too many confusing entries. The title now offers only **Play**, **Co-op (2 players)**, **Settings** and **Quit**.
- **Play** starts the solo run in full 3D (`RunState.full_3d`). The side-view solo start and the 3D prototype room are no longer offered to players.
- **Co-op** still runs on the side-view build: 3D co-op (one shared camera plus online) waits until the game is complete.
- The side-view build stays in the code: co-op and the Bishop (until phase 4) still use it, and so do the scripted checks.
- The export probe's movement check now accepts movement in any direction (in 3D, D strafes). Tests 497/497; probe 12/12; build `build/windows-run18`.

## DEC-048 — Hero animation follows the real jump; no side-view backdrop in 3D (2026-10-22)

- **Playtest:** "the character gets stuck in animations sometimes". Measured from a scripted 3D run (animation state logged every 3 frames). The causes are the clips:
  - Tripo's `fall` ends with the body collapsing onto the ground (hips 0.53 → 0.16 m after 1.2 s). Looped as the air pose, it dropped the hero into a lying pose in mid-air.
  - `jump` is four hops in a row. A 0.6 s slice played in 0.45 s, so a landing showed in mid-air.
  - `dive` (the dodge) ends face-down on the floor.
- **Fix:** `ArtAnimator._hips_span` reads each clip's phases from the hips' height:
  - the fall loop plays only its airborne first 1.13 s;
  - the jump plays one hop's takeoff in 0.22 s;
  - the dodge plays the dive's leap, not the faceplant.
- **The air pose follows whether the hero is really airborne** (rising or falling, after a 0.08 s grace), not only falling faster than 1 m/s, and landing eases straight back into locomotion.
- **3D run:** the side view's painted backdrop (distant silhouettes, the Reality Fracture's amber gate) is no longer built.
- Tests 498/498; probe 12/12; build `build/windows-run19`.

## DEC-049 — 3D platformer phase 1: the PlatformerMotor moveset (2026-10-22)

- **Design:** `docs/superpowers/specs/2026-10-22-3d-platformer-design.md`, approved. It calls for 3D World-style stages, a Mario-style moveset, and our own climbing (phase 2).
- **`PlatformerMotor`** (`scripts/player/platformer_motor.gd`) drives the player whenever a third-person camera does. The side-view game is unchanged.
- **Every move is an explicit state:** GROUND, AIR, SKID, CROUCH, SLIDE, WALL_SLIDE, HANG, PULL_UP and the POUND states, each with a jump kind. Animation and tests read the state.
- **Moves and measured numbers** (from the permanent `_m25` checks):

  | Move | Measured |
  |---|---|
  | Momentum run | 8.5 → 11 m/s after about 1.2 s running straight |
  | Skid on reversal at speed (+ side flip out of it) | 3.3 m |
  | Triple jump (jump again within 0.15 s of landing while running) | 2.0 / 2.6 / 3.4 m in the test; about 2.2 / 2.8 / 3.7 m held |
  | Long jump (run, Ctrl, Space) | 9.1 m far, 1.05 m high |
  | Backflip (stand, Ctrl, Space) | 3.7 m |
  | Crouch | collider 1.7 → 1.0 m; won't stand up under a ceiling |
  | Slide | passes under a 1.2 m slab |
  | Wall slide, then wall kick | slide capped at 3.5 m/s; 6 kicks climb a 10 m shaft |
  | Ledge grab (hang, shimmy, pull up / drop) | grabs only static geometry; pull-up checks for standing room |
  | Ground pound (Ctrl in the air) | 0.28 s spin, then a slam: a 2 m area hit, and it smashes cracked floors outright |
- **The dash stays.** No swings while hanging, wall-sliding or pounding. Swinging or dashing stands you up.
- **Controls:**
  - Crouch is new: Ctrl or C, gamepad LB, P2 numpad 0.
- **Procedural poses** (placeholder until real clips), built on the model's rest transform with the pivot at the body's centre:
  - the triple jump and pound flip forward, the backflip flips back, the side flip rolls;
  - the long jump dives forward;
  - the skid and slide lean back, the crouch squashes.
- **Movement playground** (`scenes/playground_3d.tscn`, F1 on the title screen; developer shortcut, not in the menu). One station each: momentum strip, 3.4 m tower, 8 m long-jump gap, wall-kick shaft, ledge wall, slide tunnel, pound floor.
- The old "reversal ≤ 0.20 s" check becomes "a reversal skids and relaunches ≤ 0.30 s": the skid is the design.
- **Not done:** real animation clips (the hang has its arms down), climbing (phase 2), and stages built for the moves (phases 3–4).

## DEC-050 — 3D platformer phase 2: climbing (2026-10-22)

- **Our own AC-style climbing.** It is written from scratch, from the public description: marked surfaces only, deliberate routes, and up to climb to the top. No decompiled code was used (see DEC-044).
- **What climbs:** `ClimbWall` (`scripts/level/climb_wall.gd`), a block in group `climbable`. It carries staggered bone handholds on its four sides (one MultiMesh) so climb routes read at a glance. Plain walls do not climb; you still wall-slide and wall-kick on those.
  - **Deviation from the spec:** the spec had separate handhold strips. Here the whole face of a marked wall is climbable, and the handholds are its visible marker. It is simpler to build stages with and feels the same in play. Strips can come later if routes need finer control.
- **Moves** (new `PlatformerMotor` states CLIMB and CLIMB_LEAP):
  - **Grab on:** jump into a climbable wall while pushing toward it.
  - **Move:** in 8 directions, relative to the camera. Toward the wall climbs up (2.6 m/s), away from it climbs down (3 m/s), and sideways crawls across (2 m/s).
  - **Edges hold you:** you can't climb past the side or the top of the climbable part.
  - **Space** leaps 2.1 m along the held direction (up by default); **back + Space** jumps off with a wall kick; **Ctrl** lets go.
  - **Mantle:** reaching the top with a walkable surface pulls you up onto it, using the ledge pull-up.
  - **Parkour up:** jumping into a climbable wall while holding jump keeps rising at 6.5 m/s for 0.35 s.
  - **No sword or dash while on the wall.**
- **Pose (placeholder):** the hero faces the wall, leans in, and sways hand over hand with the distance climbed.
- **Playground:** an 8 m climb tower with a top, a 3 m handhold wall for parkour-up, and a plain 8 m wall beside them that doesn't climb.
- **Tests:** 5 new `_m26` checks (512/512): climb and mantle onto the 8 m top; across 2.3 m, leap 2.1 m, kick off; crouch lets go; the plain wall doesn't climb; parkour-up onto the 3 m wall. Probe 12/12; build `build/windows-run21`.

## DEC-052 — Open courses in the 3D run (2026-10-22)

- **User direction:** "an open world platformer that's not streamlined", as "open courses in the run". The roguelike run stays (acts, seeded shuffled rooms, elite, merchant, the Bishop last); each 3D room becomes an open SM64-style course.
- **One design per view.** Each room keeps its side-view `_design()` (co-op, the Bishop hand-off and the scripted side checks still use it) and gains a `_course()` the 3D run builds instead. The side view is unchanged.
- **Course shape:** 44–64 m long (the merchant's 30 m), 24–39 m across, 5–13 m of height, no walls, floating in the void. Rooms still chain along X: an 8 m-deep entry pad (local x 0–10) and exit pad (last 8–12 m, with a glowing exit arch), tops at y = 0. Everything else spreads out in depth, kept clear of the pads' first 10 m.
- **Three routes per room** (36 in all), e.g. ground / high / climb, ferry / carousel / tower, fight / rim / gallows. At least one is basic-jumps-only in every room (most have two or three), and the climb and kick routes are the shortcuts. Side areas hold ground-pound cellars, perches and loose Bone Shards.
- **Course kit** in `LevelSection`: `pads`, `plat`, `pillar`, `wall3`, `climb` (ClimbWall), `kick_shaft`, `lift` (3D or rising mover), `orbit` (new `OrbitingPlatform`), `crumble`, `cellar` (6×6 dais over a pound-able niche), `shard` (new `ShardPickup`), `spike_bed`, `blade` (sized/rotated pendulum), `foe`, `arena`, `lever`, `hint`, and `route(tag)`.
- **Validator** (a graph over platforms with x, z and top): the exit must be reachable with basic jumps alone (the existing 2.3 m / 0.43 s / 0.27 s jump at 75% safety). Each declared route must reach it on its own platforms plus the pads, with advanced moves allowed: climbs, kick shafts, triple jump or ledge grab ≤ 3 m up, long jump ≤ 7 m. The pads alone must never connect (no single corridor), and every shard and reliquary must stand on a reachable platform.
- **Ambushes become arena rings** (12+ bone wall segments round the fight) instead of two walls across a hall. Ring foes are leashed to the ring's centre within the arena floor. The elite's ring is wider than its floor, so every approach seals the fight; the Gravewarden's reliquary rises on its floor.
- **Foes stay on their platforms:** `foe()` leashes each one inside its platform (wraiths fly: 10 m).
- **Falls:** in the 3D run you land back on the last **safe ground** for 1 HP. Safe ground is flat, static, not crumbling, breakable, moving or spiked, 1 m from every edge, and sampled 4×/s. With a fight in progress, no safe spot yet, or in the side view, the checkpoint respawn applies as before.
- **The opening:** no side walls. `OpeningGrounds` floats 7 practice stations off the causeway, each with a carved hint and a reward: jump, triple jump, long jump, ledge grab, climb, ground pound, wall kick. They are kept away from the portcullis.
- **Merchant** is 30 m wide in 3D (26 m in the side view).
- **Tests** (523/523): 11 new open-course checks:
  - routes, no corridor, size, reachable rewards, foes on their platforms, rings;
  - the opening, the E1 ring, shard pickup, safe-ground rule, fall to safe ground.

  Updated: the 3D "zig-zag ledges" check is now "completable and over 24 m across"; "floor spikes span the hall" is now "spike beds lie on their walkway"; the 3D ambush is now entered at its ring.
- **Dev tools:** `tools/dev/room_stats.gd` prints every course's validator view; `tools/dev/shot_courses.gd` captures overviews (visible window).
