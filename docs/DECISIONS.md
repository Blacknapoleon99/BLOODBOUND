

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

## DEC-051 — 3D movement: no more stuck poses; Super Mario 64 feel (2026-10-22)

- **Playtest:** "the character still gets stuck in a pose and slides". Written from the prose spec `docs/superpowers/specs/2026-10-22-movement-reference-spec.md` only (clean room, DEC-044); each cause in its §5.3 got a failing check first.
- **The contract:** the hero is always in exactly one motor state, and nothing moves the body unless the motor is in a state that represents it.
  - **Hits are a state.** `KNOCKBACK` ends any flip, slide, hang, climb or pull-up. It always restores collision, and a pull-up hit finishes on top. It decays the knock (6 m/s² while stunned, then 40.5 m/s² to a stand) and exits to ground or air.
  - **The dash and swings are states** (`DASH`, `ATTACK`). The player still drives their velocity, but `state_time` keeps ticking, so a pose can never freeze.
  - **The animator plays only `motor.anim_state()`.** Every state names a pose, and `ArtAnimator.HERO_POSES` maps each pose to locomotion, the air loop, or a held clip scrubbed by the move's own progress (metres shimmied or climbed, pull-up 0..1, seconds of knockback).
    - Hanging, climbing and pull-ups no longer show the fall loop; slides and skids no longer run their legs.
    - The takeoff clip no longer fights the flips.
    - The playback cap is now 3× (was 1.8×).
    - Enemies and the side view keep the old velocity path.
  - **Steep faces:** a face too steep to be a floor (50–73°), or a default floor above 38°, is a `SLOPE_SLIDE` instead of an endless AIR or POUND_FALL pose.
  - **Climbing** lets go when no climbable wall is left under the hands.
- **SM64 feel** (hero-scaled numbers, all named consts in `PlatformerMotor`):
  - **The run follows the facing.** A forward speed runs along a facing that turns at 6 rad/s (344°/s). A 90° turn takes 0.27 s, and velocity stays within 0° of the facing; it was up to 71° before. From a standstill the hero faces the stick at once.
  - **Squared stick:** half tilt walks at 2.70 m/s (it was 4.25).
  - **Acceleration curve:** an instant 2.8 m/s first step, then 11.1 − 0.8·v m/s². That gives 8.5 m/s in 0.83 s and 95% of the new 10.8 m/s top in 1.40 s. The 8.5 → 11 boost is gone; the curve's slow tail replaces it.
  - **New states:**
    - `BRAKE` (stick released at ≥ 5.4 m/s: 40.5 m/s², stops in 1.53 m / 0.27 s from 10.8);
    - `DECEL` (slower: 10 m/s², walk cycle winding down);
    - `LAND` (0.13 s; 0.2 s after a long jump; 0.3 s after a bonk; skipped for step-downs under 0.1 s of air).
  - **Turnaround skid** at > 100° and ≥ 5.4 m/s: it brakes at 40.5 m/s² and walks off at 2.7 m/s. Side flip 3.33 m.
  - **Jump chain window 0.25 s** (was 0.15). The triple needs > 6.75 m/s. Jumps keep 80% of forward speed.
  - **Air control:** the facing stays fixed in the air. The stick changes forward speed at 15.2 m/s² (drag 3.5 m/s²). Pulling back stops at −5.4 m/s at most; holding back measured −3.5 m/s, so no U-turns. Sideways drift is at most 3.4 m/s and doesn't accumulate.
  - **Bonk:** hitting a wall head-on (±45°) faster than 5.4 m/s without pushing into it, or during a long jump, bounces you back 2.7 m/s. A jump within 0.17 s still kicks off the wall. Pushing into a wall still wall-slides.
  - **No ledge grab out of the triple jump or the backflip.** A slow climb-up by stick toward the wall takes 0.8 s (allowed after 0.33 s of hanging); a jump climbs up in 0.3 s.
  - **Slope classes** come from collider metadata `surface` (`grip` / `default` / `slide` / `ice`; untagged means default).
    - Walking on a slope gains or loses 15 m/s² × sin(slope).
    - A slide gains 70 m/s² × sin(slope), with friction 0.92–0.98 per 1/30 s.
    - A jump off a slide is a weaker one, aimed downhill.
  - **Lock-on keeps the old vector steering** (strafing). A swing snaps the facing to the stick, so combat stays snappy.
  - Run lean and turn roll (up to 30°), eased at 170°/s.
