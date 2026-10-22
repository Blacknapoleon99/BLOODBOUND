

## Full 3D phase 3 — rooms as 3D halls (2026-10-22, build run17)

- `tools/run_checks.ps1 -Godot godot_console` → **SMOKE RESULT: 495/495** (483 earlier checks, all still passing, plus 12 new `_m24` checks):
  - 3D validator: planar gaps count;
  - all 12 rooms are completable with the 3D jump, and the ledges zig-zag;
  - a seed-77 3D run builds 8 halls with the third-person camera, and the opening soldier is unlocked;
  - every room's entry has solid floor off the centre line;
  - a hall wall stops a sideways run (z 4.65 of 5.0);
  - floor spikes span the hall;
  - a 3D ambush seals the hall with foes in 4 depth lanes, and clears;
  - the Pursuit Approach hands over to the side view: z = 0, side camera, card aim, rear gate, plane-locked spawns;
  - the next side-view run is side view again.
- Screenshots (not committed): the opening, Crypt Stairs and Blade Corridor as walled halls (pendulum scythe and spike bed visible).
- Export: `build/windows-run17/Bloodbound.exe`, probe **12/12**.
- **Not verified:**
  - A hands-on 3D playthrough of every room: the jumps are proven by the validator, not by playing them.
  - How the corridor rooms feel to play: they keep their side-view layouts, with depth added only through zig-zag ledges and spread enemies.
