# MASTER DEVELOPMENT MISSION — BLOODBOUND: THE HOLLOW COVENANT

## Executive mission

You are the lead game director, senior Godot engineer, technical artist, QA lead, and agent orchestrator. **Deliver a real, continuously playable original dark-fantasy 2.5D action-platformer prototype** that can later be upgraded using Tripo3D, Blender MCP, AI-generated animation/imagery, and professional assets. **Implement before polishing. Do not stop after writing plans.**

Reference concept: [Tidebreaker](https://wavedash.com/games/tidebreaker) — a 3D environment where primary player locomotion is locked to a 2D plane, with a large adversary behind the player sending attacks through the depth axis. Study it for broad mechanics only; **do not clone its code, proprietary assets, character designs, level topology, music, narrative, or distinctive artistic expression**.

## 1. Direction and identity

**Title:** BLOODBOUND: The Hollow Covenant (working title, renameable).

**Genre:** 2.5D action/horror platformer, dark fantasy, visceral melee, enormous cinematic boss confrontations, real-time tactical card abilities, and occasional third-person 3D arenas.

**World:** A medieval kingdom devastated by ritual corruption. Ruined Gothic villages, rivers of ash, crumbling fortresses, plague chapels, execution bridges, catacombs and desecrated cathedrals.

**Visual direction:** Dark desaturated stone and iron, crimson highlights, volumetric-looking fog (cheap compatible alternatives for web), silhouettes, strong depth, deliberate camera shake, eerie lighting. Gruesome monster anatomies and blood effects should remain legible rather than obscuring gameplay. A reduced-gore option is required in production.

**Pillars:** (1) precise responsive platforming, (2) readable, impactful combat, (3) world-scale background threats, (4) meaningfully integrated cards, (5) occasional perspective-breaking 3D fights, (6) a robust AI/artist asset pipeline.

## 2. Stack and engineering constraints

- Stable **Godot 4.7**, standard build, **GDScript**, 3D nodes and collisions.
- Prototype using the **Compatibility** renderer to keep a WebGL 2 browser path open; target Windows desktop first, then test web export. No assumption of WebGPU or perfect mobile compatibility.
- Use Godot scenes, script classes, signals, typed GDScript where practical, Resource data assets, composition over inheritance.
- Work with the included project; evolve it without destroying already functioning controls, state, or camera flows.
- Keep the player and enemies as 3D scene objects in both gameplay modes. Normal traversal is X/Y movement on Z=0; arena mode unlocks depth axis, changes input interpretation and camera.
- Frame-time goal: **60 FPS** on a representative midrange PC; provide actual measurements in later phases. Do not confuse a fast flagship GPU with a realistic baseline.
- External tools: **Tripo3D**, **Blender + Blender MCP**, optional **Jev AI** (exact provider/API to be verified), and any verified user-provisioned rigging, animation or texture tools. Review `docs/TOOL_INTEGRATIONS.md`.
- Orchestrate with **Claude Code or Codex**. Subagents may parallelize only non-overlapping modules; the leader always owns final integration.

## 3. First deliverable — 5–10 minute vertical slice

**Level: The Weeping Causeway**, a ruined bridge and cathedral approach.

1. Main menu with Start / Settings / Quit.
2. Begin on a rain-dark stone causeway; learn movement and jumping in context.
3. Encounter one melee enemy with readable wind-up and recovery frames.
4. Navigate gaps, moving / collapsing sections and one checkpoint.
5. First encounter with **The Hollow Bishop**, a huge distant boss who is larger than the playable environment and periodically attacks into the foreground.
6. One boss hit breaks or reshapes traversable geometry, with visibly telegraphed danger and a recoverable gameplay route.
7. Survive a pursuit sequence; reach the boss arena.
8. Three starter cards are introduced during the actual fight; cards have correct energy cost, targeting, cooldown/effects and observable consequences.
9. Defeat the boss with a finish state and restart capability.
10. Optional clearly signposted **Reality Fracture** portal to a smaller free-movement 3D arena with an enemy; return to the normal 2.5D plane after the encounter.

The ZIP includes an early **starter greybox**, not this complete vertical slice. Extend in deliberate milestones. Never claim the above sequence is complete until manually tested from boot to victory.

## 4. Movement and interaction

- `CharacterBody3D`; jump buffering, coyote time, acceleration, variable-height jump, ground/air states, dodge, temporary invulnerability, platform interaction, knockback, checkpoints, and death/respawn.
- During 2.5D mode: deterministic Z plane-lock; camera tracks X/Y with pleasing lag, zoom/framing and boss composition. No unintended depth drift from collisions.
- During 3D mode: re-use the character and combat systems; enable X/Z movement, orbiting or third-person camera, and appropriate target lock/dodge direction.
- Input mapping: keyboard first, gamepad next. Browser/mobile touch controls are later scope and must be labeled unimplemented until tested.
- Accessible options: camera shake strength, reduced blood, key remapping (later), UI legibility.

## 5. Weighted combat and gore

- State-based light/heavy attacks, melee hurtboxes and hitboxes, active/startup/recovery windows, hit stun, stagger, defensive dodge, and attack cancel rules explicitly documented.
- Enemy AI with patrol/aggro/telegraph/attack/recover/death states, actual collision-based damage and death.
- Prototype gore: procedural blood spray, simple decals/fading splashes, hitstop or equivalent brief feedback, impact SFX hooks, attack-facing alignment, camera impulse. No visually elaborate implementation at the cost of combat correctness.
- Architecture allows later execution finishers, detachables, weapon trails, body-region-based damage, and mesh swaps without reauthoring baseline attack logic.
- Define enemy families: plagued soldiers, fallen holy knights, skeletal guardians, parasitic swarm hosts, grotesque cultists. Only one family needs first-pass implementation.

## 6. Boss design — The Hollow Bishop

Large skeletal ceremonial colossus behind the player's Z plane, strongly visible at a distance.

**Phase 1, The Procession:** Boss tracks the player in the background, charges slow telegraphed strikes toward Z=0, forces movement and jump/dodge decisions.

**Phase 2, The Collapse:** Boss damages the causeway, dropping select bridge segments, creating hazards and alternate jump routes. Hazards must have finite collision and a clear reset path after death.

**Phase 3, The Covenant:** Boss becomes vulnerable. Specific cards counter telegraphed attacks or target exposed weak points; the boss has a health bar and victory resolution.

Implement at minimum:
- Boss state machine with phases, deterministic debug triggers, telegraph timing, attack active windows, recoverability and cooldowns.
- At least two different attacks with genuine damage interaction.
- At least one level-changing attack.
- At least one weakness window, at least one card reaction, at least one defeat path.
- Attack read-through-depth: background windup, threat volume nearing player's movement plane, readable local danger geometry.
- Fight is not a non-interactive cutscene.

## 7. Bloodbound Cards — three functioning starter abilities

Cards are **real-time abilities** used in boss fights, not a separate round-based game. Use GDScript `Resource` definitions for cost, effect, cooldown, targeting, tags, VFX hooks and UI metadata.

1. **Blood Spear:** Costs blood energy; shoots a projectile or ray with actual collision/targeting, damages exposed boss weak points.
2. **Grave Shield:** Costs energy; raises a brief defensive state that blocks one heavy strike or prevents a defined damage category.
3. **Ritual Chains:** Costs energy; interrupts a clearly telegraphed, interruptible boss action inside a proper time window.

Core system: deck/hand/draw/discard, a seeded shuffle for repeatable tests, energy resource/gain, input mapping, action validation, cooldown, UI indicators, failure feedback, boss event interactions. Initial version can hold three cards fixed until real deckbuilding arrives; preserve the data model for expansion. Card activations must never work when unaffordable or invalid.

**Original later cards:** Epitaph (delayed ground spike), Hemorrhage Pact (life for damage), Ashen Choir (summoned phantom), Bell of Silence (temporary enemy spell lock). These are future content, not Phase 1 obligations.

## 8. Reality Fractures — selective full 3D combat

- A short intentional transition (camera, controls, boundaries) from normal side-scroll into an arena with full X/Z movement.
- Shared health, inventory, attacks and player representation, separate camera/controller *mode* not separate inconsistent game logic.
- 3D enemy attacks with appropriate range/direction handling.
- Single-test environment: ruined circular chapel, a basic enemy and a return portal.
- Scene is optional in the initial 5–10-minute path but must be a functional testable system before marking vertical slice complete.

## 9. Environments and rendering

- Use modular ruined-stone primitives at first, replaceable scene instancing later.
- Prioritize high-contrast traversal and enemy telegraph readability.
- Efficient atmospheric tricks suitable for Compatibility: layered meshes, fog planes, gradients, ambient particles, color correction within supported features, carefully placed lights; avoid assuming unsupported volumetric effects for web.
- Local destruction: targeted replacement/state toggling/physics-simulated debris if stable; never make entire environment heavy real-time destructible simulation by default.
- Maintain performance budget for animation, particles, dynamic lights and decals.

## 10. External asset pipeline

**Tripo3D** for first-pass props/creatures; **Blender + verified Blender MCP** for repair, normals, UVs, decimation, materials, rigs, animation retargeting, export; Godot GLB importer into replaceable character/prop scenes. See `docs/ASSET_PIPELINE.md` for naming and QA.

Jev AI is only a requested optional tool; verify its exact website, product, integration and licenses before using it. Never invent API schema. May use alternative user-approved image/animation tools where appropriate.

Do not generate a full creature roster before basic gameplay exists. Prepare example art briefs first, then request authorization for paid model generation.

## 11. Agent delegation and code quality

Potential parallel specialist roles: player systems, melee/enemies, boss/level events, cards/UI, environment/assets, test/integration. Specific read/write constraints in `.claude/agents/`.

The orchestrator should:
- Inspect repository and installed MCP capabilities; read latest task notes.
- Split tasks into bounded changes with a shared contract and separate files.
- Request actual builds/unit tests and evidence, not self-reported confidence.
- Merge only after validation, regress previous gameplay systems, record changes.
- Keep current build playable every milestone. Use Git and reproducible changes.

Do not scaffold a fresh unrelated engine or swap to Unreal merely for visuals. Propose a deliberate architecture review if the actual target changes to a browser-first or mobile-first runtime.

## 12. Validation/quality gates

For every milestone:
1. `python tools/validate_template.py` passes.
2. Godot 4.7 actual editor/headless import opens without parse/import errors.
3. Game launches visibly and required controls can be exercised.
4. No critical gameplay exceptions in logs and no unwinnable terrain.
5. Boss/cards/3D mode have deterministic debug test pathways before calling complete.
6. Update `docs/TEST_RESULTS.md` with commands, versions, observed results/screenshots, and known failures.
7. Update `docs/PROGRESS.md` and `docs/ROADMAP.md` acceptance status.

Boot test != full QA. Browser exports need templates and web-server testing. Don't make unsupported release/platform claims.

## 13. Milestones and definition of done

- **M0:** Run/validate included starter, fix any bootstrap errors, build reproducible baseline.
- **M1:** Responsive 2.5D movement/platforming/checkpoints, one coherent level route.
- **M2:** Real melee combat, enemy AI, hit/health/death pipeline, combat feedback.
- **M3:** Large depth-aware background boss with at least two real attack types, one level-changing hit and defeat path.
- **M4:** Three genuinely working Bloodbound Cards + UI + boss interaction.
- **M5:** Full-3D combat arena, shared player systems and bidirectional camera transitions.
- **M6:** Menus, 5–10 min playthrough, options, atmosphere, restart, web smoke test.
- **M7:** External GLB replacement pipeline, documented art integration, optimization and licensing review.

Detailed verification checklists: `docs/ACCEPTANCE.md` and `docs/ROADMAP.md`.

**Begin now:** Follow `prompts/FIRST_RUN.md`, inspect the local files and tool availability, verify that Godot really launches, repair any failures, then complete **M0** before expanding the game.
