# Local co-op (online-ready) — design

## Decided with the user

- **Local couch co-op first**, structured so **online** can be added later.
- **Separate decks, shared run:**
  - each player has their own HP, blood and 3-card hand (drafted separately);
  - relics, Bone Shards, the map and the Armory gear are shared;
  - a downed player can be revived by the other, and the run only resets if both fall.

## How it plays

- **Main menu:** **Start** (solo) and **Start Co-op**. Co-op goes Armory → card draft for Player 1 (3 picks) → card draft for Player 2 (3 picks) → level.
- **Controls:**
  - **P1:** keyboard + mouse as today: A/D, Space, left/right click, Shift, 1–3, E.
  - **P2:** the first gamepad. Without a gamepad, P2 uses the keyboard's right side: arrows move, ↑ jumps, Numpad 4 light, Numpad 5 heavy, Numpad 6 dodge, Numpad 1–3 cards, Numpad Enter interact.
  - With two gamepads, P1 can also use pad #1 and P2 uses pad #2.
- **Camera:** frames both players, pulling back as they spread out. Players can't spread more than 18 m apart: the camera's edge holds the leader back.
- **Down, not out:**
  - At 0 HP in co-op you're **downed**: you lie there, can't act, and enemies ignore you.
  - Your partner stands next to you and **holds Interact for 1.2 s** to revive you at 2 HP.
  - If both are down, both respawn at the last checkpoint (the room resets as in solo).
- **Falling into the abyss:** you reappear next to your partner and lose 1 HP. If your partner is also falling or downed, it's the normal checkpoint respawn.
- **Who gets what:**
  - the player who presses E at an altar, reliquary, cache or merchant receives the card, the purchase or the heal;
  - relics apply to **both**; shards are one shared purse;
  - Leech Fang gives blood to both, and Gravebloom heals both.
- **Enemies and bosses** target the nearest standing player. Ambushes, pursuit and fight triggers react to whichever player gets there first.
- **The Reality Fracture** (3D side arena) is single-player only for now: in co-op the gate stays sealed with a message.

## Architecture (online-ready)

- **Per-player input:** each player reads its own action set via `input_prefix` ("" = P1, "p2_" = P2). `InputBindings.configure_players(coop)` builds the P2 actions and assigns devices (P1 keyboard+mouse, plus pad 0 only when two pads are present; P2 the remaining pad + right-keyboard keys). Gameplay code never reads raw devices.
  - **Online later:** a remote player becomes another prefix whose actions are pressed and released by received network input (`Input.action_press/release`), so the player script needs no changes.
- **`Players` helper:** `all()`, `standing()`, `nearest(position)`, `leader()`. It replaces every `get_first_node_in_group("player")` in enemies, bosses and ambushes.
- **`main.gd`:** `players[]` replaces the single `player` wherever a rule applies to everyone (relics, equipment, victory freeze, respawn, camera). Interactions resolve to the acting player.
- **Run state:** `RunState.coop`, `RunState.deck_p2`. Everything else is already shared.
- **Online path, documented for later:**
  - the host runs the simulation;
  - clients send input (their action prefix) and receive state through `MultiplayerSynchronizer` on players, enemies and boss;
  - seeded layouts mean the map itself never needs syncing, only the seed.

## Out of scope now

Online play, 3–4 players, split screen, per-player relics, co-op in the 3D Fracture.

## Tests

- two players spawn with separate card systems and hands;
- P2 moves and attacks through its own actions;
- enemies pick the nearest standing player;
- the camera frames both; the leash holds;
- down → revive by holding interact; both down → checkpoint respawn;
- a pit fall rejoins the partner;
- relics apply to both; an altar card goes to the presser;
- co-op draft gives each player a deck;
- solo play is unchanged (the whole existing suite stays green).
