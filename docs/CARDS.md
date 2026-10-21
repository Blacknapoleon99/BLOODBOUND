# Bloodbound Cards — reference

Cards are real-time abilities paid for with **blood**. You start each run at 2 blood. Blood comes from landing melee hits (+0.5 each) and a slow trickle (+0.25/s), up to a maximum of 6.

**Playing a card:** press **1 / 2 / 3**, or **click** the card.
- Cards that need a target (Blood Spear, Epitaph) arm on click. Then click the enemy you want. Right-click cancels.
- Keys auto-target the nearest enemy, and always prefer the Bishop's exposed stigmata.
- A refused card never costs anything. The HUD says why it was refused.

## The run loop

1. **Draft** — before each run: three rounds of "pick 1 of 3" random cards. The three cards you pick are your starting deck.
2. **Blood Altars** — two per run, one before the portcullis and one after the crumbling slabs. Press **E** at an altar to add 1 of 3 cards to your deck.
3. **Reality Fracture** — clearing the optional 3D arena also grants a pick.
4. Your **hand** always shows 3 cards. A played card goes to the discard pile, and its slot draws the next card from your deck, so a bigger deck rotates.

## Cards

| Card | Cost | Cooldown | What it does |
|---|---|---|---|
| **Blood Spear** | 2 blood | 1.5 s | A projectile at the nearest enemy (or the clicked one) within 14 m, for 3 damage. Exposed weak points are targeted first. Breaks 2 poise. |
| **Grave Shield** | 2 blood | 6 s | A 3 s ward that absorbs the next **heavy** hit, such as the Bishop's Hand Slam. It does not stop lances. |
| **Ritual Chains** | 3 blood | 8 s | Only works while the Bishop is winding up a Hand Slam or Sunder (hand hovering over the red floor marker). It cancels the strike, and the hand drops harmlessly onto the causeway with its weak point **open for 3 s**. |
| **Hemorrhage Pact** | free, 1 HP | 8 s | Lose 1 HP, gain 4 blood. Refused if it would kill you. |
| **Epitaph** | 3 blood | 4 s | Marks the ground under an enemy within 12 m. 0.6 s later a bone spike erupts for 4 damage and breaks poise. |
| **Ashen Choir** | 3 blood | 10 s | A phantom at your shoulder fires blood shards (1 damage) at the nearest enemy every 0.8 s, for 6 s. |
| **Bell of Silence** | 2 blood | 12 s | Enemies nearby (and the Bishop) can't start attacks for 4 s. Attacks still winding up are cancelled. |
| **Transfusion** | 3 blood | 10 s | Heal 2 HP. Refused at full health. |

New cards go in `resources/cards/*.tres` and are listed in `scripts/cards/card_pool.gd`.

## Relics

Passive modifiers that last the run. Every Blood Altar offers **2 cards + 1 relic**. A cleared fracture offers **2 relics + 1 card upgrade**. Relics never repeat. Once all 8 are taken, the empty slots are filled with cards.

| Relic | Effect |
|---|---|
| **Leech Fang** | Every foe you slay feeds you 1 blood. |
| **Executioner's Seal** | Combo finisher and heavy strike +1 damage. |
| **Thorned Reliquary** | Blood Spear and Epitaph +1 damage. |
| **Wraith Step** | Dodge i-frames +0.12 s (0.40 s), dodge cooldown −0.15 s (0.30 s). |
| **Vessel of Plenty** | Max blood 6 → 8, and +2 blood when taken. |
| **Bone Ward** | +1 max HP. |
| **Penitent's Rosary** | Card cooldowns −25%. |
| **Gravebloom** | Every 4th foe slain heals 1 HP. |

New relics go in `resources/relics/*.tres`, are listed in `scripts/relics/relic_pool.gd`, and get their effect in `main.gd` (`_apply_relic` for stat changes, `on_combatant_died` for kill triggers).

## Card upgrades

An upgrade ("tempered" card, name ends in **+**) costs 1 blood less (never below 0) and has a 30% shorter cooldown. It replaces every copy of that card in the deck. A card is upgraded at most once. The offered upgrade is a random un-upgraded card from your deck.