- **Playground:** two new stations, a slope station (25° / 45° / 60°) and a bonk wall. The climb and parkour spots are closer, because the run now builds speed. Signs and HUD were updated, and the HUD shows the pose.
- **Tests:** 21 new `_m27` checks.
  - Changed on purpose (spec): `_m22` "full speed ≤ 0.12 s" became 0.5–1.2 s (measured 0.83); "90° turn ≤ 0.12 s" became ≤ 0.36 s; "reversal relaunch ≤ 0.30 s" became "walks off the other way ≤ 0.45 s"; "stop ≤ 0.5 m" became ≤ 1.6 m.
  - `_m25` shaft: "≥ 3 kicks" became "≥ 2": two kicks now reach the 10 m tops, where the hero catches the wall top as a ledge; before, six kicks reached 9.1 m.
  - Long jump now 10.2 m (was 9.1).
- **Not done:** real hang/climb/slide clips (the held-clip rows are placeholders); SM64 step-up and edge climb-down; dive/rollout; ground-pound rise; level geometry tagged with `surface`.

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

## DEC-054 — Level geometry look: gothic PBR stone, rubble undersides, props (2026-10-23)

- **User direction:** "better looking ground assets ... it needs to look like a triple-A platformer, Super Mario 64 but a gorey dark gothic 3D platformer". This pass covers the level geometry only. Sky, lighting and fog belong to the renderer pass; background scenery belongs to the backdrop pass.
- **Materials:** `GothicMaterials` (scripts/art/gothic_materials.gd) is a cached library of ShaderMaterials built from CC0 Poly Haven 1k scans in `assets/textures/gothic/` (about 13 MB; see CREDITS.md). Kinds: `floor`, `floor_cobble`, `floor_blood`, `pillar`, `wall`, `ossuary`, `climb`, `iron`, `cracked`, `breakable`, `rubble`, `column`, `rust`.
- **Box shader** (`scripts/art/shaders/gothic_block.gdshader`):
  - Planar mapping per face, in world metres, so any box size tiles. Movers map in local space so the texture doesn't swim.
  - The walkable top uses flagstone or cobble. The sides use masonry and fade to near-black with depth.
  - Fake bevel: the top rim and vertical corners tilt their normals and brighten.
  - Moss and blood creep from the edges and drip down the sides; cobble is wet.
  - Variation per block plus large-scale noise.
  - The box half-size comes from the corner vertices, so one shared material fits every size.
  - Plain GLSL only, so it works in Compatibility and Forward+.
- **Which helper gets which material:**
  - Each `plat` route gets its own top: route 2 is wet cobble, and about 20% of blocks are blood-stained. The exit pad is always bloody.
  - `pillar`: darker shaft. `wall3`: dark masonry. Cellar dais: ossuary.
  - `ClimbWall`: pale block, with the bone handholds unchanged so climbs still read.
  - Movers: rusted iron with an ember rim glow.
  - Collapsing slab: cracked bricks that flash red (a per-instance copy).
  - Breakable floor: red light in its cracks.
  - The exit arch is now blood-lit.
  - main.gd's causeway solids and the portcullis now use the library (`kind_for_label`).
- **Decor pass** (`GothicDressing.dress`, open courses and the opening grounds):
  - A faceted rock chunk hangs under every floating walkable block. Its depth is capped so it stays 2.6 m above anything below, and there is none where a wall runs down through.
  - About half of the platforms at least 3×3 m get one corner prop: a skull pile with bones, a candle cluster on a wax puddle, a broken column with a fallen drum, or a bent spear-topped iron fence.
  - Props are procedural meshes in one MultiMesh per part, seeded per room. They stay 1.7 m clear of checkpoints, pickups, traps, altars, chests, levers, foes, hints, rings and the exit arch.
