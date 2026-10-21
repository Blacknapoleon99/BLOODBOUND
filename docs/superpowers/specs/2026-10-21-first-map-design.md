# First map: "The Hollow Covenant" — design

## Intent

Right now the Hollow Bishop is reached in about a minute. The first map should take **about 10 minutes** to reach him, so he feels like the end of a real level: the tutorial boss of act one. The level is the playground for everything built so far: cards, relics, items, ambushes, hazards and enemy abilities. It must also settle the environment kit before art starts, because the asset list comes from the map.

Decided with the user:
- **Structure:** handmade rooms in a **random order every run** (Dead Cells / Hades style); fixed start and fixed boss approach.
- **Content:** an **elite mini-boss**, a **merchant/shop**, **secrets and shortcuts**, and **new enemy types**.

## Goals

- **Length:** a first-time run reaches the Bishop in roughly 8–12 minutes; a skilled run in about 5.
- **Variety:** each run deals a different room order (seeded by the run seed, so a seed always rebuilds the same map). No two runs feel identical, but every map has the same shape and difficulty curve.
- **Pacing:** there is a rhythm. Fight → traverse → reward/rest → harder fight, with difficulty rising room by room.
- **Completable:** every room is always completable with the base moveset (run 8.5 m/s, ~2 m jump, ~5.6 m running jump, dodge). Cards and items help but are never required. An automated check proves the geometry of every room is reachable.

## Non-goals (for now)

- No final art: everything stays greybox until the asset phase. The rooms define the environment kit.
- No minimap, no save mid-run, no meta-progression beyond the existing Armory.
- No procedural geometry: rooms are hand-designed; only their **order** and some **contents** vary.

## Anti-goals

- Random order that produces an impossible or unfair sequence (two brutal rooms back to back early, an unreachable exit).
- Padding: long empty corridors to hit 10 minutes.
- Breaking the existing 373 checks or the current playable flow.

## Map shape (one run)

| # | Section | Fixed / random | ~Time |
|---|---|---|---|
| 0 | **Opening**: today's start (tutorial causeway, plagued soldier, portcullis, fracture gate, gate ossuary ambush + altar) | fixed | 1:00 |
| 1–3 | **Act I rooms**: 3 drawn from the easy pool | random | 3 × 1:00 |
| 4 | **Elite room**: *The Gravewarden* mini-boss + reliquary-style reward (relic choice) | fixed slot | 1:30 |
| 5–7 | **Act II rooms**: 3 drawn from the hard pool | random | 3 × 1:15 |
| 8 | **Merchant room**: *The Pale Merchant* (shop + altar + checkpoint) | fixed slot | 0:30 |
| 9 | **Pursuit approach + Bishop arena**: today's | fixed | 1:00 + fight |

There is a checkpoint at the entrance of every section. Dying respawns you there, resets that room's encounter and keeps everything else.

## Room pools (greybox, hand-designed)

Each room is about 40–70 m wide, enters at floor height on the left and exits at floor height on the right. It mixes traversal, combat and one optional secret.

**Act I pool (draw 3 of 5):**
1. **Crypt Stairs**: a vertical climb up stepped ledges and back down; archers on high ledges; a secret alcove behind a breakable wall at the top.
2. **Flooded Nave**: low corridor with spike-trap strips in sequence and Husks; a timing run.
3. **Ossuary Ambush**: an ambush arena (hounds and husks) with an altar as the reward.
4. **Bell Tower Gap**: wide gaps crossed by moving platforms under a pendulum; a crawler nest.
5. **Catacomb Crawl**: low ceilings, Bone Crawlers in tunnels, a breakable floor dropping to a secret cache.

**Act II pool (draw 3 of 5):**
6. **Collapsing Gallery**: chains of collapsing slabs over a long pit while archers shoot; it rewards Shadow Step and Ossuary Bridge.
7. **Blade Corridor**: twin pendulums plus spike traps in rhythm, then a Shielded Knight at the exit.
8. **Wraith Belfry**: vertical platforming while Flying Wraiths dive; you cannot stay still.
9. **Charnel Arena**: a two-wave ambush mixing every enemy type, Shielded Knight included.
10. **Sunken Reliquary**: a branching room (high road: hazards and a better reward; low road: an easier fight); a shortcut lever.

