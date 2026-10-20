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
