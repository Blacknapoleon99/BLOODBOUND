# BLOODBOUND as a full 3D platformer — design (draft for approval)

Date: 2026-10-22. Status: **waiting for approval; nothing built yet.**

## Why

After the playtest of build run17/18 the verdict was that the 3D run still plays like a side-scroller in a tube, and the user wants "a platformer that's fully 3D, like Super Mario."

The current state:

- **Halls:** phase 3 produced walled 10 m halls. They are the old side-view rooms extruded, so the route is still a line.
- **Movement:** the motor is a good base for responsiveness: instant start, vector steering, a designed jump. But it has no platformer moveset beyond jump and dash.

## Decisions taken (2026-10-22)

- **Level shape: Super Mario 3D World-style stages.** Each room becomes an open 3D stage chunk:
  - platforms float at many heights, with side paths and secrets;
  - there is still a clear direction toward the exit.
  The roguelike structure stays: shuffled rooms per act, the elite, the merchant, and the Bishop at the end.
- **Moveset:** all four groups:
  1. momentum run and skid turn;
  2. triple jump and long jump;
  3. wall jump and ledge grab;
  4. ground pound and backflip.
- **Climbing:** an Assassin's Creed-like climbing system, designed and written by us.
  - **Not** taken from decompiled Assassin's Creed code: that code is Ubisoft's copyright, the same reason as DEC-044. The design below is built from what Ubisoft and players describe publicly: climbable surfaces are marked by handholds, not every wall is climbable, and holding "up" climbs to the highest reachable point.
- **Combat stays:** sword combos, blood cards, lock-on, and every enemy (all already working in 3D).
- **Co-op stays deferred** until the game is complete.

## The moveset (our own numbers; tuned in playtest)

Every move is a state in a new `PlatformerMotor` (a component the player owns), with explicit entry rules. Animation is driven from these states, never from guesses.

