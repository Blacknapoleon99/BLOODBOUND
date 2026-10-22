

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
