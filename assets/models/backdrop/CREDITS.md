# Background world assets (DEC-055)

| Files | Source | Author | License |
| --- | --- | --- | --- |
| `gothic/*.glb` (cathedral, towers, broken tower, rock islands, dead trees, pillar crown, ruin wall, ribcage, pinnacle, bat) | `tools/blender/build_backdrop.py`, built headless in Blender (DEC-057) | original (this repo) | project's own |
| `kenney_castle/*.glb`, `kenney_castle/Textures/colormap.png` (tower-hexagon base/mid/top/roof, tower-square mid-windows / top-roof-high-windows, wall-half, wall-pillar, rocks-large) | Castle Kit 2.0, www.kenney.nl (local copy from the user's CC0 library) | Kenney | CC0 1.0 (see `kenney_castle/License.txt`) |

Everything else in the background world (cathedral, spires, arches, buttresses, rock islands,
dead trees, chains, gibbet cages, ribcages, mountains, the blood sea, mist, glow ring, embers,
bats) is generated procedurally in `scripts/level/backdrop_kit.gd`, `backdrop_horizon.gd`,
`backdrop_flock.gd` and the shaders in `assets/shaders/backdrop/` (original work, no third-party
content). The Kenney pieces are merged into the islands' ruined towers with our own dark stone
material (their colours and texture are not used at runtime). No paid generation was used.

DEC-057: the modelled pieces in `gothic/` now replace the procedural cathedral, towers, rocks,
trees, ribcage, pillar tops, ruin walls and bats (BackdropKit falls back to the procedural
shapes when a model is missing). The Kenney hexagon towers are no longer merged while the
modelled towers are present; the files stay for the fallback.
