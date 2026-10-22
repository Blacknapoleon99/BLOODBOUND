# BLOODBOUND — Prioritized asset list

The style rules and budgets are in `docs/ART_BIBLE.md`. Order follows the vertical slice:
**environment kit → player → enemies → the Hollow Bishop**. Status: ✅ in game, 🟡 next, ⬜ later.

## Integration contract (applies to every row)

- **Visual only.** A model replaces a greybox `MeshInstance3D` (BoxMesh, CapsuleMesh and so on). The collision shapes, hitboxes, hurtboxes, Area3Ds and scripts stay exactly as they are in code. The greybox mesh is hidden, not deleted, and the model is added beside it. See `scripts/art/art_swap.gd`.
- **Units:** metres. Godot is Y-up and Blender is Z-up. The glTF export (Y-up) maps Blender +X → Godot +X, Blender +Z → Godot +Y, and Blender −Y → Godot +Z.
- **The camera looks down −Z.** Faces that show toward the camera are +Z in Godot, which is −Y in Blender.
- **Pivots:**
  - Level boxes: the centre of the box, matching `BoxMesh` and `_make_solid`.
  - Characters: the centre of the collision capsule, because CharacterBody3D origins sit at the capsule centre. Feet are therefore about −0.85 m.
  - Props: as stated in their row.
- **Facing:** characters face +X (the side-scroll "right"). The code flips them by scaling or rotating `Visual` / `VisualRoot`. Confirm in a Godot test before rigging.
- **Animated characters:** one GLB, with animations named `idle`, `run`, `jump`, `fall`, `land`, `dodge`, `attack_1..3`, `heavy`, `hurt`, `death`, plus extras per row. The gameplay session wires an AnimationPlayer. Until then, state machines keep driving the greybox.
- **Files:**
  - Shipping GLB: `assets/models/<family>/<id>.glb`.
  - Editable source `.blend`: `assets/source/<family>/` (Godot ignores this folder through `.gdignore`).
  - Raw third-party downloads: `assets/incoming/<id>/`, which is git-ignored.
  - Provenance: `assets/manifests/assets.json`.

### Source routes

| Code | Route | Cost | Notes |
|---|---|---|---|
| **BL** | Original modelling in Blender (via the Blender MCP) | Free | We own it. Best for modular architecture and hard-surface props. |
| **PH** | Poly Haven CC0 textures, HDRIs and models | Free | Needs the Blender addon's Poly Haven library switched on (currently off), or a manual download with the user's OK. |
| **PP** | Poly Pizza (CC0 / CC-BY) | Free | Low-poly stylized. Greybox upgrade or kitbash parts only. |
| **LL** | Local library `D:\AZCoreHasse\Projects\3dgenlocal\MedievalAssets` | Free | Kenney castle and dungeon kits (CC0), OpenGameArt medieval props and houses (CC0, some CC-BY). Style is village/toy-like: use for kitbash parts and greyblock, not hero pieces. The asset index is stale: the CGTrader and Gumroad folders it lists no longer exist. |
| **T3D** | Tripo3D generation (`tripo-cli`), then Blender cleanup | **Paid credits** | Characters and organic creatures. Each batch needs the user's approval. |

## P0 — Environment kit (opening causeway, approach, arena)

