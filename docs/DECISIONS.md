# Architecture decisions

## DEC-001 — Godot 4.7 with GDScript / Compatibility

Reason: human-readable scenes and scripts suited to agentic editing, native 3D physics and camera control, reasonably straightforward browser/WebGL2 export. Unreal would be more demanding for this lightweight prototype. Revisit only after real browser/performance benchmarks.

## DEC-002 — Gameplay first, external models later

Tripo/Blender pipeline is designed, not run. Placeholder assets enable continuous progress even with no external API access or budget.

## DEC-003 — Arena uses shared player

2.5D side view and 3D arena will use the same body/health/combat identity, with different movement constraints and camera modes.

## DEC-004 — Jev AI identity pending

No uniquely verified integration endpoint found at packaging time. Ask the user for the official service link before connecting it.

## DEC-005 — Input actions registered by `InputBindings`

Gameplay reads only action names (`move_left`, `jump`, `dodge`, …). `scripts/input_bindings.gd` registers keyboard and gamepad defaults at runtime, but only for actions that Project Settings does not already define. A rebinding menu can then edit `InputMap` directly, and editor-defined bindings always win. Keys use `physical_keycode`, so the WASD layout holds on non-QWERTY keyboards.

## DEC-006 — Automated input-driven smoke test as the gameplay gate

`tests/gameplay_smoke.gd` drives the real main scene with `Input.parse_input_event` and asserts outcomes. Every milestone extends it, and `tools/run_checks.ps1` runs it. This makes "playable" claims reproducible without an MCP or desktop-control dependency. It does not replace hand-play for feel.

## DEC-007 — Second causeway gap widened to 1.5 m

The starter's second gap was 0.5 m, narrower than the 0.7 m player capsule, so it was not a real hazard. Widening it gives the M1 checkpoint (on the broken span) a meaningful job.

## DEC-008 — Jev identified; not part of the asset pipeline (supersedes DEC-004)

The user identified "Jev AI" as TypeSafe AI's Jev (https://typesafe.ai/blog/introducing-system-one-models-and-jev). It is an early-access "System One" model that returns typed decisions with calibrated probabilities (classify, route, score, extract). It does not generate images, animation, 3D or audio. Access is API-only (docs.typesafe.ai, console.typesafe.ai), waitlisted, and billed per input token. The asset pipeline stays Tripo3D + Blender. Jev is not integrated. Any later experiment (for example enemy or boss decision-making) needs explicit user approval, because it costs money and sends data to a third party.

## DEC-009 — One MeleeAttack phase machine for every attacker

The player and the enemies share `MeleeAttack` (STARTUP → ACTIVE → RECOVERY) driven by `AttackData` resources. An enemy's telegraph *is* its STARTUP phase, so the visual warning and the real hit window cannot drift apart. Hitboxes compute knockback per target, pointing away from the attacker. Hurtboxes ask their owner's `is_invulnerable()`, so dodge i-frames and post-hit i-frames need no special cases. Hit feedback (spray, hitstop, shake) runs from `Hurtbox` through `HitFeedback`, which is presentation-only and respects `GameSettings`.

## DEC-010 — Enemies are leashed to their zone

Soldiers never move beyond `patrol_min/max_x ± leash_margin` and return home if knocked into a pit. The level exit depends on killing the soldier, so an enemy lost in a gap would softlock the run.

## DEC-011 — The Bishop is damaged only through what it pushes into the play plane

The boss stands at z = −22 and is never directly reachable. Every threat it makes (the slam hand, the lances) is telegraphed on the Z=0 plane first and is only dangerous on that plane. The Hand Slam leaves the hand lying on the causeway with an exposed stigmata hurtbox: this is the weak-point window, and later cards (M4 Blood Spear) can target the same hurtbox. Phases follow HP thresholds only (12 → ≤8 → ≤3), so debug HP changes drive the same transitions as real hits.

## DEC-012 — Causeway destruction is state toggling, with rules that guarantee a route

`BreakableSegment` disables collision and drops the visual; there are no physics debris. `BossArena` never breaks the entry or end segment, never breaks next to an existing gap (so every gap is 4 m, under the ~5.6 m running jump), and caps breaks at two. Each gap has a rubble ledge 1 m down as a fallback. Segments reknit after 14 s and on any death or fall.

## DEC-013 — Attack input buffer

An attack pressed while another is still playing is kept for 0.15 s and fires on the first free frame (latest press wins). Without it, hitstop stretches attacks by a few frames and quick follow-ups were silently dropped (found by the M3 boss test).

## DEC-014 — Cards validate before they touch anything

`CardSystem.play_slot` checks, in order: card present → player can act → cooldown → target legality (weak point exposed and in range / boss action interruptible) → energy. Energy is spent, the cooldown starts, the card is discarded and the effect applies only after every check passes. Failures return a reason (`empty`, `blocked`, `cooldown`, `no_target`, `out_of_range`, `energy`) that the UI flashes on the slot. Effects reuse the combat contracts:
- Blood Spear is a real moving `Hitbox`, so a weak point that closes mid-flight rejects it.
- Grave Shield uses a `try_block` hook on `Hurtbox` that filters by damage category (`heavy`).
- Ritual Chains calls the Bishop's `interrupt_with_chains`, which is only legal before the slam's descent.

