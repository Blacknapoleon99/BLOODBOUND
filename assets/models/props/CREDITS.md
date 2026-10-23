# Gothic props and hazard models (DEC-057)

Every model in this folder is **original work**, generated headless in Blender 5.2 by
`tools/blender/build_props.py` (helpers in `tools/blender/gothic_common.py`) from primitives,
bevels, booleans and voxel-remeshed unions. No third-party meshes, no paid or AI generation.

| Files | What | Source | License |
| --- | --- | --- | --- |
| `skull`, `bone`, `skull_pile_a/b`, `candles_a/b`, `candelabra`, `column_tall/short/drum`, `gravestone_a/b`, `sarcophagus`, `fence_section`, `fence_bent`, `iron_cage` | corner props (GothicDressing), the gibbet cages of the background world | procedural, this repo | project's own |
| `spike`, `spike_plate_tile`, `pendulum_crescent/spine/arm`, `lever_base/handle`, `bridge_plank/rail`, `blood_altar`, `chest_body/lid`, `bone_shard`, `checkpoint_banner/cloth`, `exit_arch`, `bone_wall_module`, `merchant_stall`, `merchant_figure` | hazard and interactable visuals | procedural, this repo | project's own |

The GLBs carry geometry and UVs only. Material slot names are roles; `scripts/art/gothic_props.gd`
maps them to textured PBR materials built from `assets/textures/gothic/` (Poly Haven CC0
scans, plus the procedural `bone`, `cloth` and `wax` sets made by
`tools/blender/make_textures.py`; see that folder's CREDITS.md).

Rebuild: `"C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b --python tools/blender/build_props.py -- <repo> [names] [--sheet preview.png]`, then `godot --headless --path . --import`.