| # | Asset id | Replaces (greybox node) | Size / pivot | Route | Status |
|---|---|---|---|---|---|
| 1 | `causeway_segment_4m` | `main.gd _build_greybox`: **"Starting causeway appearance"** (12×1×4, tiled ×3) | 4×1×4 m, pivot at centre, top at +0.5 | BL | ✅ pipeline test (1,936 tris, 4 materials) |
| 2 | same, rolled out | "Battle causeway", "Gate causeway", "Approach causeway", "Approach landing", "Arena threshold" (`_build_greybox`, `_build_approach`) | Tiled; ArtSwap stretches X by ≤ ±15% | BL | 🟡 add labels to `ArtSwap.CAUSEWAY_SOLIDS` after a visual check |
| 3 | `causeway_segment_2m`, `causeway_endcap` | "Broken stone span" (3×0.7×3.7) and the exposed ends of every run | 2×1×4 m and 0.5×1×4 m | BL | 🟡 |
| 4 | `section_ground_*` | `LevelSection._block` (`ground` / `ledge` / `block`) in every `scripts/level/sections/*` room | Width varies × height × 4; palette per section through material tint | BL (same kit) | 🟡 needs ArtSwap support for `_block`'s mesh name |
| 5 | `causeway_breakable_4m` + `causeway_rubble` | `BossArena.build` → BreakableSegment "Bishop causeway N" `Slab` (3.96×1×4); "Rubble ledge" (1.6×0.4×3) | Same as #1, with an intact and a broken state | BL | ⬜ |
| 6 | `slab_collapsing` | `CollapsingSlab` mesh (2.5×1×4) | Centre pivot; crack lines and pre-broken chunks for the fall | BL | ⬜ |
| 7 | `floor_cracked` | `BreakableFloor` "Cracked floor" (2×1×4) | Centre pivot | BL | ⬜ |
| 8 | `portcullis` | `main.gd` "Portcullis bars" (0.3×5×3.6) | Centre pivot; iron grid | BL | ⬜ |
| 9 | `cathedral_door` | "Cathedral door" (1.2×7×4) | Centre pivot | BL | ⬜ |
| 10 | `backdrop_wall_9m`, `backdrop_pillar` | `LevelSection._backdrop`: wall (width×16×0.5 at z −6), pillars (1.2×14×1.2 every 9 m, z −5) | Wall tiles by 9 m; pillar pivot at centre | BL + PH textures | ⬜ |
| 11 | `skyline_tower_a/b`, `gothic_spire` | "Left tower", "Distant tower", "Distant Gothic silhouette" (z −18 to −26) | Centre pivot; ≤ 1k tris; vertex colour | BL | ⬜ |
| 12 | `stone_trim_1k` material set | Shared by #1–#11 | 1k albedo, normal and ORM trim sheet | PH (CC0) or a BL bake | 🟡 needs the PH library or a download approval |

## P0b — Props and hazards

