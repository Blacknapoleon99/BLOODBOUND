# Full-3D creatures (DEC-064)

Every file listed here is **original work**. The models were generated headless in Blender 5.2
(the `bpy` 5.2.3 module from pip) by `tools/blender/build_creatures.py`, using the helpers in
`tools/blender/gothic_common.py`. They are built from primitives, swept tubes, lathes,
voxel-remeshed unions, booleans and vertex displacement. No third-party meshes were used, and
nothing was made with paid or AI generation.

| Files | What | Source | License |
| --- | --- | --- | --- |
| `../flayed_stalker.glb` | Flayed Stalker: skinless sinewy crawler, 18 rigid parts | procedural, this repo | project's own |
| `../stitched_brute.glb` | Stitched Brute: sewn corpse abomination with a fused cleaver, 17 parts | procedural, this repo | project's own |
| `../limb_spider.glb` | Limb Spider: a knot of human limbs round a many-mouthed torso, 18 parts + 6 IK ends | procedural, this repo | project's own |
| `../hollow_mourner.glb` | Hollow Mourner: faceless veiled figure in a mourning dress, 10 parts | procedural, this repo | project's own |
| `../lantern_wight.glb` | Lantern Wight: 3.2 m tallow figure with a cage-lantern, 16 parts + light socket | procedural, this repo | project's own |
| `tex/muscle_*.jpg`, `tex/skin_*.jpg`, `tex/lace_diff.png` | wet fibrous muscle, pale corpse skin, torn black lace (PBR, tileable, 512 px) | numpy, `tools/blender/make_creature_textures.py` | project's own |

Each GLB is a node hierarchy. The origin of every part sits on its joint, so the game can
animate the creature procedurally (`scripts/enemies/creature_rig.gd`). There is no skeleton and
no baked animation.

The material slot names are roles, and `scripts/enemies/creature_materials.gd` maps them to
materials. The bone, iron, wax and cloth roles reuse the sets in `assets/textures/gothic/`;
see that folder's CREDITS.md. Vertex colours carry a cavity and mottling shade.

Rebuild:

1. `python tools/blender/make_creature_textures.py -- <repo>`
2. `python tools/blender/build_creatures.py -- <repo> [names]`
3. `godot --headless --path . --import`

Either step 1 or 2 can also run as `blender -b --python <script> -- <repo>`.
