# BLOODBOUND — Art Bible

Status: v0.1 (start of the art phase, 2026-10-21). Gameplay is greybox; this document fixes the
visual rules every replacement asset must follow. The prioritized list is in `docs/ASSET_LIST.md`,
the pipeline in `docs/ASSET_PIPELINE.md`.

## 1. Direction in one paragraph

A drowned gothic kingdom at night: rain-black stone, ivory bone, tarnished iron, and blood. The
world is cold and nearly colourless, and colour is earned. **Bright red means "this will hurt you
now"**, and nothing else gets to be bright red. Shapes come first. The player sees the game from
22 m away, so every asset is judged by its silhouette and value block, not its surface detail.
Inspired by gothic horror and medieval reliquary art, never by another game's designs (no
Tidebreaker, Shadow of the Colossus or Souls signature looks).

## 2. The camera and what it means for art

Facts from `scripts/main.gd`:

- **Normal camera:** FOV 52° (vertical), offset (0, 4.8, 22) from the player, looking at the player plus 1.2 m.
- **Boss approach and arena:** offset (0, 6.5, 24), looking at the player plus 4 m.
- **Reality Fracture:** offset (0, 5.8, 11.5).
- **Co-op:** pulls the camera back up to about 11 m more.

What that gives on a 1080p screen:

- At the play plane (z = 0) the view is about 21.5 m tall and 38 m wide. One screen pixel covers about 2 cm, which is roughly 50 px per metre.
- A 1.8 m character is about 90 px tall. Anything smaller than about 5 cm (2–3 px) is invisible. Spend no polygons and no texture detail there.
- The Bishop stands at z = -22, which is 44–46 m from the camera. A 30 m colossus fills about 65–70% of the screen height. It reads as architecture, so it needs big shapes and strong value breaks.
- **The camera always looks down the -Z axis.** Only the +Z face (the front face) and the top faces of play-plane geometry are ever seen. The back (-Z) faces of play-plane objects may be simplified or left open. The ends of pieces that tile along X are hidden by their neighbours.
- **Texel density targets:**
  - Play plane: 256 px/m, which is about 5× screen density. This leaves headroom for the 3D fracture camera and 1440p.
  - Mid-ground (z -5 to -10): 128 px/m.
  - Far background (z ≤ -18): 32–64 px/m, or flat vertex colour.

## 3. Depth layers

| Layer | Z range | Contents | Value / contrast |
|---|---|---|---|
| Play plane | -2 to +2 | Causeway, platforms, hazards, player, enemies, props | Full contrast. Lightest stone tops, so the walkable surface reads. |
| Near backdrop | -5 to -7 | Section walls and pillars (`LevelSection._backdrop`) | 40% darker than the play plane. No highlights brighter than the causeway top. |
| Boss plane | -18 to -26 | Hollow Bishop, distant towers, cathedral silhouette | Silhouette against the sky. Bone forms rim-lit by moonlight. |
| Sky | — | Background colour or gradient, plus fog cards | Darkest blue-black. Never pure black, so silhouettes still read. |

Readability rule: **walkable tops are the lightest surface of any layer**. Anything you can stand
on gets a lighter top face (worn paving, moonlit coping) than its sides and than the backdrop.

## 4. Palette

Linear-ish RGB values, matching how the greybox code already specifies colours.

| Role | Colour | Use |
|---|---|---|
| Night / sky | (0.021, 0.025, 0.039) | Background. Already in `_build_greybox`. |
| Stone dark | (0.07–0.11, 0.075–0.11, 0.09–0.12) | Wall and causeway sides, mortar. Blue-charcoal. |
| Stone top | +25–40% value of stone dark | Walkable surfaces, coping. |
| Iron | (0.25–0.32, 0.23–0.30, 0.24–0.34) | Portcullis, pendulum rods, armour. Low saturation. |
| Bone / ivory | (0.66–0.86, 0.62–0.82, 0.53–0.70) | Enemies, Bishop, bone bridge, spikes. The **main "creature" signal**. |
| Moonlight | (0.59, 0.66, 1.0) | Key light and rim. |
| Sacred gold | (0.70, 0.55, 0.20) | Rewards, interactables, brass, merchant lamp (lamp may lean cold). |
| Spectral teal | (0.35, 0.75, 0.80) | Player-friendly magic: Grave Shield, revive, Reality Fracture accents. |
| Amber | (0.95, 0.54, 0.12) | Gates and portals (current fracture gate). Navigation only. |
| Blood (gore) | (0.40–0.55, 0.02, 0.04) | Blood VFX and decals. **Dark and lit (shaded), never emissive.** |
| **TELEGRAPH RED** | **(0.95, 0.08, 0.05)**, unshaded, alpha 0.5 | **Danger only**: attack zones, wind-up glows, aim lines. |