- **Collision unchanged:** every helper still makes exactly the same bodies and shapes. Decor has no physics, and the route validator and tests are untouched.
- **Dev tool:** `tools/dev/shot_ground.gd` captures close views (visible window).
- **Not done:**
  - Real modelled trim and edge caps (the bevel is a shader trick).
  - Side-view backdrop materials.
  - Boss arena and Reality Fracture blocks.
  - Spike-trap and pendulum art.
- **Follow-up (after merging DEC-053/055):**
  - `GothicMaterials.standard(set, tint, scale, world)` is a textured triplanar StandardMaterial3D for props whose scripts animate their material, so telegraphs keep working: the spike plate's red pulse, the lever bridge's fade-in, the altar's spent glow, the chest's opened glow.
  - These now use the stone/iron/wood scans:
    - spike plates and spikes (rusted iron);
    - pendulum rod and blade (object-space iron, red edge glow kept);
    - lever (brass-tinted iron, glow kept) and its bridge (pale cracked stone, still fades in);
    - Bishop causeway slabs (flagstone; breakable slabs stay lighter than the solid ends) and their rubble;
    - blood altar (masonry; the bowl glow is unchanged);
    - merchant stall and reliquary chests (new CC0 `medieval_wood` set);
    - ambush bone walls (new `bone_wall` kind: local mapping for rotated ring segments, red-lit cracks).
  - Exit arch: `GothicDressing.exit_arch()` builds a carved pointed arch. It has plinths, piers, capitals, voussoirs, a skull keystone, a blood-red glowing inner moulding and a red torch light, and replaces the red box frame.
  - Hero readability: GothicEnvironment adds two short-range, shadowless lights that follow the player. A warm fill sits on the camera side and a cool rim behind. They use fast falloff, so the scene's mood is kept.
  - Dev tools: `tools/dev/audit_materials.gd` lists the remaining flat-material meshes in a 3D run. `shot_ground.gd` also captures each exit arch and the Bishop causeway.
  - Left alone: characters, the Reality Fracture (veil, ring, chapel), shard pickups, checkpoint banners and VFX.

## DEC-055 — The background world around the open courses (2026-10-23)

- **User direction:** a skybox, a world, backgrounds: "Super Mario 64 but a gorey dark gothic 3D platformer". The courses float in a void (DEC-052); now the void is a place. Decor only: no collision, no shadows, never in a course's play volume.
- **Three bands** (`scripts/level/backdrop_3d.gd` `Backdrop3D`, one per course, spawned by one line in `LevelSection.build()` (full 3D) and in `OpeningGrounds.build_grounds()`; the playground spawns one too):
  - **Near** (10-40 m past the course edge, tops below the course): clustered gothic pillars rising out of the abyss, loose masonry, a broken wall with a lit lancet per side, gibbet cages swinging on 40 m chains.
  - **Mid** (|z| ≥ 60 m, 60-200 m out): 3-4 drifting rock islands with ruined towers (procedural or Kenney Castle Kit), roofless chapels, dead trees and hanging cages; one big feature per room (titan ribcage / broken flying buttresses / ruined arcade); a bat flock (MultiMesh).
  - **Far** (`BackdropHorizon`, one per scene, follows the camera like a skybox of geometry): the colossal cathedral ~820 m ahead (+X, where the run heads) with a red rose window, lancets and chains holding its rock over the abyss; broken spires on floating rocks round the horizon; a titan carcass in the sea; two mountain rings; the blood sea (world-space noise shader, ember glints), a translucent mist layer, an additive sea-glow ring behind the mountains, rising embers.
