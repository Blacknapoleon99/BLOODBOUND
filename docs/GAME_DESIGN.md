# Game design snapshot

**BLOODBOUND: The Hollow Covenant** — an original, grim, cinematic action platformer. The world is fully 3D, but default locomotion is a constrained, readable side-scrolling plane. A towering enemy attacks from behind the level along the depth axis, influencing platforms, props and attack zones.

## Intended player fantasy

A doomed knight uses a cursed weapon and stolen ritual cards to push toward ancient beings far larger than themselves. Combat is dangerous and intentional; cards create tactical counterplay rather than automatic victories.

## 30-second loop

See a threat -> navigate ruins while reading telegraphs -> attack/dodge -> gain blood energy -> spend a card opportunistically -> advance -> checkpoint or boss phase -> repeat.

## Design constraints

- Responsive controls before polish.
- All attacks must be readable even in near-black scenes.
- Boss can be seen in background yet hit the *foreground*; the spatial threat volume is genuine.
- Cards work while the game is running, not in a detached turn-based combat screen.
- 3D arena moments are special punctuation, not a permanent genre shift.
- Avoid excessive repetition; each boss phase introduces at least one meaningful mechanic.

## First level beats

Ruined approach -> movement gaps -> lone enemy -> collapse warning -> checkpoint -> bishop stalking bridge -> timed destructible platform event -> boss opening -> three-card tutorial -> boss victory. Optional small chapel 3D fracture nearby.
