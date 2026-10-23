# Kimodo hero moveset (DEC-059)

Text-to-motion clips for the hero, generated locally with NVIDIA Kimodo (SOMA model only) and
retargeted onto `assets/models/player/bone_revenant.glb`. Credits: `assets/models/player/ANIM_CREDITS.md`.

```bash
# 1. Generate 4 takes per clip (one process at a time: ~17 GB VRAM with the encoder)
TEXT_ENCODERS_DIR=D:/Tools/kimodo/text_encoders D:/Tools/kimodo/.venv/Scripts/python.exe -I \
    tools/kimodo/kimodo_generate.py --manifest tools/kimodo/clips.json [--only slash_1]
# 2. Review: retarget every take, build a scratch library, render one sheet per clip (rows = takes)
D:/Tools/kimodo/.venv/Scripts/python.exe -I tools/kimodo/kimodo_to_hero.py --glb assets/models/player/bone_revenant.glb \
    --manifest tools/kimodo/clips.json --out <scratch>/review.json --review
godot --headless --path . -s res://tools/kimodo/build_hero_library.gd -- <scratch>/review.json <scratch>/review.res
python tools/kimodo/review_sheets.py <scratch> <scratch>/review.res
# 3. Set "npz" of the picked take in clips.json, then build the game library
D:/Tools/kimodo/.venv/Scripts/python.exe -I tools/kimodo/kimodo_to_hero.py --glb assets/models/player/bone_revenant.glb \
    --manifest tools/kimodo/clips.json --out <scratch>/final.json
godot --headless --path . -s res://tools/kimodo/build_hero_library.gd -- <scratch>/final.json res://assets/models/player/hero_kimodo_anims.res
# 4. Look: studio sheets and in-game captures
godot --path . -s res://tools/kimodo/anim_sheet.gd -- docs/screenshots/anim_attacks.png slash_1@0.37-1.60,... 10 res://assets/models/player/hero_kimodo_anims.res -60 sword
godot --path . -s res://tools/kimodo/capture_moves.gd -- docs/screenshots
```

Prompts work best as "A person ..." describing the body. Kimodo did not produce a real ledge hang
(every take stood with the arms up), a feet-first slide or a hit stagger with much travel; see the
notes in `clips.json`.
