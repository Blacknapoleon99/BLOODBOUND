# Equipment, attributes and the Armory

Between runs you visit the **Armory** (Start → Armory → card draft → level; after a victory, R → Armory). There you:

- **claim spoils:** pick 1 of 3 items you don't own yet;
- **equip** one weapon, one armor piece and one charm;
- **see** your attributes and the resulting stats.

Owned items and what you wear persist in `user://profile.cfg`.

**Spoils:** a new profile starts with one spoil to claim. Each Bishop kill adds one.

## Attributes

| Attribute | Per point |
|---|---|
| **Vigor** | +1 max HP |
| **Might** | +1 damage on the combo finisher and heavy strike; +1 on the opening jabs per 2 points |
| **Agility** | +4% run speed, −0.02 s dodge cooldown, +0.015 s dodge i-frames (negative Agility slows you) |
| **Devotion** | +0.1 blood per melee hit; +1 max blood per 2 points |

The weapon also sets **attack speed**: every melee phase lasts duration ÷ speed. Some weapons add heavy-strike damage.

## Items

| Item | Slot | Bonuses |
|---|---|---|
| Rusted Blade | weapon (starter) | none |
| Bloodletter Sabre | weapon | Might +1, attack speed ×1.1 |
| Gravecleaver | weapon | Might +2, Agility −1, speed ×0.85, heavy +2 |
| Twin Fangs | weapon | Agility +1, Devotion +1, speed ×1.25 |
| Penitent's Flail | weapon | Vigor +1, Might +1, speed ×0.95, heavy +1 |
| Pilgrim Rags | armor (starter) | none |
| Ossuary Plate | armor | Vigor +2, Agility −1 |
| Shroud of Ash | armor | Agility +2 |
| Martyr's Mail | armor | Vigor +1, Devotion +1 |
| Hunter's Leathers | armor | Might +1, Agility +1 |
| Censer Locket | charm | Devotion +2 |
| Wolf Tooth | charm | Might +1, Agility +1 |
| Saint's Knucklebone | charm | Vigor +1 |

New items go in `resources/items/*.tres` and are listed in `scripts/items/item_pool.gd`. Attribute rules live in `scripts/items/equipment.gd`. Its `BASE_*` constants must match the player scene, and the smoke test checks that they do.