### Red is reserved (hard rule)

- **Bright, unshaded or emissive red (or red-orange) appears only in a telegraph.** That means a wind-up glow, a danger zone, an aim line, or a hazard that is about to fire. The colour is `BishopHand._warning_material()` (`scripts/boss/bishop_hand.gd`) plus orange-red wind-up emission.
- Blood is **dark, desaturated, lit maroon**. It is part of the world, not a warning. If blood ever glows, it stops being blood and becomes a telegraph.
- Crimson as a *material* (cloth, mitre, banners) is allowed only at low value (≤ 0.45) and fully shaded. It must never emit.
- No texture contains bright red details: no red runes, no red eyes on non-attacking enemies.

Current greybox conflicts. These are recommendations. Fixing them means changing gameplay-owned scripts, so it belongs to the gameplay session:

1. Several rewards and interactables glow red: the blood altar bowl, the reliquary lid and its light, and the active checkpoint banner. Move them to sacred gold (or keep the altar a dark lit maroon with a *gold* rim glow).
2. The Bishop's stigmata weak point opens in the same red as danger. Make the open stigmata **white-gold "holy wound" light**, so "hit here" and "get out of here" are different colours.
3. The Bishop's eyes glow red constantly. They should only glow red during a wind-up. Idle eyes should be dim cold blue-white.
4. Player 2 "wears red" (0.88, 0.45, 0.32). Change P2 to a gold or teal tabard so a red-orange shape on the play plane is never a friend.
5. Enraged enemies turn red. That is acceptable only if it is treated as a sustained "more dangerous" state. Prefer an emissive crack pattern over a whole-body red tint.

## 5. Silhouettes

- **Player knight:** vertical, narrow and upright, with a long sword and a short tattered cape. Readable facing direction (asymmetric pauldron and sword side). Bright steel highlights, the only cool-bright figure on screen.
- **Enemies:** bone/ivory value against dark stone. Each family gets one unique shape cue visible at 90 px:
  - Soldier: hunched with a raised blade.
  - Husk: the same soldier, shorter and slumped.
  - Archer: a bow taller than the head.
  - Hound: a long low horizontal.
  - Shielded Knight: a tower shield.
  - Wraith: a tapering shroud with no legs.
  - Crawler: low and wide.
  - Gravewarden: a huge maul.
- **The Bishop:** a vertical cathedral. Mitre spire, rib cage, a skull lit from above, robe falling into fog. Its hand must read as a hand at 46 m: five clear digits and a big palm plane.
- Keep 30–50% negative space in creature silhouettes (gaps between limbs and weapons). Solid blobs lose readability.

## 6. Materials

- **PBR, Compatibility renderer.** StandardMaterial3D through the glTF import. No custom shaders unless a Web export test passes. The Compatibility renderer has no SSAO, SSR or SDFGI, so bake ambient occlusion into vertex colour or textures where it matters.
- **Stone:** rough (0.85–0.95), non-metallic, chipped bevels (2 cm) to catch moonlight rim, block-and-mortar geometry for the front face. Prefer **trim sheets** and tileable 1k sets over unique bakes.
- **Bone:** roughness 0.6–0.75, slight subsurface tint in albedo only, cavity darkening.
- **Iron:** metallic 0.6–0.8, roughness 0.5–0.7, rust in the roughness map.
- **Cloth:** roughness 0.95, low-value crimson or black.
- **Emission** is reserved for telegraphs (red), interactables (gold), friendly magic (teal) and portals (amber). Static props never emit.
- **One material per mesh where possible.** At most 4 for an environment piece and 2–3 for a character (body, weapon, optional emissive).

