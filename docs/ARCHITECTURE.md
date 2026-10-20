# Architecture and extension points

## Current tiny bootstrap (not final game architecture)

- `scenes/main.tscn` uses `scripts/main.gd` to spawn small procedural test world, camera, HUD, dummy, exit and 3D practice area.
- `scenes/player.tscn` is a `CharacterBody3D` with `scripts/player.gd`, capsule mesh and collider.
- The baseline intentionally has **no external textures, sound, animations or shaders**, making it robust for initial agent inspection.

## Target architecture

```text
scenes/
  gameplay/main_menu.tscn, weeping_causeway.tscn
  actors/player.tscn, basic_enemy.tscn, hollow_bishop.tscn
  systems/card_hand.tscn, combat_hud.tscn
scripts/
  actors/player_controller.gd, player_motor.gd, player_combat.gd
  combat/health.gd, damage_event.gd, hitbox.gd, hurtbox.gd
  combat/attack_definition.gd, attack_state_machine.gd
  ai/enemy_brain.gd, boss_brain.gd, boss_attack.gd
  cards/card_definition.gd, deck.gd, hand.gd, card_effect.gd
  world/checkpoint.gd, destructible.gd, encounter_manager.gd
  camera/camera_director.gd, mode_transition.gd
  ui/hud_controller.gd, card_overlay.gd
resources/cards/*.tres
assets/incoming/, assets/processed/
```

**Do not produce empty classes solely to satisfy the diagram.** Build each subsystem when a milestone actually requires it.

Coordinates: X right, Y up, Z depth. 2.5D movement Z=0; combat, boss attacks, and platforms use true 3D physics. Arena uses shared player but unlocked Z and third-person camera.

**Signals and events:** damage requested/taken, character killed, checkpoint activated, boss attack telegraph/impact, world section broken, card played/rejected, camera mode entering/completed. Systems should not call arbitrary other scene descendants by brittle relative paths.

**Asset swaps:** child `VisualRoot` should hold imported appearance, animation and sockets, while `CharacterBody3D` collision and root script remain stable. Keep scaling at asset root and validate authored units.

**Determinism:** seed procedural cards, boss phases and hazard layout when running tests. Difficulty must not depend on nondeterministic timing of AI external calls.