## DEC-015 — Seeded deck with stable slots

`CardDeck` is a draw/hand/discard model with its own seeded RNG (Fisher–Yates). A played card's slot refills from the draw pile, and the discard pile reshuffles when the draw pile is empty. With the three-card starter deck, each card returns to its own slot, so hand positions stay stable. The seeded deal currently puts Grave Shield on 1, Ritual Chains on 2 and Blood Spear on 3. Larger decks work unchanged when deckbuilding arrives.

## DEC-016 — Reality Fracture as a level node with a fade-covered mode swap

`RealityFracture` owns the free-movement chapel, its guardian, the return portal and the transition. Entering and exiting run as a timed sequence: fade to black → teleport and flip `in_3d_mode` (camera snaps while the screen is black) → fade in, while the camera eases into its framing. Player input is frozen throughout, so nothing can act mid-teleport.
- HP, blood energy, card hand and cooldowns carry across with no copying, because the same player node crosses over.
- The return point is wherever the player pressed E, on Z=0.
- Death inside expels the player there at full HP and resets the guardian, so the encounter can always be retried.
- Clearing it heals the player, grants +3 blood and seals the fracture.
- A dark veil behind the chapel hides the main level.

## DEC-017 — 3D combat reuses 2.5D combat; two additions only

The guardian is a stock Plagued Soldier with `plane_locked = false`. It is leashed by radius around its home instead of by an X range. Hitboxes, telegraph markers and knockback already worked on X/Z. The player gains a soft lock-on in 3D only: an attack with no movement input turns toward the nearest living enemy within 3.5 m. In 2.5D, facing remains fully manual.

## DEC-018 — Pursuit Approach before the boss arena

The vertical-slice spec calls for collapsing/moving sections and a pursuit sequence, so a 40 m approach was inserted between the portcullis and the arena:
- three collapsing slabs over a pit;
- a moving "bone ferry" across a 10 m gap;
- the Bishop rising early into a PURSUIT phase, where it follows the player and throws single telegraphed lances every 3.2 s. In PURSUIT it cannot be damaged and shows no HP bar.

Reaching the arena calls `begin_fight()`. The arena moved by +40 m; boss tests express positions through `_bx()`, relative to the arena's real left edge, so future layout moves don't break them.

## DEC-019 — Export probe for packaged builds

`--script` is editor-only, so packaged builds cannot run `tests/gameplay_smoke.gd`. `ExportProbe` is a dormant node that the title screen adds only when it sees `--export-probe` (desktop user argument) or `?export-probe` (web URL). It drives real input through the packaged build and exits 0 or 1. Normal players never trigger it.

## DEC-020 — Settings persistence and test isolation

`GameSettings` saves to `user://settings.cfg`. `persistence_enabled = false` makes the default path a no-op, so automated tests never read or overwrite a player's real settings; the round-trip test uses its own file. The pause menu pauses the whole tree; the menu itself and the settings panel run with `PROCESS_MODE_ALWAYS`.

## DEC-021 — Damaging abilities: target any enemy, buffer through hitstun, Bishop retuned (playtest 2026-10-20)

User playtest: "the damaging abilities don't seem to work". Diagnosed with `tests/diag_abilities.gd`, which plays with real keys and the AI on. Three root causes:
1. Blood Spear only targeted the Bishop's exposed stigmata, so it refused (`no_target`) against every ordinary enemy. It now uses `Targeting.ENEMY`: the nearest living enemy hurtbox within range, with exposed weak points preferred. In 2.5D, targets must be within 2.5 m of the play plane. (New enum values go at the end, because `.tres` files store the integer.)
2. Cards and attacks pressed during hitstun were dropped. The most natural moment to spear, right after the slam lands on you and opens the stigmata, failed as `blocked`. Both are now held until the stun ends, plus 0.15 s.
3. Tuning: optimal melee did about 6 damage per weak window against 12 HP, so the Bishop died in about 2 windows (11 s). New values: Bishop 36 HP (Collapse ≤24, Covenant ≤10), 0.5 blood per melee hit, Blood Spear 3 damage. A test bounds optimal melee to at most 1/5 of the Bishop per window.

Readability: enemy hits show floating damage numbers (gold for weak points), and a refused card prints the reason in the HUD ("Blood Spear: no enemy or exposed stigmata within 14 m").

## DEC-022 — Mouse play for cards: click a card, then click the target

