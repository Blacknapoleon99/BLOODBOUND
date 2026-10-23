# Hero animation credits (DEC-059)

`hero_kimodo_anims.res` holds 24 clips for the Bone Revenant (`bone_revenant.glb`), loaded by
`ArtSwap` into the model's AnimationPlayer next to its 13 Tripo clips (which stay untouched).

## Source

- **Motion model:** NVIDIA Kimodo, model **Kimodo-SOMA-RP-v1.2**, under the **NVIDIA Open Model
  License** (commercial use allowed). Generated locally on this machine (`D:\Tools\kimodo`, code
  Apache-2.0, github.com/nv-tlabs/kimodo); nothing was sent to a cloud service.
- **Text encoder:** LLM2Vec adapters (McGill-NLP, MIT) on Meta-Llama-3-8B-Instruct (Llama 3
  Community License), as installed for the Kimodo setup.
- **Not used:** Kimodo-SMPLX-RP (non-commercial), UniMate (CC-BY-NC), Mixamo, Tripo animation
  requests, Epic sample animations.
- The prompts, seeds, durations and the picked take of each clip are in `tools/kimodo/clips.json`.
  Raw takes are not committed (`tools/kimodo/raw/`, regenerate with the fixed seeds).

## Pipeline (all in this repo)

1. `tools/kimodo/kimodo_generate.py` (adapted from the Blockheads pipeline) writes 4 takes per clip.
2. `tools/kimodo/kimodo_to_hero.py` (written for BLOODBOUND, numpy only) retargets a take onto the
   hero's Mixamo skeleton: world-rotation transfer with a per-bone swing from the hero's rest
   direction to the SOMA T-pose direction, in-place root, leg-length hip scaling, toe grounding,
   the hero's own sword-grip fingers (from its `slash` clip), loop cross-fades.
3. `tools/kimodo/build_hero_library.gd` turns that into the AnimationLibrary, with each clip's
   `strike` (sword hand's fastest frame), `motion_start`, `motion_end` and `treadmill_speed` as metadata.
4. `tools/kimodo/review_sheets.py` + `anim_sheet.gd` render the review contact sheets;
   `capture_moves.gd` captures the moves in the playground.
