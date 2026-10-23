# Background world assets (DEC-055)

| Files | Source | Author | License |
| --- | --- | --- | --- |
| `kenney_castle/*.glb`, `kenney_castle/Textures/colormap.png` (tower-hexagon base/mid/top/roof, tower-square mid-windows / top-roof-high-windows, wall-half, wall-pillar, rocks-large) | Castle Kit 2.0, www.kenney.nl (local copy from the user's CC0 library) | Kenney | CC0 1.0 (see `kenney_castle/License.txt`) |

Everything else in the background world (cathedral, spires, arches, buttresses, rock islands,
dead trees, chains, gibbet cages, ribcages, mountains, the blood sea, mist, glow ring, embers,
bats) is generated procedurally in `scripts/level/backdrop_kit.gd`, `backdrop_horizon.gd`,
`backdrop_flock.gd` and the shaders in `assets/shaders/backdrop/` (original work, no third-party
content). The Kenney pieces are merged into the islands' ruined towers with our own dark stone
material (their colours and texture are not used at runtime). No paid generation was used.