**Ordering rules:** the shuffle is seeded by `RunState.seed_value`. There is never the same room twice. Act I rooms come only from the easy pool and Act II only from the hard pool. Each room declares a difficulty value, and inside each act the rooms are ordered by ascending difficulty, with a small random swap allowed.

## New enemies

- **Shielded Knight**: a tower shield blocks hits from the front (sparks, no damage, a small knockback on you). A heavy hit, Grave Hook or a hit from behind breaks its guard briefly. It shield-bashes (telegraphed charge). 6 HP.
- **Flying Wraith**: floats over gaps and hazards and ignores gravity. It telegraphs a dive along a red line, then drifts back up. 2 HP; dies to one finisher.
- **Bone Crawler**: small and fast. It scuttles at you, glows, and bursts after 0.8 s (StrikeZone). Killing it first with any hit makes it burst early where it stands.

## Elite mini-boss: The Gravewarden

A huge armoured knight (30 HP, poise 6) in a closed arena. Three moves, all telegraphed:
- **Crypt Charge** (dash across the arena, wall-stun on a dodge);
- **Grave Quake** (ground slam sending spike waves both ways, jump them);
- **Raise Guard** (summons two Bone Crawlers).

Below 50% HP it enrages: faster, with chained charges. Its reward is a reliquary with a **relic choice** plus 40 Bone Shards. An HP bar shows its name.

## Currency and merchant

- **Bone Shards:** dropped by every enemy (1–3; elites 40), lasting the run only, shown in the HUD. The Leech Fang–style relic hooks (`on_combatant_died`) handle drops.
- **The Pale Merchant** sells 4 items per visit, randomised from the run seed:
  - a card (~30 shards);
  - a relic (~60);
  - a full heal (~25);
  - a card upgrade (~40).

  The prices scale slightly with act. The merchant uses the existing offer overlay with prices on the buttons; things you can't afford are refused with a reason.

## Secrets and shortcuts

- **Breakable walls and floors:** a cracked texture (in greybox, a different colour plus hairline marks). Two heavy hits or one Blood Nova breaks them. Behind them are shard caches, a free card pick, or a relic (rarely).
- **Shortcuts:** some rooms have a lever-gate at the far end. Opening it creates a one-way passage back to the room's entry checkpoint, so a death late in a long room skips the part already cleared.
- **The Reality Fracture** (today's optional 3D arena) stays in the opening as the first secret-ish side area.

## Architecture (builder's notes)

- **`LevelSection` base** (`scripts/level/sections/*.gd`), one script per room. It has `build(origin_x) -> width` and creates its own solids, hazards, enemies, ambush, altar, secrets and checkpoint at its origin. It also exposes metadata: `act`, `difficulty`, an `id`, and a list of **platform rectangles** for the reachability check.
- **`LevelLayout`** chooses the run's sections from the seed and records the order (shown in the pause menu as "Map: …" for bug reports).
- **`main.gd`**:
  - builds the opening, then the chosen sections starting at x = 18.2, then the approach and arena shifted by the total section width;
  - the old position constants become offsets;
  - the HUD shows the room name, act and shards.
- **`LevelLayout.classic`:** when true (scripted tests), no middle sections are inserted, so the classic layout and every existing check stay identical. New checks run the full map.
- **Tests:**
  - a reachability validator per room over the declared platforms, using the player's real jump limits;
  - seed determinism (same seed → same order) and the ordering rules;
  - each new enemy's moves;
  - the Gravewarden's moves, enrage and reward;
  - the shop (buying, refusals, shards), secrets breaking, and shortcut gates;
  - an end-to-end bot run that teleports through each room's checkpoints to the arena.

## Order of work

1. Section framework + `LevelLayout` + classic mode (existing tests still green).
2. Bone Shards + the three new enemies.
3. Act I rooms, then Act II rooms (reachability validator first).
4. Gravewarden elite.
5. Merchant.
6. Secrets and shortcuts.
7. Full-map tests, a timed bot traversal, a build, and a playtest by the user.

## Left to the builder

Exact room geometry, numbers (HP, prices, drop rates), colours of greybox materials, and which room hosts which secret. These are all tunable after the first playtest.