| Move | Input | Feel target |
|---|---|---|
| Walk to run | stick | Speed builds 4 → 8.5 → 11 m/s over about 1 s of running straight. Sharp turns bleed speed. |
| Skid turn | stick reversed while running | About 0.18 s skid with dust, then launch the other way. Jumping out of a skid gives a **side flip** (higher, about 3.2 m). |
| Jump (variable) | tap or hold | 1.2 m on a tap, 2.3 m held (today's arc). Coyote time 0.1 s; jump buffer 0.12 s. |
| Triple jump | jump again within 0.15 s of landing, while running | 2.3 → 2.9 → 3.8 m. The third is a spin flip; the chain breaks if you stop. |
| Long jump | crouch (Ctrl / B) + jump while running | Low (1.0 m), fast and far (about 9 m). Keeps momentum. |
| Backflip | crouch + jump while standing | 3.6 m straight up and slightly back. |
| Crouch / slide | Ctrl | Crouch-walk; at speed it becomes a short slide under low gaps. |
| Wall slide → wall jump | push into a wall in the air → jump | Slide down slowly with a hand on the wall, then kick off away from the wall. Chain between facing walls. |
| Ledge grab | fall past a platform edge you're facing | Hang, shimmy left and right, pull up (jump/up) or drop (crouch). |
| Ground pound | crouch in the air | 0.25 s hang-spin, then slam straight down. Breaks cracked floors (the secret cellars). In combat it's an area hit plus a stagger. |
| Dash (kept) | Shift | The existing 0.6-blood teleport dash, now usable in the air once per jump. |

## Climbing (our design, AC-style)

- **What is climbable:** only **marked surfaces**:
  - stone walls with visible handholds (ledges, bricks, bone ribs);
  - ivy or chains;
  - every walkable edge (ledge grab).
  Plain walls are not climbable, so routes stay deliberate.
- **Detection:** each frame, shape casts from the chest and hands find the nearest **handhold** (an `Area3D` strip tagged `climb`). The level helpers place them automatically along ledges and on climb walls.
- **On the wall:** move in 8 directions between handholds (up, down, sideways, diagonals).
  - Climbing up a wall goes faster than crawling across it.
  - **Jump while climbing** leaps to the next handhold in the held direction, up to 2.5 m.
  - **Back + jump** ejects off the wall.
  - Reaching the top **mantles** onto the platform.
- **"Parkour up":** holding jump while running at a climbable wall runs up it, about 2 m, and grabs the top if it's in reach.
- **Stamina:** none at first. Add it only if playtests show climbing trivialises routes.

## Stages (3D World style)

- Rooms keep their ids, themes and difficulty, but each `_design()` is rebuilt as a **3D stage**:
  - a main route plus at least one alternative (a high route over the rafters, a climb route, a hidden path);
  - floating platforms reached from several angles;
  - climb walls; wall-jump shafts;
  - ground-pound floors (secrets);
  - moving and collapsing platforms used in 3D (orbiting, rising);
  - hazards that sweep in 3D (rotating blades, spike rings).
- **Room shape:** about 40–60 m long, up to about 30 m wide, with 15 m of vertical space. There are no tall side walls: pits and the abyss bound the play space, and stages float in the dark cathedral void.
- **Helpers grow 3D primitives:** `platform(x, z, w, d, top)`, `pillar`, `climb_wall`, `wall_jump_shaft`, `orbiter`, `rotating_blade` and more.
- **3D reachability validator:** a graph over platforms using the full moveset's reach:
  - the jump, triple jump, long jump, wall jump and climb edges;
  - designs must also stay completable with **basic jumps only**, so advanced moves are shortcuts, not requirements.
- **Collectibles:** Bone Shards on paths and on hard-to-reach spots, to reward the moveset. Secret reliquaries stay.
- **The opening:** rebuilt as a short tutorial stage that teaches run, jump, the triple jump, the ledge grab, climbing and the ground pound.

## Camera

The existing third-person camera, plus 3D World-style helpers:

- automatic swing behind the direction of travel when the player isn't steering it;
- higher framing over pits;
- the spring arm avoids walls;
- lock-on is unchanged.

## Animation (needed; this involves cost)

The hero has 13 clips today. The new moves need roughly 15 more:

- run fast, skid, crouch and crouch-walk, slide;
- triple-jump spin, long jump, backflip, side flip;
- wall slide, wall kick;
- ledge hang, shimmy left and right, pull-up;
- climb idle and climb moves in 4 directions, climb jump, mantle;
- ground-pound spin and land.

Options:

- **(a) Tripo animation credits**, rigged to the existing Bone Revenant rig: costs credits, so each batch needs your approval first.
- **(b) Procedural fallbacks** made in Godot (poses and IK on the current rig): free, but stiffer.

Recommendation: build the moves with procedural poses first, so they are playable and tunable, then buy real clips for the moves that feel right.

## Phases

Each phase ends playable, tested and committed.

1. **PlatformerMotor and moveset**:
   - momentum, skid and side flip;
   - triple jump, long jump, backflip, crouch and slide;
   - wall slide and wall jump;
   - ledge grab;
   - ground pound.

   Built and tested in a new **movement playground** stage, with procedural placeholder poses.
2. **Climbing:** handholds, climb movement, climb jump, mantle and parkour-up, in the playground.
3. **Stage kit and validator:** the 3D primitives, handhold placement and the moveset-aware 3D reachability check.
4. **Rebuild the stages:**
   - the opening as a tutorial;
   - 10 rooms, the elite arena and the merchant stage as 3D World stages;
   - shard collectibles.
5. **The Bishop in 3D** (the old phase 4), in a stage-style arena.
6. **Animation pass** (real clips, with your approval for any cost), the camera helpers, and polish.

## Not in scope

- Online co-op.
- New enemies.
- Story.

## Left to the builder

- Exact tuning numbers; the table above is a starting point.
- Room-by-room layouts, within the rules above.
- How handholds look.
