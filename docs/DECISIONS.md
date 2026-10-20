# Architecture decisions

## DEC-001 — Godot 4.7 with GDScript / Compatibility

Reason: human-readable scenes and scripts suited to agentic editing, native 3D physics and camera control, reasonably straightforward browser/WebGL2 export. Unreal would be more demanding for this lightweight prototype. Revisit only after real browser/performance benchmarks.

## DEC-002 — Gameplay first, external models later

Tripo/Blender pipeline is designed, not run. Placeholder assets enable continuous progress even with no external API access or budget.

## DEC-003 — Arena uses shared player

2.5D side view and 3D arena will use the same body/health/combat identity, with different movement constraints and camera modes.

## DEC-004 — Jev AI identity pending

No uniquely verified integration endpoint found at packaging time. Ask the user for the official service link before connecting it.