Second playtest report: the cards show READY but say "no target", even though the player clicked the target. Root cause: the game had no mouse input at all (no `InputEventMouse*` handling). Cards were keyboard-only and auto-targeted, so the playtester's clicks did nothing.
- `CardHandUI` slots are clickable. `CardTargeting` arms enemy-targeting cards: the slot gets a white outline and "AIM: CLICK TARGET", and the cursor becomes a crosshair.
- The next left-click picks the enemy hurtbox nearest the cursor (within 90 px on screen), and `CardSystem.play_slot(slot, chosen_target)` validates that exact target. Self and telegraph cards play on click.
- Right-click, clicking the same card again, or 8 s idle cancels. A miss keeps the card armed and says so.
- Clicking the Bishop's body explains that only the stigmata can be wounded. Clicking a sealed stigmata returns the new reason `not_exposed`.
- Keys 1–3 keep auto-targeting (nearest enemy, exposed weak point first).
- Testing: Godot's headless display server drops mouse input, so headless runs route clicks to the same signal and handler; the visible run uses real mouse events.

## DEC-023 — Combat feel: 3-hit combo, hold-to-chain, auto-attack, poise, hit reactions (playtest 2026-10-20)

Playtester: melee too slow, wants an auto/filler attack to earn blood, and hit reactions on both sides.
- **Light combo:** `player_light` → `player_light_2` → `player_light_finisher` via `AttackData.next_combo`. Pressing again, or just holding J, within 0.35 s chains the next step. Each light step takes 0.28 s; the finisher takes 0.44 s, deals 2 damage and 2 poise.
- **Auto-attack:** `GameSettings.auto_attack`, default on, toggle in Settings. With no attack pressed, the player swings at the nearest hittable enemy hurtbox within 1.8 m and turns to face it, but never while moving away from it.
- **Lunge gating:** a swing doesn't lunge when an enemy body is within 1.3 m ahead. Lunging into the soldier triggered its contact damage, which broke the combo before the finisher (found by diagnostic).
- **Poise:** every hit flashes the soldier white and makes it flinch. Only breaking poise (3 points; light 1, finisher/spear 2, heavy 3) cancels its attack and staggers it. Poise refills after 1.5 s without hits, so combos can't stun-lock it. Soldier HP 3 → 6.
- **Player reactions:** a red flash, a recoil lean, and a red screen-edge vignette when hurt. Swings lean forward. The Bishop's stigmata flares white per hit.
- **Bishop HP 36 → 60** (Collapse ≤40, Covenant ≤18). Held-combo spam deals about 9 per weak window, and a test bounds that at ≤1/5 of max HP.
- The dormant Bishop is hidden until it rises; its sunk silhouette was poking into early shots.
- Tests disable auto-attack (`_test_defaults`), except in the checks written for it.

## DEC-024 — Roguelike run loop: draft, altars, eight cards (playtest 2026-10-20)

Playtester wants a roguelike side-scroller: choose cards before the run from a random offer, more cards, and more happening between the set-pieces.
- `RunState` (static): run seed, the drafted deck, and a seeded RNG for every offer in that run. `CardPool.offer()` gives a weighted sample without replacement, preferring cards not already owned.
- **Draft** (`scenes/draft.tscn`): three rounds of "pick 1 of 3"; the result is the starting deck. Start, Restart run (pause menu) and R after victory all begin a new run through the draft. Opening `main.tscn` directly (tests) uses the default three cards.
- **Blood Altars** (x 16.8 and 40.7) and a cleared Reality Fracture open `CardOfferOverlay`: pause, pick 1 of 3 or take nothing. The card is added at a random point in the draw pile. The hand stays 3 slots and rotates through the growing deck.
- **New cards:** Hemorrhage Pact (HP for blood; answers blood starvation), Epitaph (delayed spike, 4 damage, breaks poise), Ashen Choir (summoned shard phantom), Bell of Silence (cancels wind-ups, blocks new attacks for 4 s; the Bishop is always in reach), Transfusion (heal). New refusal reasons: `too_weak` and `full_health`.
- Player-facing reference: `docs/CARDS.md`.

## DEC-025 — A bigger Hollow Bishop: four phases, roars, three new attacks (2026-10-21)

Playtester: give the Bishop more HP, more mechanics, abilities and phases.
- **HP 90.** Phases by HP: I Procession (>65), II Collapse (≤65), III Covenant (≤35), IV **Unmaking** (≤12), with weak windows of 2.5 / 2.5 / 4 / 5 s.
- **Roar:** entering a new fight phase drops the current attack. The Bishop then shudders for 1.8 s and starts nothing, and the level shows a banner ("THE HOLLOW BISHOP — II · THE COLLAPSE"). `debug_attack` ends a roar (tests).
- **New attacks**, each with a distinct answer and all telegraphed on the play plane:
  - **Censer Sweep** (`CenserSweep`, II+): a red band along the causeway while the censer swings in from depth to knee height, then it sweeps at 16 m/s. Jump it (it reaches ~1.35 m) or dodge through it. 1 damage, category `sweep`.
  - **Requiem Beam** (`RequiemBeam`, III+): a heart charge with a causeway line and a start pillar, then a sweep at 18 m/s, too fast to outrun. Dodge through it, toward the beam. 2 damage, category `beam`.
  - **Grasping Dead** (II+): red marks show where 2 Husks will rise (2 HP, poise 1, roaming the arena). At most 2 at a time. They're cleared on player respawn and on the Bishop's defeat.
