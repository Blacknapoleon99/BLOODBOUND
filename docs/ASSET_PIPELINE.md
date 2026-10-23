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

## Modelled level architecture (DEC-056)

- Level blocks keep their `BoxShape3D` collision exactly; only the look is rebuilt. `GothicKit` (`scripts/art/gothic_kit.gd`) 9-slices any box into kit pieces from `assets/models/kit/gothic_kit.glb`:
  - walkable tops: 2 x 2 m random-ashlar paving cells;
  - edges: a coping ring with a moulded cornice lip and a corbel table, with mitred corners;
  - sides: masonry courses, or a blind pointed arcade on faces taller than 3 m, with dressed quoins on the corners;
  - walls get shallow buttresses; pillars get a capital, a clustered shaft, annulets and a broken foot;
  - climb walls get carved corbel-and-bone handholds; movers become iron grates; collapsing and secret slabs become shattered stone over a glowing core; gate bars become a portcullis.
- The kit is original, modelled procedurally and headless by `tools/blender/build_gothic_kit.py` (Blender 5.2, `-b --factory-startup`; it never touches a live Blender session). Pieces are authored in Godot axes (Y up, +Z outward). Vertex colour carries masks: r = cavity, g = glow, b = bone, a = paving (1) or trim (0).
- Textures come from the CC0 scans by world-space triplanar mapping (`gothic_kit.gdshader`), so stretched pieces still tile at true metres. Materials are cached per kind and room tint.
- **Performance:** each room is one `GothicKit.Batch`, drawn as one MultiMeshInstance3D per (piece, material). Paving cells and handholds cast no shadow; the underside slab casts the block's full shadow.
- **Footing contract** (checked for every piece; see `tests/kit_check.gd`): nothing more than 0.03 m above a block's top, and nothing more than 0.16 m past its sides or bottom.
- **To add a piece:**
  1. Write a `build_<name>(B)` function, register it in `PIECES`, and rerun the script.
  2. Run `godot --headless --path . --import`.
  3. Place the piece in `GothicKit._masonry` / `_pillar` (or `single()` for a scaled one-off), and add it to `tests/kit_check.gd`.
- **Visual checks** (visible window):
  - `tools/dev/shot_kit.gd`: close-ups of the cornice edge, paving, pier, climb wall, mover, slab, and both sides of a tall face;
  - `tools/dev/shot_ground.gd`: room views;
  - `tools/dev/kit_perf.gd`: fps, draw calls and primitives.

## Modelled props, hazards and backdrop pieces (DEC-057)

- **Source:** original models built headless in Blender (no live MCP session, no paid generation):
  - `tools/blender/build_props.py` writes `assets/models/props/<name>.glb` (corner props, spike trap, pendulum, lever and bridge, altar, merchant, chest, shard, checkpoint standard, exit arch, ossuary wall module).
  - `tools/blender/build_backdrop.py` writes `assets/models/backdrop/gothic/<name>.glb` (cathedral, towers, rocks, trees, pillar crown, ruin wall, ribcage, pinnacle, bat).
  - `tools/blender/make_textures.py` writes the procedural `bone`, `cloth` and `wax` PBR sets into `assets/textures/gothic/`.
  - Run: `"C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b --python tools/blender/<script>.py -- <repo> [names...] [--sheet preview.png]`. `--sheet` renders a Workbench contact sheet for a quick shape check. Then run `godot --headless --path . --import`.
- **Conventions** (`tools/blender/gothic_common.py`):
  - Builders take Godot coordinates (y up, +Z front). Origin at the ground contact unless the docstring says otherwise (the pendulum arm hangs from its pivot, the chest lid sits on its hinge, the wall module is centred).
  - One joined object per GLB. Material slot names are **roles** (stone, stone_dark, stone_pale, rock, iron, blade, bone, wood, wax, flame, glow, cloth, gold, glass, dark). Textures are not embedded.
- **Props in Godot:** `GothicProps` (`scripts/art/gothic_props.gd`) loads a GLB and maps each role to a textured, object-space triplanar PBR material.
  - Scripts that animate a material pass it in `roles`, so telegraphs keep working: the spike plate's warning pulse, the lever bridge fade, the altar and chest glow, the checkpoint banner.
  - `stretched()` nine-slices a model along one axis, so a 1 m pendulum arm or spine fits any length without stretching its hub.
  - `subset()` splits candle flames from wax, so the flames cast no shadows.
  - Every call returns null when a GLB is missing, and the old primitive is then built instead.
- **Backdrop in Godot:** `BackdropKit.model()` / `add_model()` merge a GLB into the one-mesh-per-object `Merge`, turning roles into vertex colours. Alpha 0.75 marks rock.
  - `add_tower_model()` stretches the tower shaft to the requested height and scales the spire part separately.
  - `backdrop_stone.gdshader` adds triplanar detail: the masonry scan on buildings and the rubble scan on rock.
- **Budgets** (triangles):
  - Corner props: 0.5k–5k each.
  - Bone wall module: 20k per 2 m (shown only during an ambush).
  - Exit arch: 6.4k.
  - Cathedral: 46k.
  - Unit towers: about 2.5k.
  - Rocks: 1.3k. Trees: 1k.
- **Checks:**
  - `tools/dev/shot_props.gd` (visible window) photographs every prop and hazard under the gothic lighting.
  - `tests/backdrop_check.gd` keeps the background decor free of collision and shadows, and out of the play volume.