## 7. Lighting

- **Key light:** one cold moonlight `DirectionalLight3D` (exists), roughly 45° down from upper-left-behind, so tops and front edges catch light.
- **Fill:** cool ambient (0.29, 0.31, 0.46) at 0.75 (exists).
- **Accent lights:** warm `OmniLight3D` only on interactables (merchant lamp, reliquary). There is a budget for dynamic lights; see section 10.
- **Fog:** Compatibility-safe fog (depth fog in `Environment` where Web supports it) or **alpha fog cards** between depth layers. Never volumetric fog.
- **Rim:** enemies and the Bishop rely on the moonlight rim. Avoid back-facing geometry that blocks it.
- **Telegraphs stay unshaded.** They must read identically in light and shadow.

## 8. Asset families

### Player knight ("Cursed Knight")
- About 1.8 m tall, matching the collision capsule (r 0.35, height 1.7).
- Blackened steel plate with worn silver edges, tattered dark cape, longsword. Teal accents only on the Grave Shield VFX, never on the base material.
- The sword exists only visually; the hitbox stays in code.
- Must survive the downed pose: the code rotates `VisualRoot` 90° on Z, so the mesh must look acceptable lying on its side.

### Plagued Soldier (and Husk variant)
- Rotting conscript in mail and leather, sickly olive skin, a rusted falchion held high.
- Readable wind-up arc on the blade.
- The Husk reuses the same mesh at 0.85 scale with a bone-pale material variant (`EnemyFactory.husk()`). No separate model.

### Bone Archer
- A gaunt skeleton with a tall bone-and-sinew bow. Bow height at least as tall as the head, so the aim pose reads.
- The aim line telegraph stays in code.

### Crypt Hound
- A long, low, emaciated hound with an exposed ribcage.
- Its crouch-before-bite must change the silhouette (head down, haunches up).

### The Hollow Bishop
- A skeletal colossus about 30 m tall, standing 22 m behind the play plane.
- Robe and ribcage with a crimson heart (low value when shut). Bone skull under a cracked mitre (dark crimson cloth, gold trim).
- Built as **separate meshes that match the code's node layout**: robe, ribcage, spine, shoulders, skull, mitre, idle arm, heart, slam arm. `hollow_bishop.gd` animates parts and stretches the slam arm every frame.
- **The slam hand is its own asset** (`BishopHand`): palm, four fingers and a thumb as separate meshes. The **stigmata weak point** is a socket in the palm centre, with its own small mesh so the code can light it. The open stigmata glows white-gold (see section 4).
- No boss collision on the body, as in the code today. Only the hand has collision, and that stays the code's box shapes.

### Causeway / cathedral kit
- **Modular, 4 m on X, 4 m deep, 1 m tall**, with the pivot at the box centre to match `_make_solid`. Ashlar front face toward +Z, paved top, coping lip.
- Variants: plain, broken edge, cracked (for collapsing and breakable pieces), end cap, short 2 m.
- **Cathedral:** door, portcullis, arches and pillars (backdrop layer), a buttress flank wall, distant towers and spires (far layer, low-poly).

### Props
- **Blood Altar:** a stone pillar with a basin of dark blood and a gold rim glow (reward = gold).
- **Bishop's Reliquary** (loot chest): a gilded coffin-reliquary, gold. The lid light should be warm gold, not red.
- **Spike trap:** an iron grate plate with bone spikes. The red flash stays in code.
- **Pendulum:** an iron arm and a crescent blade. The edge catches moonlight; no red emission unless swinging toward the player is the telegraph.
- **Bone bridge** (card): fused vertebrae and long bones, ivory with a faint teal (friendly) glow while summoned.
- **Checkpoint:** a votive banner pole. The active state is gold flame, not crimson.
- **Merchant:** a pale, tall, hooded figure behind a cluttered table, lit by a cold lamp.

## 9. Per-asset budgets

The targets assume a mid-range PC at 60 fps and a Web (WebGL2, Compatibility) build that should hold 60 fps on integrated graphics. A **Web budget** is the asset as shipped in the Web export: use a LOD or decimated variant when the desktop number is higher.