- **Patterns:** II summon/sunder/censer/volley/slam; III summon/beam/slam/censer/volley/sunder; IV beam/slam/censer/volley/slam with a 0.7 s cooldown.
- Silence (Bell of Silence) also cancels a censer or beam still telegraphing, and a summon still rising.
- Fix found by test: Husks were first leashed ±3 m around their spawn, so they hovered out of reach. They now roam the whole arena.

## DEC-026 — Encounters between the set-pieces: Bone Archer and ambush rooms (2026-10-21)

Playtester: more mechanics and things to do between the start and the Bishop.
- **Bone Archer** (`BoneArcher`, 3 HP, poise 2): keeps its distance, backing away when closer than 3.5 m unless cornered. It draws for 0.9 s with a red aim line, then looses a chest-high arrow (`BoneArrow`, 14 m/s, 1 damage, category `projectile`). Jump it, dodge it, or block with nothing; Grave Shield is heavy-only. It can be silenced.
- **Ambush rooms** (`Ambush`): crossing the trigger raises bone walls on both sides and spawns the room's foes. The walls drop when every foe is dead. Dying or falling mid-fight clears and re-arms the room. While a room holds you, the fracture gate and Blood Altars refuse, and the Bishop's pursuit lances wait.
  - **E1, Gate ossuary** (x 9.3–18.3): 2 Husks + an archer. Its altar (x 16.8) is the reward.
  - **E2, Landing** (x 37.8–43.8, mid-pursuit): a Husk + 2 archers. Its altar (x 40.7) is the reward, and the ferry waits behind the wall.
- `EnemyFactory` builds Husks and archers for both the ambushes and the Bishop's Grasping Dead. Dead foes free themselves after 1.5 s; `Ambush` prunes freed references before touching them (found by test: script errors on freed Husks).
- `Ambush.enabled` (static) is off in scripted tests and on in the game.

## DEC-027 — Sound & music: synthesized in-repo, routed through one service (2026-10-21)

- No third-party audio: `tools/generate_audio.gd` synthesizes 32 effects and two music loops (level drone, 120 bpm boss track) into `assets/audio/` (22050 Hz 16-bit mono WAV, ~3 MB). Rerun it to retune any sound.
- `Audio` (static service, lazily added under root) owns a 14-voice SFX pool on bus `SFX` and a looping music player on bus `Music`. Gameplay scripts stay mostly audio-free: `main.gd` maps player, card, Bishop and ambush/altar signals to sounds. Only the archer, beam, slam and hit feedback call `Audio.sfx` directly, at the exact frame they act.
- Music: the level drone plays from the menu; the boss track starts at `begin_fight`; victory stops music and plays a chord.
- Settings: Music and Sound-effects sliders (0–1, saved under `[audio]`) set the bus volumes.
- Found by the new "every sound is triggered" test: the player's `landed` signal never fired, because `_was_on_floor` was sampled after `move_and_slide()`. It now stores the pre-move floor state.
- Known quirk: under the headless dummy audio driver Godot reports leaked AudioStreamWAV playbacks at exit. The real WASAPI driver reports none.

## DEC-028 — Relics and card upgrades (2026-10-21)

- Relics are `RelicData` resources (8, see docs/CARDS.md), held in `RunState.relics` (static, like the deck). A level opened without an active run clears them on load.
- Offers are mixed lists of `CardData` / `RelicData`. `CardOfferView.describe` labels each one. Altar: 2 cards + 1 relic (the relic last, so "1" still takes a card). Fracture: 2 relics + 1 upgrade.
- Upgrades are runtime `duplicate()`s with `upgrade_source` pointing at the original. They are never saved over the .tres. The id is unchanged, so cooldowns, sounds and effects carry over.
- Effects are applied where the rule lives, not through a global modifier system. Stat relics change the player, energy or health in `_apply_relic`. Damage relics use `MeleeAttack.bonus_damage[id]` and `CardSystem.spell_damage_bonus`. Rosary uses `CardSystem.cooldown_scale`. Kill relics use `Health` broadcasting deaths to the `death_listeners` group.
- Gotcha found by test: `CardPool.offer` returns `Array[CardData]`, and appending a RelicData to it fails. The offer helpers convert to untyped arrays.

## DEC-029 — Manual melee on the mouse; no auto-attack (2026-10-21)

- Playtester: melee should not be automatic. Left click is the light combo (hold to chain) and right click is the heavy. J/L and the gamepad still work. The auto-attack and its setting are removed.
- Holding counts only if the press reached the player's `_unhandled_input`. A click consumed by the HUD or by card targeting (an armed card's target click, right-click cancel) never starts or continues a combo.

## DEC-030 — Faster and harder (2026-10-21)

