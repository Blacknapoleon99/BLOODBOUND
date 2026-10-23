# Gothic level kit — credits and provenance (DEC-056)

| File | Source | Licence | Notes |
|---|---|---|---|
| `gothic_kit.glb` | Original: modelled procedurally in Blender 5.2 (headless) by `tools/blender/build_gothic_kit.py`, written for BLOODBOUND | Project-owned (original work, no third-party geometry) | 21 pieces, ~27.5k triangles in total. Regenerate with the command below; the build is deterministic. No paid generation; nothing downloaded. |

Textures are not embedded. In game the pieces use the CC0 Poly Haven scans already credited in
`assets/textures/gothic/CREDITS.md`, applied by world-space triplanar mapping in
`scripts/art/shaders/gothic_kit.gdshader`.

Regenerate:

```
"C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe" -b --factory-startup --python tools/blender/build_gothic_kit.py -- assets/models/kit/gothic_kit.glb
godot --headless --path . --import
```

Preview sheet (Blender workbench render):
`blender -b --factory-startup --python tools/blender/preview_gothic_kit.py -- assets/models/kit/gothic_kit.glb <out.png>`
