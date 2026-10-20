extends SceneTree
## Diagnostic (not part of the smoke suite): exercises every damaging ability the way a player
## would — real key presses, AI running — and logs each layer so failures can be located.
## Run: godot_console --headless --path . -s res://tests/diag_abilities.gd

var main: Node3D
var player: CharacterBody3D
var cards: CardSystem
var energy: BloodEnergy


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    GameSettings.persistence_enabled = false
    change_scene_to_file("res://scenes/main.tscn")
    for i in 10:
        await process_frame
    main = current_scene as Node3D
    player = main.get("player")
    cards = player.get_node("Cards")
    energy = player.get_node("BloodEnergy")
    cards.card_played.connect(func(c: CardData, s: int) -> void: print("  [cards] PLAYED %s (slot %d) energy now %.2f" % [c.id, s + 1, energy.current]))
    cards.card_failed.connect(func(c: CardData, s: int, r: StringName) -> void: print("  [cards] FAILED %s (slot %d) reason=%s energy=%.2f" % [c.id if c else &"-", s + 1, r, energy.current]))
    print("hand: ", cards.deck.hand.map(func(c: CardData) -> StringName: return c.id))
    await _wait(1.0)

    print("\n=== A. 2.5D soldier, cards + melee ===")
    var soldier: PlaguedSoldier = main.get("enemy")
    soldier.set_ai_enabled(false)
    player.call("teleport_to", Vector3(3.2, 1.0, 0.0))
    soldier.teleport_to(Vector3(5.0, 1.0, 0.0))
    await _wait(0.5)
    energy.set_amount(6.0)
    for i in 3:
        print(" press key %d (soldier hp=%d)" % [i + 1, soldier.health.current])
        await _tap(KEY_1 + i)
        await _wait(0.8)
        print("  -> soldier hp=%d" % soldier.health.current)
    print(" press J at distance %.2f (soldier hp=%d)" % [soldier.global_position.x - player.global_position.x, soldier.health.current])
    await _tap(KEY_J)
    await _wait(0.6)
    print("  -> soldier hp=%d" % soldier.health.current)

    print("\n=== B. Bishop fight, AI on, player plays like a human ===")
    var boss: HollowBishop = main.get("boss")
    var arena: BossArena = main.get("boss_arena")
    soldier.health.apply_damage(99)
    await _wait(0.5)
    player.call("teleport_to", Vector3(arena.left_x() + 3.0, 1.0, 0.0))
    await _wait(0.3)
    boss.min_x = arena.left_x() + 4.0
    boss.max_x = arena.right_x() - 4.0
    boss.begin_fight()
    boss.attack_started.connect(func(a: StringName) -> void: print("  [boss] attack %s" % a))
    boss.weak_point_changed.connect(func(o: bool) -> void: print("  [boss] weak point %s (hand x=%.1f, player x=%.1f)" % ["OPEN" if o else "closed", boss.hand.global_position.x, player.global_position.x]))
    boss.health.changed.connect(func(c: int, m: int) -> void: print("  [boss] HP %d/%d" % [c, m]))
    (player.get("health") as Health).damaged.connect(func(a: int) -> void: print("  [player] took %d" % a))
    var t: float = 0.0
    var spear_tried_this_window: bool = false
    while t < 40.0 and boss.health.current > 0:
        await physics_frame
        t += 1.0 / 60.0
        if (player.get("health") as Health).current < 3:
            (player.get("health") as Health).restore_full()  # keep the run going
        if boss.hand.weak_open:
            var dx: float = boss.hand.global_position.x - player.global_position.x
            if not spear_tried_this_window:
                spear_tried_this_window = true
                energy.set_amount(6.0)
                print("  window open: trying Blood Spear from dx=%.2f" % dx)
                await _tap(KEY_1 + _slot_of(&"blood_spear"))
            elif absf(dx) > 1.3:
                # walk toward the hand like a player would
                _key(KEY_D if dx > 0 else KEY_A, true)
            else:
                _key(KEY_D, false)
                _key(KEY_A, false)
                player.set("facing_direction", signf(dx))
                await _tap(KEY_J)
        else:
            spear_tried_this_window = false
            _key(KEY_D, false)
            _key(KEY_A, false)
    print(" result after %.1fs: boss HP %d" % [t, boss.health.current])

    print("\n=== C. Blood Spear while the Bishop is idle / hand raised ===")
    energy.set_amount(6.0)
    await _tap(KEY_1 + _slot_of(&"blood_spear"))
    await _wait(0.5)
    quit()


func _slot_of(id: StringName) -> int:
    for i in cards.deck.hand.size():
        if cards.deck.hand[i].id == id:
            return i
    return 0


func _key(code: Key, pressed: bool) -> void:
    var ev: InputEventKey = InputEventKey.new()
    ev.keycode = code
    ev.physical_keycode = code
    ev.pressed = pressed
    Input.parse_input_event(ev)


func _tap(code: Key) -> void:
    _key(code, true)
    await physics_frame
    await physics_frame
    _key(code, false)


func _wait(seconds: float) -> void:
    for i in int(seconds * 60.0):
        await physics_frame