- **Player:** run speed 7 → 8.5, snappier acceleration, dodge 17 m/s with a 0.4 s cooldown.
- **Enemies:** soldier chases at 4.4 and Husks at 3.6. Archers aim in 0.7 s and recover in 1.0 s. Arrows fly at 18 m/s.
- **Bishop:**
  - 120 HP (phases at 88/50/18) and up to 3 Husks;
  - slam telegraph 0.75 s, sunder 1.0 s, roar 1.3 s;
  - cooldowns 1.25/1.0/0.7/0.45 s by phase; lances at 21 m/s.
- **Fairness floors kept:** the soldier slash still telegraphs ≥ 0.5 s (30 frames). The slam floor was lowered from 80 to 60 frames (aim + telegraph ≈ 1.05 s).

## DEC-031 — Unique abilities (2026-10-21)

- **`StrikeZone`:** a shared telegraphed area strike (red ring → strike → fade). It powers the Bishop's **Bone Rain** (two offset waves: step between them) and **Marrow Geyser** (three spikes chase your position: keep moving). Both are `BishopBarrage` actors in the phase patterns. Silence cancels them while they are still being marked.
- **Plagued Soldier:**
  - **Plague Lunge** at 3–6 m: 0.55 s crouch, an 11 m/s dash, and a predictive leash so it never overshoots.
  - **Frenzy** at half HP (≥ 4 max HP): red, 30% faster chase, attacks twice as often.
- **Husk:** **Death Burst**, a plague cloud 0.6 s after death.
- **Bone Archer:** every 3rd shot is a lobbed **Grave Arrow** that lands on your marked spot. When crowded it **Bone Hops** backwards, from idle or recovery.
- **New Crypt Hound:** runs in at 6.5 m/s, crouches 0.45 s (glow), pounces in an arc, then lands exposed for 0.8 s. It can't be knocked out of a pounce. Hounds join both ambushes; the landing ambush now has 4 foes.

## DEC-032 — A harder route (2026-10-21)

- **Spike traps** (`SpikeTrap`): cycle down 1.5 s → warning glow 0.5 s → up 0.7 s. One is on the start causeway, one on the approach causeway, and one on the threshold off the ferry.
- **Pendulum blade** (`PendulumBlade`): swings over the approach causeway at waist height. Jump it or time it.
- Collapsing slabs drop after 0.5 s (was 0.7). The ferry crosses in 2.1 s with a 0.6 s pause (was 2.8/0.9).
- The existing platform geometry is unchanged, so every traversal check still proves the route is completable. Respawning resets all traps.
- `SpikeTrap.enabled` / `PendulumBlade.enabled` are off in scripted tests (like `Ambush.enabled`), and the hazards have their own checks.

## DEC-033 — Equipment, attributes and the Armory (2026-10-21)