- **Theme** by act (`BackdropKit.theme`): act 0/1 blood red, act 2 violet-crimson; the horizon re-themes to the room under the camera. Room ids seed the layout (stable per room).
- **Rendering:** every object is merged into one vertex-coloured mesh (one draw call each); custom fog-disabled shaders do their own distance haze, synced every 0.5 s to the environment's sky horizon / fog / background colour, so the far layers read in Compatibility and Forward+ whatever the lighting agent sets. A room's decor hides beyond 300 m (camera X). Measured at the opening (Compatibility, 1280×720): +25 draw calls, +82k primitives; ~8 ms build per room.
- **Sources:** procedural (original) + 9 Kenney Castle Kit pieces (CC0), credited in `assets/models/backdrop/CREDITS.md`. No paid generation.
- **Checks:** `tests/backdrop_check.gd` (5/5): one backdrop per course + opening, one horizon, no collision, no shadow casters, no vertex inside any course's play volume. Capture: `tools/dev/shot_backdrop.gd` (visible window, gameplay camera).
- **Headless** (tests/CI): the decor is built but not animated (no `_process`, no embers). The smoke check "a loose Bone Shard is collected by touch" waited 6 *process* frames, which only sometimes contain the 3 physics ticks the area needs (2/5 failures in isolation even without the backdrop); it now waits 6 physics frames.
- **Not done:** the sky itself (lighting/sky owner); per-room unique far landmarks; LOD impostors (not needed at current cost).

## DEC-053 — Forward+ renderer and the gothic full-3D look (2026-10-23)

- **User direction:** "Super Mario 64, but a gorey, dark, gothic 3D platformer" at AAA quality: a skybox, a world, background, atmosphere. Web is no longer the target.
- **Renderer:** desktop uses **Forward+** (`rendering_method="forward_plus"`). Web and mobile keep **Compatibility** through the feature-tag overrides `rendering_method.web` / `.mobile` (the Godot docs say Web can only run Compatibility). Those builds get the reduced look; the Forward+-only effects (volumetric fog, SSIL, SSAO) never switch on there. Shadows: 4096 directional atlas with soft filter quality 3, plus MSAA 2x and FXAA.
- **One module:** `GothicEnvironment` (`scripts/art/gothic_environment.gd`) builds the whole full-3D look. The 3D run (`main.gd`, full_3d only), the movement playground and proto_3d all use it. The side view and co-op keep their old flat lighting. ArtSwap skips its fill light and tonemap when it finds the gothic environment.
- **Sky:** `assets/shaders/gothic_sky.gdshader` is fully procedural:
  - a huge blood-red moon with maria and a halo;
  - drifting fbm storm clouds, lit at the rims from the moon side;
  - twinkling stars through the cloud gaps;
  - a crimson horizon band, and a dark abyss below the horizon with a faint ember glow.
  - The radiance pass skips stars and craters and uses fewer octaves. Radiance updates incrementally.
  - No HDRI was downloaded. Poly Haven CC0 remains an option.
- **The visible moon is placed apart from the light.** The moon disc sits about 12° up in the moonlight's azimuth, so the play camera keeps it in frame. The light itself comes from about 38° up, so the ground still gets a readable key angle and shadows.
- **Lighting:**
  - Moonlight is a rose key at energy 2.0 with 4-split PSSM shadows over 70 m (splits 0.08 / 0.22 / 0.5) and PCSS softness (`light_angular_distance` 0.6) on high.
  - A cool, shadowless fill light comes from opposite the moon, plus a cool ambient.
  - `GothicEnvironment.torch_light(pos)` returns a warm, flickering OmniLight3D for torches and candles.
- **Atmosphere:**
  - Fog: exponential depth fog plus height fog below y = -3. On high, volumetric fog (80 m) and an `AbyssFog` FogVolume that follows the camera under the courses add to it.
  - SSAO everywhere, and SSIL on high. SDFGI stays off (too costly for procedurally built courses).
  - Glow for the moon and embers. ACES tonemap, contrast 1.08, saturation 0.78, and a split-tone correction ramp (cold shadows, warm highlights).
  - Ash (900) and embers (140) GPU particles follow the active camera.
- **Quality preset:** `GameSettings.high_quality` is saved under `[graphics]` and toggled in Settings ("High graphics"). Low turns off volumetrics, SSIL, PCSS and the abyss volume, drops to 2 shadow splits, uses fewer particles and a 64 px radiance map. `GothicEnvironment.refresh_quality(tree)` applies a change live.
- **Measured** (RTX 5090, 1280×720, vsync off, `tests/shot_gothic.gd`):

  | Preset | 3D run | Playground |
  |---|---|---|
  | High | 440–630 fps | 400–1240 fps |
  | Low | ~520 fps | ~1500 fps |

  A mid GPU has not been measured yet.
