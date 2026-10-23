# Asset pipeline — Tripo3D → Blender/MCP → Godot

**No cost-bearing external asset generation without explicit authorization.** First verify that external providers and access exist.

## Folder convention

- `assets/incoming/<asset_id>/` — original downloaded GLB, provider readme and generation notes; do not modify in place.
- `assets/processed/<asset_id>/` — checked GLB(s), textures and import notes.
- `assets/manifests/assets.json` — name, provider, prompt/reference provenance, license status, approval, approximate polycount, skeleton/animation list, scale, texture budget.

## Modeling requirements

- Units: meters, Y-up after Godot import; use Blender's normal conventions and verify rotations in engine, **do not assume conversions**.
- Origin: ground-contact at character feet; prop pivot according to attachment usage. No baked arbitrary enormous transform.
- Face forward consistently (prefer character facing -Z in authored 3D unless current rig standard is established; confirm with Godot import test).
- Triangle budgets are **targets, not absolute**: hero 15k–50k tris desktop; common enemy 8k–30k; small props 200–8k. For browser/mobile start lower, measure performance, require LODs for expensive assets.
- Textures: prototype 1k–2k PBR sets, 4k only where close-up evidence justifies it. Consider atlas, compression and draw calls.
- Prefer GLB for scene interchange; preserve skinning, animation, mesh LOD choices and material details that the Godot importer actually supports.
- Collisions: simplified shape(s) intentionally authored or generated in Godot. Avoid using every decorative polygon as combat collision.

## Production steps

1. Write art brief and needed in-game scale/animations.
2. Confirm model source licensing, content permissions, Tripo/Jev quotas, and user approval.
3. Create a short batch with provider app or documented current API. Prefer a visual reference when consistency matters.
4. Download original to `assets/incoming/<id>/` and fill manifest.
5. Use Blender interactively or through a **verified and trusted** Blender MCP: inspect topology, fix holes/normals/UVs, apply scale carefully, edit pivots, decimate or retopologize when justified.
6. Rig or retarget if an animated character; verify idle, run, jump, attack, stagger, and death as relevant.
7. Export validated GLB and a thumbnail/test screenshot to `assets/processed/<id>/`.
8. Import to Godot in a test scene. Check materials under Compatibility renderer, lighting response, orientation, collider, animation name and memory usage.
9. Replace **only** visual child nodes so scripts and gameplay physics remain unchanged. Roll back if broken.

## Example asset IDs

`player_cursed_knight_v01`, `enemy_plagued_soldier_v01`, `boss_hollow_bishop_blockout_v01`, `prop_gallows_small_v01`, `environment_bridge_segment_v01`.

## Asset generation prompt template

> Single original [character / prop] for a dark medieval action-platformer. Functional silhouette visible from a fixed side camera, readable negative space, weathered charcoal stone/bone/iron with restrained crimson accents. Neutral pose if animated, no base/pedestal, no text/logos, no environment; design appropriate for real-time 3D use. Target dimensions [meters], animation requirements [list], topology and texture constraints [budget]. Distinct from existing games/film designs.

Record tool settings and costs, not API keys. Do not copy Tidebreaker, Shadow of the Colossus, or third-party signature character appearances.

## Level geometry textures (DEC-054)

- CC0 PBR scans live in `assets/textures/gothic/<set>_{diff,nor,arm}.jpg` with `CREDITS.md`.
- Import settings (in the `.import` files): diffuse and ARM use VRAM compression with mipmaps; normal maps are lossless with mipmaps. Normals are OpenGL convention, and the shaders decode them by hand, so no normal-map import flag is needed.
- To add a set: download the 1k `diff`, `nor_gl` and `arm` JPGs and name them `<set>_diff.jpg`, `<set>_nor.jpg` and `<set>_arm.jpg`. Copy the import params from an existing set, run `godot --headless --path . --import`, add a kind in `GothicMaterials._make`, and add a CREDITS row.
- Check the look with `godot --path . -s res://tools/dev/shot_ground.gd -- <out_dir> [seed]` (a visible window, not headless).

## Background world (DEC-055)

- Backdrop decor is procedural (`scripts/level/backdrop_kit.gd`) plus CC0 kit pieces copied into `assets/models/backdrop/` with a `CREDITS.md` row each. Copy only the pieces used, with their licence file and any texture the GLB references (or the import logs errors).
- Kit pieces are merged into one mesh per object and drawn with `assets/shaders/backdrop/backdrop_stone.gdshader` (vertex colour rgb = tint, alpha 0 = glowing). A replacement GLB only needs a single mesh at a sensible scale; `BackdropKit.kenney()` measures its AABB to stack it.
- Backdrop meshes never get collision and never cast shadows; `tests/backdrop_check.gd` enforces that and keeps them out of every course's play volume.