- **Items** are `ItemData` resources. There are 13 (see docs/EQUIPMENT.md): 3 slots and 4 attributes, plus weapon attack speed and heavy damage. They persist between runs in a `Profile` (user://profile.cfg): stash, equipped, pending spoils.
- **Flow:** Start → Armory → draft → level. A victory adds a spoil (pick 1 of 3 unowned items), and R after victory opens the Armory.
- **Application:** `Equipment.apply` runs once per level load, after relics. It reuses the relic hooks: `MeleeAttack.bonus_damage`, and the new `MeleeAttack.speed_scale` for attack speed.
- **Tests:** they reset the Profile to starter gear (no stats), so equipment never changes scripted timings. The export probe disables persistence so it never writes the player's profile.

## DEC-034 — ElevenLabs sound pass (2026-10-21)

- Playtester: the synthesized sounds were too generic. With the user's approval of the credit cost, `tools/elevenlabs_sfx.py` generated all 38 effects and both music loops with the ElevenLabs Sound Effects API (`eleven_text_to_sound_v2`; music uses `loop: true`).
- **Cost and account:** 808 credits (account went from 8,682 to 9,490 used of 10,000), about 10 credits per requested second. The account is on the free tier.
- **Format:** the API returns 16-bit **stereo** PCM for `pcm_22050`. Found by checking sample correlation, because clips came back at double length. The script downmixes to mono, trims leading and trailing silence on effects (instant response), fades the tail and peak-normalises per sound.
- **Cache:** raw responses are cached in `tools/.elevenlabs_cache/` (git-ignored), so reruns only pay for missing sounds. The key is read from `ELEVENLABS_API_KEY` and never printed.
- **Fallback:** `tools/generate_audio.gd` (the synthesized set) writes the same files. Rerunning it replaces the ElevenLabs audio.
- **Open question:** ElevenLabs' free plan may not grant commercial rights to generated audio. Check their current terms before any commercial release (or regenerate on a paid plan).

## DEC-035 — Faster Bishop with overlapping attacks; reliquary drop; utility cards (2026-10-21)

- **Pacing.** Playtester: the fight is still too slow, but the telegraph timing feels right. Telegraphs are unchanged. What changed:
  - downtime between attacks is 0.9/0.75/0.55/0.35 s by phase (was 1.25/1.0/0.7/0.45);
  - the Bishop tracks you at 4.5 m/s (was 2.5) and roars for 1.0 s;
  - the patterns contain more slams, so there are more stigmata windows per minute.
- **Second channel.** From phase III the Bishop runs a second ability alongside its main one (`start_secondary`):
  - Bone Rain or Marrow Geyser, every 3.0 s in phase III and every 2.0 s in phase IV;
  - phase IV can also add a censer, but never on top of the beam (jumping and dodging at the same instant would be unfair).
  - It is never the same attack twice at once. Silence cancels it while it is still being marked; roars, respawn and defeat clear it.
- **Reliquary drop.** Playtester: nothing to pick up from the boss. The spoils existed, but only in the Armory. Now a glowing reliquary (`LootChest`) rises beside you when the Bishop dies. E opens a pick of 1 of 3 unowned items, which go straight into the stash (that spends the victory's spoil). Ignoring it leaves the spoil waiting in the Armory.
- **Five new cards** (13 in total):
  - **Shadow Step** (teleport dash 4.5 m, through enemies, never through walls, 0.3 s i-frames);
  - **Grave Hook** (pull yourself to an enemy within 10 m and strike for 1; it lifts you out of pits onto a foe's ledge);
  - **Ossuary Bridge** (a 3 m bone slab at your feet for 5 s);
  - **Blood Nova** (2 damage to every enemy within 3 m, breaks poise);
  - **Sigil of Haste** (×1.3 run and attack speed for 5 s).
- `Player.blink` raycasts at knee, chest and head height. It skips bodies in the enemy group and stops 0.45 m short of anything else.
- Found by test: the first Grave Hook test stood in a gap, and the ledge wall correctly blocked the pull. That led to the hook's lift.
- `tools/generate_audio.gd` now takes ids after `--`, so placeholder sounds for new content never overwrite the ElevenLabs set.

## DEC-036 — Sound v2 and voices (2026-10-21)

- **Effects v2.** Playtester: some sounds were still generic. All 46 SFX and music were regenerated with the user's new ElevenLabs key. The prompts now name materials, layers and characters (`tools/elevenlabs_sfx.py`), with prompt_influence 0.7, and the music loops are 30 s. The v1 cache is kept locally in `tools/.elevenlabs_cache_v1/`.
- **Key handling.** The key file's path is passed with `--key-file`; the tool reads it at runtime and never prints or stores it.
- **Voices** (`tools/elevenlabs_voice.py`, ElevenLabs TTS `eleven_v4`). The free plan cannot design or save custom voices, nor use premium library voices, through the API, so each speaker uses one fixed default voice:
  - **The Hollow Bishop** (Adam, then the same `demonize` chain on every line: pitch −20%, 60 Hz ring modulation for the robotic metal, tanh distortion, bit grit, 130 ms cathedral echo).
    - 12 lines: awakening, fight start, each phase, attack callouts (slam/sunder, beam, summon, Bone Rain, Marrow Geyser), a taunt when it kills you, and its death.
    - Callouts never talk over another line, and at most one plays every 4 s.
  - **The knight** (Harry, "fierce warrior"): 4 hurt cries picked at random, a falling scream ("Aaaah!", played when you drop into the abyss), a death line and 2 effort shouts on finishers and heavy swings.
- `Audio.sfx` now plays a random take when `<id>_2..6` exist; `Audio.voice` is a single voice channel (urgent lines interrupt).
- **Credits:** the new key's meter showed 506 used right after the batches (it lags). Expected total ≈ 1,100 (SFX) + ≈ 450 (TTS characters).

## DEC-037 — The first map: shuffled rooms, elite, merchant, secrets, new enemies (2026-10-21)

Built from docs/superpowers/specs/2026-10-21-first-map-design.md (approved by the user).

- **Map shape:** opening (unchanged) → 3 Act I rooms → The Gravewarden's Hall → 3 Act II rooms → The Pale Merchant → pursuit approach + Bishop.
  - `LevelLayout.plan(seed)` deals the rooms from the run seed.
  - Act I/II rooms are drawn 3 of 5 and run easiest → hardest, with one random neighbour swap.
  - No room repeats. Checked over 40 seeds.
- **Rooms:** each is a `LevelSection` script, built in world coordinates from local-x helpers (ground, ledge, slab, mover, spikes, pendulum, enemy, ambush, altar, secret_cellar, shortcut).
  - Every room has an entry checkpoint, and entry and exit floors at y = 0, so rooms join in any order.
  - **Reachability:** every walkable surface is recorded, and `is_completable()` proves the exit is reachable. Its jump model comes from the player's real numbers (run 8.5, jump 9.5, gravity 22/30), counting on 75% of the theoretical reach. It caught a 2 m wall in the Sunken Reliquary before it shipped.
- **`main.gd`:** the rooms are inserted at x = 18.2. Everything after them (approach, landing ambush and altar, traps, arena, Bishop, checkpoints, the pursuit/fight triggers and the camera's arena framing) shifts by `map_offset`. `LevelLayout.classic = true` inserts no rooms, so all earlier checks still run on the original short layout.
- **New enemies** (`CodeEnemy` base):
  - **Shielded Knight:** frontal hits are blocked while guarding. A heavy strike, Grave Hook or poise-3 hit breaks the guard. It shield-bashes.
  - **Flying Wraith:** no gravity, ghosts through walls, dives along a red line.
  - **Bone Crawler:** fuses and bursts. Killed early, it still bursts after 0.45 s.
- **The Gravewarden (elite):**
  - **Crypt Charge** passes through the player and dazes it against walls only, not bodies (both found by tests).
  - **Grave Quake** sends low "wave" spikes you can jump. **Raise Guard** summons crawlers.
  - Enrages at 50% (faster, double charge). Drops 40 shards.
  - Its hall seals like an ambush; afterwards a relic reliquary rises. The HP bar shows its name.
- **Bone Shards:** a run currency from every kill (`shard_value`: husk 1, archer/hound 2, knight 4, Gravewarden 40), shown in the HUD with a floating "+N".
- **The Pale Merchant:** a card (30), relic (60), full heal (25) and card upgrade (40), rolled once per visit. Several purchases per visit; unaffordable wares and a heal at full HP are refused at no cost.
- **Secrets:** cracked floors (4 HP, never targeted by cards) over cellars with a shards cache, a card shrine or a relic, in 4 rooms, each with a step back up. Rooms stay completable with the floor broken.
- **Shortcuts:** `LeverShortcut` (Godot already has a `Shortcut` class) in the Collapsing Gallery and the Wraith Belfry. Pulling the lever turns a ghost bone bridge solid back over the room's hard stretch.
- **Ambushes:** they now support waves (Charnel Arena has two) and raised floors.
- **Known gaps:**
  - The 10-minute length is estimated, not measured. The full route is ~430 m (about 8 rooms of 45–65 m plus the opening and approach), and the hazards and fights set the pace.
  - No bot plays the whole map end to end. Reachability plus "every checkpoint stands on ground" are the automated guarantees.

## DEC-038 — Tighten-up pass: a 3-reviewer bug hunt (2026-10-21)

Three read-only reviewers swept three areas: combat/enemies/boss; level/map/run flow; cards/UI/items/audio. They reported 23 findings with code evidence. 22 were fixed (see commit 3258e38); one stays a known gap (below).

**Highest-impact fixes:**
- **Secret cellars could not be reached in real play.** The test teleported to the cache, which hid it. They are now a sealed niche under the cracked floor, and the test claims the cache and hops out with no teleport.
- **Esc over a reward or shop overlay unpaused the game underneath.** This allowed altar rerolls and lost rewards. Now the pause menu restores the overlay's pause, overlay keys ignore input while paused, and the level ignores Interact while an overlay is open.
- **A killing blow knocked the player back after respawning.** Player deaths are now handled deferred.
- **The Bishop's pursuit lances could follow you back into the rooms.** Its engage line now follows `map_offset`.
- **Economy exploits:**
  - shop relics already owned, and stale card upgrades, are dropped;
  - reliquaries and shrines roll their offer once;
  - ambush retries keep dead foes dead (no shard farming);
  - Gravewarden summons pay no shards.
- **The Gravewarden:**
  - no crawlers behind its walls;
  - its crawlers crumble when it dies instead of bursting;
  - the enraged double charge now actually happens.

**Smaller fixes:**
- **Enemies:** the knight's stagger is no longer cut short; hounds and archers can walk back inside their bounds.
- **Player and cards:**
  - respawn clears combo, haste and shield;
  - Bell of Silence refuses (no cost) with nothing in earshot;
  - a queued card whose target vanished fails rather than retargeting.
- **UI:** the cursor is restored, and the Armory keeps keyboard/gamepad focus.
- **Audio:** music state is set only once a stream has loaded, and voice stops when the level ends.
- **Level:** the Wraith Belfry shortcut bridge runs under the beams.

**Known gap:** a dead-but-not-freed queued target already fails correctly. Only the freed case was changed.

## DEC-039 — Local co-op, structured for online later (2026-10-21)

Design: docs/superpowers/specs/2026-10-21-coop-design.md (the user chose local-first and separate decks with a shared run).

- **Start Co-op** in the main menu goes Armory → draft for player 1, then player 2 → level.
  - **Player 1:** keyboard + mouse.
  - **Player 2:** the first gamepad, or arrows + numpad.
  - With two pads, player 1 also gets pad #1 and player 2 pad #2.
- **Input:** the player script reads actions through `act()`, using `input_prefix` ("" or "p2_"). `CardSystem.slot_action()` does the same for card keys. `InputBindings.configure_players(coop)` builds the p2_ actions and assigns devices; in co-op the arrow keys move from player 1 to player 2.
  - **Online later:** a remote player is just another prefix whose actions are pressed by received network input (`Input.action_press`). No gameplay script reads raw devices.
- **Targeting:** `Players` (`all`, `standing`, `nearest`, `leader`) replaces every single-player lookup in enemies, bosses and ambushes. Downed players are ignored.
- **Separate:** HP, blood and hands (player 2's hand HUD is bottom-right; player 2 is red).
- **Shared:** relics (applied to both), shards, the map and Armory gear.
- **Rewards:** altars, reliquaries, shrines and the merchant give to whoever pressed Interact.
- **Down and revive:** in co-op, 0 HP downs you. Your partner holds Interact beside you for 1.2 s to bring you back at 2 HP. Both down sends both to the checkpoint. A pit fall pulls you back beside a grounded partner for 1 HP.
- **Camera and leash:** the camera frames the midpoint and pulls back as the players spread. A leash keeps them within 18 m (main runs its physics after the players).
- **The Reality Fracture** is solo-only for now.

## DEC-040 — Art merged; fluid animation layer (2026-10-22)

- **Merge:** the art branch (`claude/exciting-kapitsa-f1c50d`) is merged into main. It adds the Tripo models (the Bone Revenant hero with its separate sword, back scabbard and spring-bone cloth; the enemies; the Bishop), the art bible and the asset list.
- **Why the characters were stiff:** the Tripo preset clips are long. Slash and chop run 6.6 s, dive 2.7 s, jump 2.2 s, while a light attack lasts about 0.28 s. The old animator played whole clips as uninterruptible one-shots on the full body, and locomotion was a hard idle/run switch.
- **The new `ArtAnimator`** builds an AnimationTree in code:
  - **Locomotion:** a BlendSpace1D (idle, walk, run) on the smoothed ground speed. Playback speeds up past the run clip's own speed, so the feet track the 8.5 m/s run instead of sliding.
  - **Falling:** a Blend2 eases into "fall" while descending.
  - **Actions:** two one-shots, full body and upper body. The upper-body one is masked to spine, arms and head, so swings, draws and casts play over running legs. Both fade in over 0.06 s and out over 0.12 s.
- **Action timing:** every action plays only its busiest stretch, found once per clip by summing bone rotation speed. That stretch is time-scaled to the gameplay duration (startup + active + recovery ÷ weapon and haste speed), so the visible swing lasts as long as the real attack.
- **Draw:** a 0.14 s upper-body draw, then the swing for the rest of the attack.
- **Death** stops the tree and holds the defeat clip. Facing eases toward the gameplay direction at the same rate whatever the frame rate.
- **Evidence:** `tests/shot_motion.gd` prints the tree state and saves `docs/screenshots/20_motion_*.png`:
  - running at the full blend, sped up 1.55×;
  - draw and swing on the upper body while running;
  - heavy attack, dodge and jump on the full body.
- **Results:** 446/446; `build/windows-run11/Bloodbound.exe` (192 MB, models embedded); the release export probe exits 0.

## DEC-041 — Movement feel: no rubber-banding (2026-10-22)

Playtest: "rubberbandy and lagging when switching directions". Measured before the fixes: a full-speed turnaround took 0.30 s, the camera trailed 1.9 m behind at full run, and its aim swung about 10° on every turnaround. The aim followed the player instantly while its position lagged, so the view slid one way and swivelled back. That was the rubber band.

**Fixes:**
- **Physics interpolation** is on, so motion is smooth on any refresh rate. Teleports call `reset_physics_interpolation()`, the camera reads interpolated positions, and the camera itself is not interpolated (it moves every rendered frame).
- **Camera:** one smoothed focus point drives both position and aim (12/s horizontally, 5/s vertically), with a 1.6 m look-ahead toward the facing side. Only the framing offset eases (arena pull-back, co-op spread). It cuts instead of sweeping after a teleport.
- **Player:** turnarounds use a dedicated rate (160 on the ground, 70 in the air) instead of the 60 used for speeding up.

**After:** a turnaround takes 0.18 s; the camera leads by 0.9 m instead of trailing; aim swing is 0°. Permanent checks were added (450/450). Build `build/windows-run12/Bloodbound.exe`.

## DEC-042 — Bishop arm, Bishop motion, dash cost (2026-10-22)

- **Bishop arm.** The greybox SlamArm box is replaced by `ArtBoneArm`: the model's right arm is folded away by a SkeletonModifier3D, and a skeletal arm (humerus, raised elbow, radius and ulna) grows from the model's real shoulder to the slam hand.
  - **Why not the model's own arm:** the hand travels ~28 m from the shoulder, but the arm is 8 m. Aiming and stretching the real arm (a custom modifier) was tried and measured: the bones reached the hand exactly (0 m gap). But the Tripo auto-rig skins the robe sleeve partly to the body, so a 3.5× stretch tore it into sheets.
  - In the full-3D version the Bishop slams within its natural reach and uses its own arm.
- **Bishop motion.** Locomotion reference speeds now scale with model size (the 30 m Bishop had been playing a human-speed walk 1.8× too fast). Its tracking eases (accelerates and settles) instead of starting and stopping instantly. The animation speed input is smoothed exponentially.
- **Dash costs blood.** A dodge/dash costs 0.6 blood (`Player.dodge_blood_cost`). Without enough blood it is refused (sound plus HUD message) and nothing is spent.
- **Results:** 452/452. Build `build/windows-run13/Bloodbound.exe`.