| Asset class | Desktop tris | Web tris | Textures (desktop / web) | Materials |
|---|---|---|---|---|
| Player knight | 20–30k | 10–12k | 2k set / 1k set | 2 (body, sword) |
| Common enemy (Soldier, Archer, Hound, …) | 8–15k | 4–6k | 1k set / 512 set | 1–2 |
| Elite (Gravewarden) | 15–25k | 8k | 2k / 1k | 2 |
| Hollow Bishop body, total | 40–60k | 20–25k | 2× 2k / 2× 1k | ≤ 5 |
| Bishop slam hand | 6–10k | 3–4k | 1k / 512 | 1–2 |
| Causeway segment (4 m) | 1.5–3k | 1.5k | Shared stone trim 1k / 512 | ≤ 4 |
| Backdrop wall / pillar | 0.5–2k | 0.5–1k | Shared trim | 1–2 |
| Distant towers / skyline | 0.2–1k each | same | Vertex colour or 256 | 1 |
| Small props (altar, chest, spikes, lever, banner) | 0.5–3k | 0.5–1.5k | 512–1k / 256–512 | 1–2 |
| Pendulum, bone bridge, ferry | 1–3k | 1k | 512 / 256 | 1 |

Scene totals:

- **Desktop:** at most 300k visible tris, at most 250 draw calls, at most 4 shadowed lights.
- **Web:** at most 120k visible tris, at most 120 draw calls, 1 shadowed light (the moon), and at most 64 MB of textures in VRAM. Import textures as VRAM Compressed. The Web export ships desktop formats (S3TC/BPTC); add ETC2/ASTC only if mobile browsers become a target. See `docs/WEB_EXPORT.md`.

Measure in-engine with the Godot Monitors panel before an asset is marked done.

## 10. Readability rules (checklist for every asset review)

1. Seen at gameplay distance in the real camera, the silhouette identifies the asset in under half a second.
2. The walkable top surface is lighter than its sides and lighter than the backdrop behind it.
3. No bright or emissive red anywhere on the asset unless it is a telegraph driven by code.
4. Bone/ivory value separates every enemy from the stone behind it.
5. The visual stays inside the collision volume within ±10 cm on the front face and the walkable top. A ledge that looks walkable must be walkable.
6. The pivot and scale match the greybox node it replaces (see `docs/ASSET_LIST.md`), so collision code is untouched.
7. The asset works in the Compatibility renderer with the Web texture variant (check one screenshot).
8. Reduced-gore mode: blood decals and gore pieces have an ash-grey variant; base meshes contain no baked blood.

## 11. Provenance

Every external file needs an entry in `assets/manifests/assets.json` (source, licence, approval,
tris, scale). Only CC0, CC-BY (with credit in the manifest and credits screen), original Blender
work, or user-approved paid generation (Tripo3D) are allowed. Kenney and OpenGameArt CC0 kits in
the local library are licence-clean, but their style (toy-like, village) only suits greyblocking
or heavily reworked pieces.

## 12. Concept references

These were generated on 2026-10-21 with ChatGPT (web, the user's account) from text prompts only;
no project files were uploaded. They live in `assets/concepts/`, which has a `.gdignore`, so
Godot never imports or exports them. They are mood and shape references, not designs to copy one
to one. Provenance is in `assets/manifests/assets.json`.

| File | Use it for | Notes |
|---|---|---|
| `00_moodboard.png` | Palette, materials, the "only red is danger" rule | Six panels plus a swatch strip. |
| `01_player_knight.png` | Knight silhouette, plate, cape and pauldron | Front, side and back views plus a silhouette. A Tripo3D reference candidate (needs upload approval). |
| `02_plagued_soldier.png` | Hunch, falchion wind-up, bone and rag read | Idle and wind-up side views plus a silhouette. |
| `03_hollow_bishop.png` | Scale and composition, mitre and ribcage, a white-gold stigmata in the palm, a red slam zone on the causeway | The best match to sections 4 and 8. Use it as the boss art target. |
| `04_causeway_frame.png` | Depth layers, the lit walkable top, the arcade causeway, skyline spires | The causeway kit (#1–#11 in the asset list) follows this. |

Using any of these as an image input for Tripo3D sends it to a third party. Ask first.
