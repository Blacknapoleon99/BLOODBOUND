# Gothic level textures: credits and licences

All textures here come from [Poly Haven](https://polyhaven.com) and are licensed **CC0 1.0**
(public domain; no attribution required, credited anyway). They are 1k JPG maps downloaded
from the public API (`https://api.polyhaven.com/files/<id>`): diffuse (`_diff`), OpenGL normal
(`_nor`), and packed AO / roughness / metalness (`_arm`). They were renamed and not edited.

| Local set   | Poly Haven asset         | Source URL                                             | Used for |
|-------------|--------------------------|--------------------------------------------------------|----------|
| `flagstone` | monastery_stone_floor    | https://polyhaven.com/a/monastery_stone_floor          | walkable tops (worn cathedral flagstone) |
| `masonry`   | medieval_blocks_02       | https://polyhaven.com/a/medieval_blocks_02             | block sides, walls, broken columns |
| `cobble`    | cobblestone_floor_08     | https://polyhaven.com/a/cobblestone_floor_08           | wet cobble tops (second route) |
| `rust_iron` | rusty_metal_02           | https://polyhaven.com/a/rusty_metal_02                 | moving / orbiting platforms, fence spikes, portcullis |
| `cracked`   | castle_brick_broken_06   | https://polyhaven.com/a/castle_brick_broken_06         | collapsing slabs, breakable floors, ossuary sides |
| `rubble`    | rock_wall_08             | https://polyhaven.com/a/rock_wall_08                   | crumbled undersides of floating platforms |
| `climb`     | rough_block_wall         | https://polyhaven.com/a/rough_block_wall               | climb walls (behind the bone handholds) |
| `wood`      | medieval_wood            | https://polyhaven.com/a/medieval_wood                  | merchant stall, reliquary chests |

Licence text: https://polyhaven.com/license (CC0 1.0 Universal,
https://creativecommons.org/publicdomain/zero/1.0/).

Props (skulls, bones, candles, columns, fence) are procedural meshes built in
`scripts/art/gothic_dressing.gd`; no third-party models are used.