- **Captures:** `tests/shot_gothic.gd` (visible window) writes `docs/screenshots/23_gothic_*.png` and prints the fps. Pass `-- <dir> low` to capture the low preset.

## DEC-059 — The hero's full range of motion: a real moveset and whole sword swings (2026-10-23)

- **User:** "make sure that our character has full range of motion ... it's currently stiff, the attack animations don't do a full motion". The hero had 13 Tripo clips; swings played a 0.75 s slice of `slash` squeezed into the attack, and hangs, climbs, slides, skids, flips and pounds were frozen placeholder frames (DEC-051).
- **Source:** 24 clips generated locally with NVIDIA Kimodo (**Kimodo-SOMA-RP-v1.2, NVIDIA Open Model License**; never the SMPLX model or UniMate), 4 takes each, picked from contact sheets. Credits: `assets/models/player/ANIM_CREDITS.md`; prompts, seeds and picks: `tools/kimodo/clips.json`.
- **Retarget (our own code):** `tools/kimodo/kimodo_to_hero.py` (numpy) transfers world rotations with a per-bone swing from the hero's rest to the SOMA T-pose, keeps the root in place (the motor moves the body), scales hips by leg length, grounds the toes, keeps the hero's sword-grip fingers and cross-fades loops; airborne clips keep the hips at rest height so flips turn about them. `build_hero_library.gd` writes `assets/models/player/hero_kimodo_anims.res`, which `ArtSwap` adds to the hero's AnimationPlayer. The Tripo GLB and its 13 clips are untouched; the cloth stays on the spring sim.
  - The Blockheads Blender retarget script was copied first, but running it was refused by this session's permission check, so it was replaced (not shipped). The Quaternius UAL itch.io route was also refused; no Quaternius files are used.
- **Attacks:** each combo step has its own whole clip (`slash_1`, `slash_2`, `slash_3`; heavy `heavy_overhead`). `ArtAnimator.attack_plan` lays the wind-up over STARTUP, the contact (the sword hand's fastest frame ± 0.06 s) over ACTIVE, and the follow-through over RECOVERY plus a 0.25 s visual tail that the next action interrupts; each segment has its own rate (≤ 4×; a wind-up too long for a 0.06 s startup starts part-way in). Upper-body layer while moving or airborne, full body standing; 0.18 s blend out. Gameplay timings, hitboxes and the motor are unchanged.
- **Moves (`ArtAnimator.HERO_MOVESET`):** combat stance when the sword is out; boost sprint blended over the run from 7.5 to 10 m/s; jump takeoff, front flip (triple), backflip, side flip (the clips do the rotation, the procedural flips are off), long-jump leap (plus the 45° dive tilt), wall kick, wall slide, ledge hang, shimmy (by metres), pull-up (by progress), climb (by metres), climb leap, crouch, slide, skid/brake, landing, ground pound spin/tuck/landing, knockback and bonk, dodge roll. Held clips use two cross-faded slots, so pose changes never pop. Run lean/turn roll stay procedural. Side view and enemies keep their existing paths (the side-view hero gets the new swings and roll too).
- **Still weak:** Kimodo gave no real hanging take (the hang loop is a shimmy take, arms up, legs dangling), no feet-first slide (a low crawl-slide), a modest knockback stagger, and the fall loop stays the Tripo clip. Draw/sheathe, hurt (light), cast and death stay Tripo clips.
- **Tests:** `_m28` adds 5 checks (every motor pose maps to a real clip, 3 distinct combo clips, contact inside ACTIVE for all four attacks, and in play the light swing shows its contact during ACTIVE). DEC-048's air-pose check now reads the held-clip layer too, since the rising jump is a held clip. 549/549.
- **Captures:** `docs/screenshots/anim_attacks.png`, `anim_air.png`, `anim_wall.png`, `anim_ground.png` (studio sheets of the windows the game plays) and `anim_3d_combo.png`, `anim_3d_moves.png`, `anim_3d_wall.png` (in the playground).