| # | Asset id | Replaces | Size / pivot | Route | Status |
|---|---|---|---|---|---|
| 13 | `prop_blood_altar` | `blood_altar.gd`: pillar (0.7×1×0.7 at z −1.2) and bowl | Pivot at floor centre of the node | BL | ⬜ |
| 14 | `prop_reliquary` | `loot_chest.gd` "BishopReliquary": body 1.2×0.7×0.8 and lid (lid is a separate mesh so the code can open it) | Pivot at floor centre | BL | ⬜ |
| 15 | `hazard_spike_plate`, `hazard_spike` | `spike_trap.gd`: plate (width×0.04×2.6) and cones (r 0.14, h 0.9). Cones stay separate so the code can raise them. | Spike pivot at its base | BL | ⬜ |
| 16 | `hazard_pendulum` | `pendulum_blade.gd`: rod (0.12×arm×0.12) and blade (1.6×0.5×0.15). Rod and blade are separate; the rod scales with arm length. | Blade pivot at the rod joint | BL | ⬜ |
| 17 | `bone_bridge` | `cards/bone_bridge.gd` "OssuaryBridge" (length×0.4×2.4) | Tiles along X; centre pivot | BL | ⬜ |
| 18 | `bone_ferry` | `moving_platform.gd` "Bone ferry" (3×0.6×4) | Centre pivot | BL | ⬜ |
| 19 | `prop_checkpoint_banner` | `checkpoint.gd` "Banner" (0.18×2.2×0.18 at z −0.9) | Pivot at the pole base | BL | ⬜ |
| 20 | `prop_lever` | `lever_shortcut.gd` "Handle" (the bridge reuses #17 or #1) | Pivot at the hinge | BL | ⬜ |
| 21 | `prop_merchant_stall` + `npc_pale_merchant` | `merchant_stall.gd`: table (2.4×0.9×1) and capsule (r 0.35, h 2) | Floor pivot | BL (stall); T3D or BL (merchant) | ⬜ |
| 22 | `ambush_bone_wall` | `ambush.gd` bone wall (0.6×6×3) | Centre pivot | BL | ⬜ |

## P1 — Player

| # | Asset id | Replaces | Size / pivot | Route | Status |
|---|---|---|---|---|---|
| 23 | `player_cursed_knight` ✅ (Tripo, rigged, 11 clips) | `scenes/player.tscn` `VisualRoot/PlaceholderKnight` (CapsuleMesh r 0.35, h 1.7). Hurt flash and `body_color` currently tint this material. | 1.8 m tall; pivot at the capsule centre (feet −0.85) | **T3D** (mesh), then BL cleanup, rig and animation | ⬜ needs credits and a rig plan |
| 24 | `weapon_longsword` | (none: there is no sword mesh today; the attack is a hitbox) | Pivot at the grip; attach to a hand bone | BL | ⬜ |
| 25 | `vfx_grave_shield` | `player.gd _build_shield_visual` "GraveShieldWard" sphere | Keep as a shader or sphere; teal | Godot | ⬜ |

Animations needed (#23): idle, run, jump, fall, land, dodge, attack_1–3, heavy, hurt, death,
downed, revive, card_cast. Free rigging options are Rigify in Blender or Mixamo. **Mixamo uploads
the mesh to Adobe, which counts as a third-party upload and needs the user's OK.**

## P2 — Enemies (common first)

| # | Asset id | Replaces | Size / pivot | Route | Status |
|---|---|---|---|---|---|
| 26 | `enemy_plagued_soldier` ✅ (rigged, 5 clips) | `scenes/enemies/plagued_soldier.tscn` `Visual`: Body (capsule r 0.4, h 1.8), Head, Blade | 1.8 m; capsule-centre pivot; the blade is a separate node for the wind-up | T3D, then BL rig | ⬜ |
| 27 | (Husk) | `EnemyFactory.husk()`: the same scene at 0.85 scale | Material variant of #26 only | — | ⬜ |
| 28 | `enemy_bone_archer` ✅ (rigged, 5 clips) | `bone_archer.gd _build_visual`: body capsule (r 0.3, h 1.75) and "Bow" (0.08×1.2×0.08) | 1.8 m; the bow is a separate mesh | T3D, then BL | ⬜ |
| 29 | `enemy_crypt_hound` ✅ (rigged, walk) | `crypt_hound.gd _build_visual`: body box (1.0×0.45×0.35 at y −0.4) and "Head" | About 1.1 m long; pivot at the collider centre | T3D, then BL | ⬜ |
| 30 | `enemy_shielded_knight` ✅ (rigged, 5 clips) | `shielded_knight.gd _build_body`: "Body" and "Shield" (the shield moves in code, so it stays a separate mesh) | 1.9 m | T3D | ⬜ |
| 31 | `enemy_flying_wraith` ✅ (static) | `flying_wraith.gd`: "Shroud" (alpha) and "Skull" | 1.0 m | T3D or BL | ⬜ |
| 32 | `enemy_bone_crawler` | `bone_crawler.gd`: "Carapace" and "Legs" | 0.7×0.5 | BL | ⬜ |
| 33 | `enemy_gravewarden` ✅ (rigged, 7 clips) | `gravewarden.gd _build_body`: "Armour", "Maul handle", "Maul head", "Helm" | 2.6 m elite | T3D | ⬜ |
| 34 | `proj_bone_arrow`, `proj_bone_lance` | `bone_arrow.gd` (0.9×0.08×0.08); `bone_lance.gd` "Shaft" (0.28×0.28×3.4) | Pivot at the centre, pointing +X / +Z as in code | BL | ⬜ |

## P3 — The Hollow Bishop (last)

| # | Asset id | Replaces (`hollow_bishop.gd _build_body` unless noted) | Size / pivot | Route | Status |
|---|---|---|---|---|---|
| 35 | `boss_bishop_robe` ✅ whole body as one rigged model (7 clips) | Robe 7×22×4 at y −1 | Parts are positioned in boss-local metres exactly as in `_build_body`, about 30 m total | T3D concept mesh, then BL split into parts (or full BL) | ⬜ |
| 36 | `boss_bishop_ribs`, `_spine`, `_shoulders` | Rib0–4, Spine, Shoulders | Each part's pivot at its greybox box centre | BL | ⬜ |
| 37 | `boss_bishop_skull`, `_mitre`, `_eyes` | Skull (sphere r 2.3), Mitre (2.6×4.2×1.6), Eye ×2 (eyes stay separate so the code can light them) | Same as above | T3D or BL | ⬜ |
| 38 | `boss_bishop_heart` | Heart (sphere r 0.9); pulse driven by code | Centre pivot | BL | ⬜ |
| 39 | `boss_bishop_arm_idle`, `_arm_slam` | LeftArm (0.9×9×0.9); SlamArm (stretched from shoulder to hand every frame: model it as a unit-length forearm along its local axis) | Unit-length segment, pivot at the shoulder end | BL | ⬜ |
| 40 | `boss_bishop_hand` ✅ (static; moved by code) | `bishop_hand.gd`: Palm (2.4×0.6×2.2), Finger0–3, Thumb, **Stigmata** (sphere r 0.45 at y 0.35). Each digit stays a separate mesh; the stigmata is a separate small mesh lit by code. | Hand pivot at the palm centre | T3D or BL | ⬜ |
| 41 | `boss_censer`, `boss_beam_pillar` | `censer_sweep.gd` bowl and chain; `requiem_beam.gd` pillar | Centre pivot | BL | ⬜ |

Telegraph plates and lines (`SlamTelegraph`, lane, band and ring markers) **stay code-driven
unshaded red**. They are never replaced by art.

## Player hero: Bone Revenant (chosen 2026-10-22)

- **Concept:** `assets/concepts/player_variants/c_bone_revenant.png`.
- **Turnaround:** `assets/concepts/refs/revenant_tpose.png`. It is a T-pose with the sword sheathed on the back in every view, and short cloth so the joints read.
- The Blood Knight stays in the game as a placeholder until the Revenant replaces it.

### Mesh and rig options (researched; nothing spent)

| Option | Credits | For an animated hero |
|---|---|---|
| **H3.1 HD Model (multiview), private** | **30** | Proven here: 5 humanoids generated and auto-rigged cleanly from T- or A-pose sheets. About 28k tris, 2k PBR, GLB. |
| Smart Mesh P2.0 (quad) | 100–130 | A Preview model. Studio shows it as "Sharing Only", which means public, not private. Quads force FBX (Godot imports FBX, but our pipeline is GLB). Tripo claims joint edge loops; an independent review finds no proof. No built-in rig. |
| Generate in Parts | +20 | Forces textures off; parts come back as separate meshes. That helps rigid props, but skinned characters get seams at the joints. **Not for the hero.** |
| Quad remesh / Smart low-poly | +5 / +10 | Topology cleanup only. Godot triangulates anyway, and good deformation comes from skin weights more than quads at 25k tris. |
| Tripo Auto Rig (Mixamo skeleton) + presets | 20; presets free | Worked for the knight (T-pose), Soldier, Archer, Shield Knight, Gravewarden and Bishop. Clips import into Godot's AnimationPlayer with "stay in place" (no root motion). |
| Mixamo rig instead | free | Better weights and a huge animation library, but it uploads the mesh to Adobe, so it needs the user's OK. Use only if Tripo's weights deform badly at the elbows or knees. |
| Blender Rigify | free | Full control, but hours of manual weight painting. Use as a last resort. |

**Recommendation:**

1. Generate H3.1 HD multiview from the T-pose sheet (30 credits).
2. Run Tripo Auto Rig (20 credits).
3. Apply the same 11 free presets as the knight.
4. In Blender: cut the sheathed sword off as its own prop (the hand sword is a separate attachment), decimate to about 25k tris, and keep 2k textures.

The test costs **50 credits**. If the elbows or knees deform badly, fall back to Mixamo weights (free, with your OK) before spending on Smart Mesh.

### Revised hero pipeline: separate sword, draw/sheathe, cloth physics (2026-10-22, nothing spent)

**References:**
- **Body:** `assets/concepts/refs/revenant_tpose_v2.png`. Empty hands, an empty scabbard strapped diagonally on the back (it reads side-on whichever way he faces), and cloth as separate panels with gaps: a hood tail, 2 front and 2 back belt panels above the knees, and shoulder rags.
- **Sword:** `assets/concepts/refs/revenant_sword.png`, a 1.1 m bone-and-iron sword shown front and edge-on.

**Steps:**

| # | Step | Where | Credits |
|---|---|---|---|
| 1 | Body: H3.1 HD multiview from the v2 sheet (private) | Tripo Studio | 30 |
| 2 | Body: Tripo auto-rig (Mixamo skeleton) + free presets (idle, run, walk, jump, fall, slash, chop, dive, hit, defeat, cast) | Tripo Studio | 20 |
| 3 | Sword: HD model from the front and side views (a separate asset, never cut out of the body) | Tripo Studio | 30 |
| 4 | Blender (scripted through the MCP): <br>• a 3–5 bone chain down each cloth panel and the hood tail, with the panel vertices weighted to it <br>• a `Sheath` bone on the upper spine at the scabbard <br>• `draw` and `sheathe` clips keyframed on the right arm (reach over the shoulder, about 0.3 s each) <br>• decimate to about 25k tris, 2k textures | Blender | 0 |
| 5 | Godot, art layer only (`scripts/art/`): <br>• `BoneAttachment3D` sockets **WeaponHand** (`mixamorig:RightHand`) and **WeaponSheath** (`Sheath`) <br>• a sword controller that reparents the sword between them <br>• `SpringBoneSimulator3D` on the cloth chains, with `SpringBoneCollisionCapsule3D` on the thighs, hips and spine (verified in Godot 4.7.2) <br>• an `AnimationTree` with an upper-body blend, so draw and sheathe play while running | Godot | 0 |
| — | Optional: draw and sheathe from Tripo text-to-motion, if the Blender-keyed clips look stiff | Tripo Studio | 40 |
| — | Optional: Mixamo draw/sheathe clips | Mixamo | 0, but uploads the mesh to Adobe; needs OK |

**Total: 80 credits (120 with Tripo motions). Balance is 1,955.**

**Draw and sheathe behaviour** (visual only; it reads gameplay signals and changes nothing else):

- The sword stays sheathed when idle or exploring.
- On the first `attack_started`, the right arm snaps into a fast draw and the sword moves to WeaponHand on the grab frame, so the swing continues straight on. Hit timing is unchanged, because hitboxes stay in code.
- The sword auto-sheathes after about 4 s with no attack and no living node in the `enemy` group (dead ones skipped via `is_dead()`) within about 8 m of that sword's own player. In co-op each player is checked separately.
- Card casting uses the free left hand (the `cast_a_spell` clip).

**Risks:**

- Tripo may still fuse a cloth panel to a leg. Fix: separate it in Blender (free).
- Spring-bone cloth needs tuning (stiffness and drag per chain).
- The front view doesn't show the scabbard strap, so the generated strap may come out simplified.

**First test, 50 credits:** steps 1 and 2. Check the rig, joint deformation and whether the cloth panels separate. Only then run the sword (step 3) and the Blender/Godot work.

## Animation wiring (2026-10-22)

`scripts/art/art_animator.gd` (visual-only) drives every rigged model from gameplay:

- **Locomotion:** idle, walk or run comes from the body's velocity (from position change for the Bishop). The player falls when airborne and descending.
- **Player:**
  - `attack_started` plays slash, or chop for a heavy attack.
  - `dodge_started` plays dive.
  - `jumped` plays jump.
  - `hurt` plays hit.
  - `died` plays defeat.
  - The model turns to face the player's direction.
- **Enemies** (from `state_changed`):
  - A wind-up or attack state starts the attack clip, so the swing is the telegraph.
  - Hitstun or stagger plays hit.
  - Aim plays shoot.
  - Dead plays defeat.
  - The Gravewarden roars on the charge wind-up and runs while charging.
- **The Bishop:**
  - `attack_started` plays chop for slam and sunder, `cast_a_spell` for beam, barrage and summon, and slash for anything else.
  - `phase_changed` plays a roar.
  - `defeated` plays defeat.

Proof: `tests/shot_art_anim.gd` writes the frame strips `docs/screenshots/18_anim_soldier.png` and `18_anim_bishop.png`.

## Tripo3D cost plan (checked 2026-10-21): use the web Studio, not the API

**Use the Tripo Studio web app** (studio.tripo3d.ai in Chrome), at the user's request.

**Account:** ravenisafk, **Max** plan, **2,435 credits**. **2,135 of them expire on 2026-10-30**, together with the plan, so they should be spent first. A separate API key account (`tripo-cli`) holds 0 credits and is not used.

**Studio prices** (seen in the UI and in the account's usage history):

| Action | Credits |
|---|---|
| HD Model (H3.1 Best Quality), image or multiview, private | 30 |
| Text to Model | 30 |
| Text to Motion (animation) | 20 |
| Smart Mesh P2.0 | 100, and "Sharing Only" (public), so **don't use it** |
| Auto rig | Shown once a model is selected; the API charges 25 |

**Plan:**

- HD Model from multiview crops of the concept sheets (30 credits each).
- Decimate, pivot and scale in Blender (free).
- Rig in Studio.
- Generate Motion only for moves the CC0 humanoid packs lack. Everything else is retargeted in Godot for free.

| Asset | Credits |
|---|---|
| Player knight | about 30 + rig + 4 motions ≈ 135 |
| 6 rigged enemies (about 30 + rig + 2–3 motions each) | ≈ 600 |
| Flying Wraith (no rig) | 30 |
| Bishop body and hand (no rig) | 60 |
| Retries (one each) | ≈ 300 |
| **Total** | **about 1,100**, which fits inside the expiring 2,135. No purchase needed. |

## Needs from the user (paid or third-party)

1. **Tripo3D credits** for the characters, one batch at a time, each with your approval. About 12 base generations, plus retries for each:
   - 1 player knight
   - 7 enemies: Soldier, Archer, Hound, Knight, Wraith, Gravewarden, plus an optional merchant
   - Bishop concept: 1 body and 1 hand
   - Budget 2–3 attempts per asset.
   - The per-credit price was not checked. Run `tripo --help` and check the account balance first.
2. **Rigging route:** Rigify (free, local) or Mixamo (a free account, but it uploads the mesh to Adobe).
3. **Poly Haven:** switch on the library in the Blender addon panel (N → MCP for Blender), or approve a manual download of a CC0 stone texture set for the shared trim (#12).
4. **Blender MCP addon update:** the addon reports protocol 5 against the server's 13, and the update command is `uvx mcp-for-blender install-addon`. It still works for code execution. Review the release before updating.
