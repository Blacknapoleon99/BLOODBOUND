extends Node3D
## Procedural greybox level: causeway → Plagued Soldier → portcullis → Pursuit Approach
## (collapsing slabs, moving platform, the Bishop hurling lances) → Hollow Bishop arena.
## The optional Reality Fracture (free 3D arena) is entered at the amber gate; see RealityFracture.
## Goal: easily replaceable greybox; level rules (checkpoints, resets, victory) live here.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const SOLDIER_SCENE: PackedScene = preload("res://scenes/enemies/plagued_soldier.tscn")
const SPAWN_POSITION: Vector3 = Vector3(-16.0, 2.0, 0.0)
const ENEMY_POSITION: Vector3 = Vector3(5.0, 1.0, 0.0)
const GATE_POSITION: Vector3 = Vector3(13.0, 1.0, 0.0)
const CHECKPOINT_POSITION: Vector3 = Vector3(-4.5, 1.2, 0.0)
const PORTCULLIS_X: float = 18.6
## Positions after the opening are shifted by `map_offset` (the total width of the run's rooms).
const APPROACH_START_X: float = 18.2
const APPROACH_CHECKPOINT_POSITION: Vector3 = Vector3(20.6, 1.2, 0.0)
const PURSUIT_START_X: float = 20.0
const BOSS_ARENA_START_X: float = 58.2
const BOSS_CHECKPOINT_POSITION: Vector3 = Vector3(60.6, 1.2, 0.0)
const FIGHT_START_X: float = 60.0

var player: CharacterBody3D
var camera: Camera3D
var enemy: PlaguedSoldier
var checkpoint: Checkpoint
var boss_checkpoint: Checkpoint
var approach_checkpoint: Checkpoint
var collapsing_slabs: Array[CollapsingSlab] = []
var ferry: MovingPlatform
var boss: HollowBishop
var boss_arena: BossArena
var portcullis: StaticBody3D
var boss_bar: ProgressBar
var boss_label: Label
var fracture: RealityFracture
var altars: Array[BloodAltar] = []
var offer_overlay: CardOfferOverlay
var card_system: CardSystem
## Co-op: both players (players[0] is `player`). `_actor` is whoever is interacting right now.
var players: Array[CharacterBody3D] = []
var _actor: CharacterBody3D
var _revive_progress: Dictionary = {}  # downed player -> seconds of partner holding Interact
const COOP_LEASH: float = 18.0
const REVIVE_TIME: float = 1.2
var _pending_altar: BloodAltar
var _fall_screamed: bool = false
var _callout_cooldown: float = 0.0
var loot_chest: LootChest
var _pending_chest: LootChest
var _shop: MerchantStall
const PRICES: Dictionary = {&"card": 30, &"relic": 60, &"heal": 25, &"upgrade": 40}
var _loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _reward_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ambushes: Array[Ambush] = []
## The run's shuffled rooms (LevelLayout), between the opening and the Bishop's approach.
var sections: Array[LevelSection] = []
## The 3D run's practice stations round the opening causeway (DEC-052; null in the side view).
var opening: OpeningGrounds
var map_offset: float = 0.0
var traps: Array[Node3D] = []  # SpikeTrap and PendulumBlade hazards
var respawn_point: Vector3 = SPAWN_POSITION
var hud: Label
var enemy_alive: bool = true
var arena_visited: bool = false
var game_won: bool = false
var _message: String = ""
var _message_until: float = 0.0
var _trauma: float = 0.0
var hurt_vignette: ColorRect
var phase_banner: Label
var _banner_left: float = 0.0
## The 3D run (RunState.full_3d, solo): rooms are 3D halls played with the third-person camera.
## Until the Bishop is rebuilt in 3D (phase 4), the run hands over to the side view at the
## Pursuit Approach (`enter_side_view`).
var full_3d: bool = false
var cam3d: ThirdPersonCamera
var _rear_gate: StaticBody3D
var targeting: CardTargeting


func _ready() -> void:
    InputBindings.configure_players(RunState.coop)
    full_3d = RunState.full_3d and not RunState.coop
    Lane.full_3d = full_3d
    EnemyFactory.full_3d = full_3d
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    process_physics_priority = 10  # after the players move (co-op leash)
    GameSettings.load_settings()
    add_to_group(&"camera_shaker")
    _build_greybox()
    ArtSwap.apply(self)  # visual-only model swaps; collision stays greybox
    player = PLAYER_SCENE.instantiate() as CharacterBody3D
    player.add_to_group(&"player")
    card_system = player.get_node("Cards") as CardSystem
    if RunState.active and not RunState.deck.is_empty():
        card_system.starter_cards = RunState.deck.duplicate()  # the drafted deck
        card_system.deck_seed = RunState.seed_value
        _reward_rng.seed = RunState.seed_value + 1
    else:
        _reward_rng.seed = 4242
    add_child(player)
    player.global_position = SPAWN_POSITION
    players.append(player)
    _actor = player
    if RunState.coop:
        var p2: CharacterBody3D = PLAYER_SCENE.instantiate() as CharacterBody3D
        p2.name = "Player2"
        p2.set("input_prefix", "p2_")
        p2.set("player_index", 1)
        p2.add_to_group(&"player")
        var cards2: CardSystem = p2.get_node("Cards") as CardSystem
        if RunState.active and not RunState.deck_p2.is_empty():
            cards2.starter_cards = RunState.deck_p2.duplicate()
        cards2.deck_seed = (RunState.seed_value if RunState.active else 4242) + 11
        p2.set("body_color", Color(0.88, 0.45, 0.32))  # player 2 wears red
        add_child(p2)
        p2.global_position = SPAWN_POSITION + Vector3(1.4, 0.0, 0.0)
        players.append(p2)
    add_to_group(&"death_listeners")
    if not RunState.active:
        RunState.relics.clear()  # a directly opened level starts bare
        RunState.shards = 0
    for relic: RelicData in RunState.relics:
        _apply_relic(relic, false)
    Profile.ensure_loaded()
    for p: CharacterBody3D in players:
        Equipment.apply(p, cards_of(p), Profile.equipped_items())
        p.connect("died", _on_player_died.bind(p), CONNECT_DEFERRED)  # after the killing hit resolves
    _connect_audio()

    camera = Camera3D.new()
    camera.name = "SideViewOrArenaCamera"
    camera.fov = 52.0
    camera.current = true
    camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # moved every rendered frame
    add_child(camera)
    camera.global_position = player.global_position + Vector3(0.0, 4.8, 22.0)
    camera.look_at(player.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
    if full_3d:
        player.set("in_3d_mode", true)
        player.floor_snap_length = 0.35
        player.floor_max_angle = deg_to_rad(50.0)
        cam3d = ThirdPersonCamera.create(player)
        add_child(cam3d)
        player.set("view_camera", cam3d)
        cam3d.yaw = -PI * 0.5  # looking down the hall (+X)
    fracture.teleported.connect(func(_to_3d: bool) -> void: _snap_camera())
    fracture.entered.connect(_on_fracture_entered)
    fracture.exited.connect(_on_fracture_exited)

    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.name = "MinimalHUD"
    add_child(canvas)
    hud = Label.new()
    hud.name = "ControlsHUD"
    hud.position = Vector2(22, 20)
    hud.add_theme_font_size_override("font_size", 19)
    hud.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
    hud.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.02))
    hud.add_theme_constant_override("shadow_offset_x", 2)
    hud.add_theme_constant_override("shadow_offset_y", 2)
    canvas.add_child(hud)
    _build_boss_bar(canvas)
    hurt_vignette = ColorRect.new()
    hurt_vignette.name = "HurtVignette"
    hurt_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
    hurt_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hurt_vignette.material = _vignette_material()
    hurt_vignette.color = Color(0.7, 0.0, 0.02, 0.0)
    canvas.add_child(hurt_vignette)
    canvas.move_child(hurt_vignette, 0)
    for p: CharacterBody3D in players:
        p.connect("hurt", func(_info: DamageInfo) -> void: hurt_vignette.color.a = 0.55)
    phase_banner = MenuStyle.label("", 46, Color(0.95, 0.85, 0.8))
    phase_banner.name = "PhaseBanner"
    phase_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
    phase_banner.offset_top = 150.0
    phase_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
    phase_banner.visible = false
    canvas.add_child(phase_banner)
    boss.phase_changed.connect(_on_boss_phase_changed)
    var card_ui: CardHandUI = CardHandUI.create(card_system)
    canvas.add_child(card_ui)
    targeting = CardTargeting.create(card_system, card_ui, cam3d.camera if full_3d else camera, boss)
    targeting.hint.connect(func(text: String) -> void: _flash(text, 2.5))
    add_child(targeting)
    card_system.card_played.connect(_on_card_played)
    card_system.card_failed.connect(_on_card_failed)
    if players.size() > 1:
        var cards2: CardSystem = cards_of(players[1])
        var card_ui2: CardHandUI = CardHandUI.create(cards2)
        card_ui2.name = "CardHandP2"
        card_ui2.anchor_left = 1.0
        card_ui2.anchor_right = 1.0
        card_ui2.offset_left = -400.0
        card_ui2.offset_right = -22.0
        canvas.add_child(card_ui2)
        cards2.card_played.connect(_on_card_played)
        cards2.card_failed.connect(_on_card_failed)
    add_child(PauseMenu.create())
    offer_overlay = CardOfferOverlay.create()
    offer_overlay.resolved.connect(_on_offer_resolved)
    add_child(offer_overlay)
    if full_3d:
        _flash("3D RUN: cross the open courses (your own way: every room has several routes), defeat the plagued soldier, and reach the cathedral. Q locks on.", 7.0)
    else:
        _flash("Cross the causeway, defeat the plagued soldier, and face what waits beyond the gate.", 7.0)


## True while `who` (default: player 1) is inside the Reality Fracture (the side view's 3D
## detour). In the 3D run everyone is free-moving and the fracture stays closed.
func in_fracture(who: Node = null) -> bool:
    if who == null:
        who = player
    return bool(who.get("in_3d_mode")) and cam3d == null


func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    var in_arena: bool = in_fracture()
    if cam3d == null:
        _update_camera(delta)
    elif Players.leader().global_position.x > APPROACH_START_X + map_offset + 0.3:
        enter_side_view()
    _apply_shake(delta)
    hurt_vignette.color.a = move_toward(hurt_vignette.color.a, 0.0, 1.4 * delta)
    if _banner_left > 0.0:
        _banner_left -= delta
        phase_banner.modulate.a = clampf(_banner_left / 0.6, 0.0, 1.0)
        phase_banner.visible = _banner_left > 0.0

    _callout_cooldown = maxf(0.0, _callout_cooldown - delta)
    if player.is_on_floor():
        _fall_screamed = false
    elif not _fall_screamed and player.global_position.y < -1.5 and player.velocity.y < -7.0:
        _fall_screamed = true
        Audio.sfx(&"player_fall", 0.03)  # falling into the abyss
    if cam3d != null:
        _track_safe_ground(delta)
    for p: CharacterBody3D in players.duplicate():
        if p.global_position.y < -9.0:
            _fall_respawn(p)
    _tick_revives(delta)
    var lead: Node3D = Players.leader()

    if not in_arena and enemy_alive and absf(player.global_position.x - (PORTCULLIS_X - 0.8)) < 1.0:
        _flash("The portcullis is sealed while the plagued soldier stands.", 1.0)
    if not in_arena and boss.phase == HollowBishop.Phase.DORMANT and lead.global_position.x > PURSUIT_START_X + map_offset:
        boss.awaken()
        Audio.voice(&"vo_awaken", true)
        _flash("THE HOLLOW BISHOP rises from the abyss — run for the cathedral!", 3.5)
    if not in_arena and not boss.fight_started and lead.global_position.x > FIGHT_START_X + map_offset:
        boss.min_x = boss_arena.left_x() + 4.0
        boss.max_x = boss_arena.right_x() - 4.0
        boss.begin_fight()
        Audio.music(&"music_boss")
        Audio.voice(&"vo_fight", true)
        _flash("The Bishop turns to face you. Strike the stigmata when its hand falls.", 3.5)
    _update_boss_bar()
    var ambush_now: Ambush = _active_ambush()
    boss.pursuit_hold = ambush_now != null
    if ambush_now != null and _message == "":
        _message = "AMBUSH — %d foe(s) remain" % ambush_now.alive_count()
        _message_until = 0.2

    if _message_until > 0.0:
        _message_until -= delta
        if _message_until <= 0.0:
            _message = ""

    var state: String = "REALITY FRACTURE — WASD move / SPACE jump / LEFT CLICK light / RIGHT CLICK heavy / SHIFT dodge / cards: 1-3 or click" if in_arena else "2.5D — A/D move / SPACE jump / LEFT CLICK light / RIGHT CLICK heavy / SHIFT dodge / cards: 1-3 or click / E amber gate"
    var player_health: Health = player.get("health")
    # ASCII only: the web build ships just Godot's default font (no box-drawing glyphs).
    var hp: String = "HP %d/%d    SHARDS %d" % [player_health.current, player_health.max_health, RunState.shards]
    if players.size() > 1:
        var h2: Health = players[1].get("health")
        hp = "P1 HP %d/%d%s    P2 HP %d/%d%s    SHARDS %d" % [player_health.current, player_health.max_health, " DOWN" if bool(player.get("is_downed")) else "",
            h2.current, h2.max_health, " DOWN" if bool(players[1].get("is_downed")) else "", RunState.shards]
    var objective: String = "SOLDIER: DEFEATED" if not enemy_alive else "SOLDIER: %d HP" % enemy.health.current
    if not enemy_alive:
        objective = "BISHOP: SLAIN" if boss.phase == HollowBishop.Phase.DEFEATED else "GATE: OPEN"
    var arena_state: String = "FRACTURE: OPTIONAL"
    if fracture.state == RealityFracture.State.CLEARED:
        arena_state = "FRACTURE: SEALED"
    elif in_arena:
        arena_state = "GUARDIAN: DEFEATED — ENTER THE PORTAL" if fracture.portal_open else "GUARDIAN: %d HP" % fracture.guardian.health.current
    var checkpoint_state: String = "CHECKPOINT: SET" if checkpoint.is_active else "CHECKPOINT: —"
    var room: LevelSection = current_section()
    if room != null:
        checkpoint_state = "ROOM %d/%d: %s" % [sections.find(room) + 1, sections.size(), room.title.to_upper()]
    checkpoint_state += "    DECK %d" % card_system.deck.total_cards()
    if not RunState.relics.is_empty():
        checkpoint_state += "    RELICS: " + relic_names()
    for altar: BloodAltar in altars:
        if altar.player_in_reach(player) and _message == "":
            _message = "E: offer blood at the altar for a new card"
            _message_until = 0.2
    if cam3d != null:
        state = "3D RUN — WASD move / mouse look / SPACE jump / LEFT CLICK light / RIGHT CLICK heavy / SHIFT dodge / Q lock on / cards: 1-3 / E use"
        if cam3d.lock_target != null:
            state += "    LOCKED: " + String(cam3d.lock_target.name)
    hud.text = "BLOODBOUND — GREYBOX VERTICAL SLICE\n" + state + "\n" + hp + "    " + objective + "    " + arena_state + "    " + checkpoint_state + "\n" + _message


func _unhandled_input(event: InputEvent) -> void:
    if event.is_echo() or offer_overlay.is_open():
        return
    if event.is_action_pressed(&"restart") and game_won:
        RunState.end_run()
        get_tree().change_scene_to_file("res://scenes/armory.tscn")  # spoils + gear, then a new draft
        return
    var actor: CharacterBody3D = _interactor(event)
    if actor != null:
        _actor = actor
    if actor != null and game_won and loot_chest != null and loot_chest.player_in_reach(actor):
        _pending_chest = loot_chest
        _open_loot()
        return
    if actor == null or game_won or bool(actor.get("is_downed")):
        return
    if _downed_partner_near(actor) != null:
        return  # holding Interact revives (see _tick_revives)
    if fracture.is_transitioning():
        return
    if _active_ambush() != null:
        _flash("The bone walls hold until every foe is slain.", 2.0)
        return
    for node: Node in get_tree().get_nodes_in_group(&"shortcut"):
        var cut: LeverShortcut = node as LeverShortcut
        if cut.lever_in_reach(actor):
            cut.pull()
            _flash("A bridge of bone knits across behind you: a shortcut back.", 3.0)
            return
    var stall: MerchantStall = get_tree().get_first_node_in_group(&"merchant") as MerchantStall
    if stall != null and stall.player_in_reach(actor):
        _open_shop(stall)
        return
    for node: Node in get_tree().get_nodes_in_group(&"loot_chest"):
        var chest: LootChest = node as LootChest
        if chest != loot_chest and chest.player_in_reach(actor):
            _open_chest(chest)
            return
    for altar: BloodAltar in altars:
        if altar.player_in_reach(actor):
            _pending_altar = altar
            Audio.sfx(&"altar", 0.0)
            offer_overlay.open("BLOOD ALTAR — a card for your deck, or a relic", _altar_offer())
            return
    if RunState.coop and actor.global_position.distance_to(GATE_POSITION) < 2.7:
        _flash("The fracture admits only a lone soul (solo only, for now).", 2.0)
        return
    if full_3d and cam3d == null:
        _flash("The Reality Fracture is closed in the 3D run.", 2.0)
    elif full_3d:
        _flash("Nothing to use here.", 1.5)
    elif in_fracture():
        if fracture.portal_open:
            _flash("Step into the burning portal to return.", 2.0)
        else:
            _flash("The fracture holds you until its guardian falls.", 2.0)
    elif player.global_position.distance_to(GATE_POSITION) < 2.7:
        if fracture.can_enter():
            fracture.enter(player)
        else:
            _flash("The fracture has sealed. Nothing stirs beyond the gate.", 2.0)
    else:
        _flash("Approach the amber pillar at x = 13 to enter the Reality Fracture.", 2.0)


func _on_enemy_defeated() -> void:
    enemy_alive = false
    _open_portcullis()
    _flash("The plagued soldier falls. The portcullis grinds open.", 4.0)


func _active_ambush() -> Ambush:
    for ambush: Ambush in ambushes:
        if ambush.is_active():
            return ambush
    return null


func _on_ambush_started(ambush: Ambush) -> void:
    Audio.sfx(&"walls_rise")
    _flash("AMBUSH — bone walls rise! Slay them all.", 3.0)


func _on_ambush_cleared(_ambush: Ambush) -> void:
    _flash("The walls crumble. The way is open.", 3.0)


func _on_player_died(who: CharacterBody3D = null) -> void:
    if who == null:
        who = player
    if in_fracture(who):
        # Revived where you stand (no stray death state), then the fracture expels you.
        who.call("revive_at", who.global_position)
        fracture.fail()
        _flash("The fracture rejects you. Its guardian waits to be challenged again.", 3.5)
        return
    if players.size() > 1 and not Players.standing().is_empty():
        who.call("set_downed", true)
        _revive_progress[who] = 0.0
        _flash("PLAYER %d IS DOWN: partner, hold Interact beside them to revive!" % (int(who.get("player_index")) + 1), 3.5)
        return
    for p: CharacterBody3D in players:
        p.call("set_downed", false)
        p.call("revive_at", respawn_point + Vector3(1.4 * int(p.get("player_index")), 0.0, 0.0))
    _revive_progress.clear()
    _reset_hazards()
    _flash("You were slain — restored at the last checkpoint." if players.size() == 1 else "Both fell — restored at the last checkpoint.", 3.5)


func _on_fracture_entered() -> void:
    arena_visited = true
    _flash("REALITY FRACTURE — move freely on X/Z. Slay the guardian to open the way back.", 4.0)


func _on_fracture_exited(cleared: bool) -> void:
    if cleared:
        _flash("The fracture seals behind you. Blood and vigour restored.", 3.5)
        _pending_altar = null
        offer_overlay.open("THE FRACTURE YIELDS — a relic, or temper a card", _fracture_offer())


## The run's seeded stream when a run is active, else a local one (level opened directly).
func _offer_rng() -> RandomNumberGenerator:
    return RunState.rng if RunState.active else _reward_rng


## Offers are mixed lists, so both helpers return plain (untyped) arrays.
func _card_offer(count: int) -> Array:
    var owned: Array = cards_of(_actor).deck.all_cards().map(func(c: CardData) -> StringName: return c.id)
    return Array(CardPool.offer(_offer_rng(), count, owned), TYPE_NIL, &"", null)


func _relic_offer(count: int) -> Array:
    return Array(RelicPool.offer(_offer_rng(), count, RunState.owned_relic_ids()), TYPE_NIL, &"", null)


## Blood Altar: two new cards and a relic (three cards once every relic is taken).
func _altar_offer() -> Array:
    var relics: Array = _relic_offer(1)
    var choices: Array = _card_offer(RunState.OFFER_SIZE - relics.size())
    choices.append_array(relics)
    return choices


## Cleared fracture: two relics and an upgrade of a random un-upgraded deck card, topped up
## with new cards when relics or upgradable cards run out.
func _fracture_offer() -> Array:
    var choices: Array = _relic_offer(2)
    var upgradable: Array[CardData] = []
    for card: CardData in cards_of(_actor).deck.all_cards():
        if not card.upgraded and not upgradable.has(card):
            upgradable.append(card)
    if not upgradable.is_empty():
        var base: CardData = upgradable[_offer_rng().randi_range(0, upgradable.size() - 1)]
        choices.append(base.upgraded_copy())
    if choices.size() < RunState.OFFER_SIZE:
        choices.append_array(_card_offer(RunState.OFFER_SIZE - choices.size()))
    return choices


## The Pale Merchant: a card, a relic, a full heal and a card upgrade, rolled once per visit.
func _open_shop(stall: MerchantStall) -> void:
    if not stall.stocked:
        stall.stocked = true
        var card: Array = _card_offer(1)
        if not card.is_empty():
            stall.stock.append(ShopItem.make(&"card", card[0], PRICES[&"card"]))
        var relic: Array = _relic_offer(1)
        if not relic.is_empty():
            stall.stock.append(ShopItem.make(&"relic", relic[0], PRICES[&"relic"]))
        stall.stock.append(ShopItem.make(&"heal", null, PRICES[&"heal"]))
        var upgradable: Array = cards_of(_actor).deck.all_cards().filter(func(c: CardData) -> bool: return not c.upgraded)
        if not upgradable.is_empty():
            var base: CardData = upgradable[_offer_rng().randi_range(0, upgradable.size() - 1)]
            stall.stock.append(ShopItem.make(&"upgrade", base.upgraded_copy(), PRICES[&"upgrade"]))
    # Drop wares that went stale since the stock was rolled (relic owned, card already upgraded).
    stall.stock = stall.stock.filter(func(w: ShopItem) -> bool: return _ware_valid(w))
    _shop = stall
    _pending_altar = null
    _pending_chest = null
    if stall.stock.is_empty():
        _shop = null
        _flash("\"Sold out, little lamb.\"", 2.0)
        return
    offer_overlay.open("THE PALE MERCHANT: you hold %d Bone Shards" % RunState.shards, stall.stock, "Leave the merchant")


func _ware_valid(ware: ShopItem) -> bool:
    match ware.kind:
        &"relic":
            return not RunState.has_relic((ware.payload as RelicData).id)
        &"upgrade":
            return cards_of(_actor).deck.all_cards().has((ware.payload as CardData).upgrade_source)
    return true


## Tries to buy `ware`; reopens the shop while anything is left.
func _buy(ware: ShopItem) -> void:
    var stall: MerchantStall = _shop
    _shop = null
    if not _ware_valid(ware):
        stall.stock.erase(ware)
        _flash("\"That one is no longer for sale.\"", 2.0)
    elif RunState.shards < ware.price:
        Audio.sfx(&"card_refused", 0.0)
        _flash("Not enough Bone Shards: %d needed, you have %d." % [ware.price, RunState.shards], 2.5)
    elif ware.kind == &"heal" and (_actor.get("health") as Health).current >= (_actor.get("health") as Health).max_health:
        Audio.sfx(&"card_refused", 0.0)
        _flash("You are already whole.", 2.0)
    else:
        RunState.shards -= ware.price
        stall.stock.erase(ware)
        Audio.sfx(&"equip", 0.0)
        match ware.kind:
            &"heal":
                (_actor.get("health") as Health).restore_full()
                _flash("The tonic burns going down. Fully healed.", 2.5)
            &"relic":
                RunState.relics.append(ware.payload as RelicData)
                _apply_relic(ware.payload as RelicData, true)
                _flash("Bought %s." % (ware.payload as RelicData).display_name, 2.5)
            &"upgrade":
                var upgraded: CardData = ware.payload
                cards_of(_actor).upgrade_card(upgraded.upgrade_source, upgraded)
                RunState.replace_card(upgraded.upgrade_source, upgraded)
                _flash("%s is tempered." % upgraded.display_name, 2.5)
            _:
                cards_of(_actor).add_card(ware.payload as CardData)
                if RunState.active:
                    deck_of(_actor).append(ware.payload as CardData)
                _flash("Bought %s." % (ware.payload as CardData).display_name, 2.5)
    if not stall.stock.is_empty():
        _open_shop.call_deferred(stall)


## Elite and secret reliquaries (the Bishop's uses _open_loot).
func _open_chest(chest: LootChest) -> void:
    _pending_chest = chest
    _pending_altar = null
    match chest.kind:
        &"shards":
            add_shards(chest.shards, chest.global_position)
            chest.consume()
            _pending_chest = null
            Audio.sfx(&"loot_drop", 0.0)
            _flash("A hidden cache: %d Bone Shards." % chest.shards, 3.0)
        &"relics":
            if chest.offer.is_empty():
                chest.offer = _relic_offer(3)
            var relics: Array = chest.offer.filter(func(r: RelicData) -> bool: return not RunState.has_relic(r.id))
            if relics.is_empty():
                chest.consume()
                add_shards(30, chest.global_position)
                _flash("The reliquary is empty of relics. 30 Bone Shards instead.", 3.0)
                return
            Audio.sfx(&"altar", 0.0)
            offer_overlay.open("THE GRAVEWARDEN'S RELIQUARY: claim one relic", relics)
        &"card":
            Audio.sfx(&"altar", 0.0)
            if chest.offer.is_empty():
                chest.offer = _card_offer(3)
            offer_overlay.open("A HIDDEN SHRINE: take a card", chest.offer)
        _:
            _open_loot()


## The Bishop's reliquary: pick 1 of 3 unowned items; it goes straight into the stash.
func _open_loot() -> void:
    var chest: LootChest = _pending_chest if _pending_chest != null else loot_chest
    if chest.offer.is_empty():
        _loot_rng.randomize()
        chest.offer = Array(ItemPool.offer(_loot_rng, 3, Profile.stash), TYPE_NIL, &"", null)
    var items: Array = chest.offer
    if items.is_empty():
        loot_chest.consume()
        _flash("The reliquary is empty: you already own every item.", 3.0)
        return
    Audio.sfx(&"altar", 0.0)
    offer_overlay.open("THE BISHOP'S RELIQUARY: claim one item", items)


func _on_offer_resolved(choice: Resource) -> void:
    if _shop != null:
        if choice is ShopItem:
            _buy(choice)
        else:
            _shop = null
            _flash("\"Come back with more bones.\"", 2.0)
        return
    if choice is ItemData:
        var item: ItemData = choice
        Profile.add_item(item.id)
        Profile.pending_spoils = maxi(0, Profile.pending_spoils - 1)  # this was the victory's spoil
        Profile.save()
        (_pending_chest if _pending_chest != null else loot_chest).consume()
        _pending_chest = null
        Audio.sfx(&"equip", 0.0)
        _flash("%s claimed! Equip it in the Armory (R). %s" % [item.display_name, item.stat_line()], 999999.0)
        return
    if loot_chest != null and game_won and choice == null:
        _flash("You leave the reliquary sealed. Its spoil still waits in the Armory (R).", 999999.0)
        return
    if _pending_altar:
        _pending_altar.consume()
        _pending_altar = null
    if _pending_chest != null:
        if choice != null:
            _pending_chest.consume()
        _pending_chest = null
    if choice == null:
        _flash("You walk away. The altar's blood runs dry.", 2.0)
        return
    if choice is RelicData:
        var relic: RelicData = choice
        RunState.relics.append(relic)
        _apply_relic(relic, true)
        _flash("Relic claimed: %s — %s" % [relic.display_name, relic.description], 4.0)
        return
    var card: CardData = choice
    if card.upgrade_source != null:
        cards_of(_actor).upgrade_card(card.upgrade_source, card)
        RunState.replace_card(card.upgrade_source, card)
        _flash("%s is tempered: cost %d, cooldown %ss." % [card.display_name, card.cost, str(card.cooldown)], 3.5)
        return
    cards_of(_actor).add_card(card)
    if RunState.active:
        deck_of(_actor).append(card)
    _flash("%s joins your deck (%d cards)." % [card.display_name, cards_of(_actor).deck.total_cards()], 3.0)


## Applies one relic's stat changes to this level's player. `fresh` = just picked (instant
## bonuses such as Vessel of Plenty's blood). Rule relics (Leech Fang, Gravebloom) are read
## when they trigger, in on_combatant_died.
func _apply_relic(relic: RelicData, fresh: bool) -> void:
    for p: CharacterBody3D in players:
        _apply_relic_to(p, cards_of(p), relic, fresh)


func _apply_relic_to(player: CharacterBody3D, card_system: CardSystem, relic: RelicData, fresh: bool) -> void:
    var energy: BloodEnergy = card_system.energy
    var health: Health = player.get("health")
    match relic.id:
        &"executioners_seal":
            var melee: MeleeAttack = player.get("melee")
            for id: StringName in [&"player_light_finisher", &"player_heavy"]:
                melee.bonus_damage[id] = int(melee.bonus_damage.get(id, 0)) + 1
        &"thorned_reliquary":
            card_system.spell_damage_bonus += 1
        &"wraith_step":
            player.set("dodge_invulnerable_time", float(player.get("dodge_invulnerable_time")) + 0.12)
            player.set("dodge_cooldown", maxf(0.2, float(player.get("dodge_cooldown")) - 0.15))
        &"vessel_of_plenty":
            energy.maximum += 2.0
            energy.add(2.0 if fresh else 0.0)
            energy.changed.emit(energy.current, energy.maximum)
        &"bone_ward":
            health.max_health += 1
            health.heal(1)
            health.changed.emit(health.current, health.max_health)
        &"penitents_rosary":
            card_system.cooldown_scale *= 0.75


var kills: int = 0


## Health broadcasts every death to the "death_listeners" group.
func on_combatant_died(who: Node) -> void:
    if who == null or not who.is_in_group(&"enemy"):
        return
    kills += 1
    var value: int = int(who.get("shard_value")) if "shard_value" in who else (1 if who.name.begins_with("Husk") else 2)
    add_shards(value, (who as Node3D).global_position)
    for p: CharacterBody3D in players:
        if RunState.has_relic(&"leech_fang"):
            cards_of(p).energy.add(1.0)
        if RunState.has_relic(&"gravebloom") and kills % 4 == 0:
            (p.get("health") as Health).heal(1)


## Adds Bone Shards and floats a "+N" above `at`.
func add_shards(amount: int, at: Vector3) -> void:
    if amount <= 0:
        return
    RunState.shards += amount
    var label: Label3D = Label3D.new()
    label.text = "+%d" % amount
    label.modulate = Color(0.92, 0.86, 0.66)
    label.font_size = 64
    label.outline_size = 8
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.add_to_group(&"shard_popup")
    add_child(label)
    label.global_position = at + Vector3(0.0, 1.2, 0.0)
    var tween: Tween = label.create_tween()
    tween.tween_property(label, "global_position:y", label.global_position.y + 1.2, 0.9)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
    tween.tween_callback(label.queue_free)


func relic_names() -> String:
    var names: Array = RunState.relics.map(func(r: RelicData) -> String: return r.display_name)
    return ", ".join(names)


func _exit_tree() -> void:
    Audio.stop_voice()  # the Bishop does not follow you to the menu


## Which player pressed Interact in this event (null if none).
func _interactor(event: InputEvent) -> CharacterBody3D:
    for p: CharacterBody3D in players:
        if event.is_action_pressed(p.call("act", &"interact")):
            return p
    return null


func _partner_of(who: CharacterBody3D) -> CharacterBody3D:
    for p: CharacterBody3D in players:
        if p != who:
            return p
    return null


func cards_of(p: Node) -> CardSystem:
    return p.get_node("Cards") as CardSystem


## The run's deck list for this player (player 2 has its own).
func deck_of(p: Node) -> Array[CardData]:
    return RunState.deck_p2 if int(p.get("player_index")) == 1 else RunState.deck


func _downed_partner_near(helper: CharacterBody3D) -> CharacterBody3D:
    var partner: CharacterBody3D = _partner_of(helper)
    if partner != null and bool(partner.get("is_downed")) and partner.global_position.distance_to(helper.global_position) < 1.8:
        return partner
    return null


## Co-op revive: the standing partner holds Interact beside a downed player for REVIVE_TIME.
func _tick_revives(delta: float) -> void:
    for downed: CharacterBody3D in _revive_progress.keys():
        var helper: CharacterBody3D = _partner_of(downed)
        var holding: bool = helper != null and Players.is_standing(helper) and _downed_partner_near(helper) == downed \
                and Input.is_action_pressed(helper.call("act", &"interact"))
        _revive_progress[downed] = float(_revive_progress[downed]) + delta if holding else maxf(0.0, float(_revive_progress[downed]) - delta)
        if float(_revive_progress[downed]) >= REVIVE_TIME:
            revive(downed)


func revive(downed: CharacterBody3D) -> void:
    _revive_progress.erase(downed)
    (downed.get("health") as Health).revive(2)
    downed.call("set_downed", false)
    downed.set("_invulnerable_left", 1.0)
    Audio.sfx(&"card_transfusion", 0.0)
    _flash("PLAYER %d is back on their feet!" % (int(downed.get("player_index")) + 1), 2.5)


## Co-op leash: players stay within COOP_LEASH of each other (runs after they moved).
func _physics_process(_delta: float) -> void:
    if players.size() < 2:
        return
    var a: CharacterBody3D = players[0]
    var b: CharacterBody3D = players[1]
    if bool(a.get("in_3d_mode")) or bool(b.get("in_3d_mode")) or not Players.is_standing(a) or not Players.is_standing(b):
        return
    var spread: float = b.global_position.x - a.global_position.x
    if absf(spread) > COOP_LEASH:
        var lead: CharacterBody3D = b if spread > 0.0 else a
        var trail: CharacterBody3D = a if lead == b else b
        lead.global_position.x = trail.global_position.x + signf(spread) * COOP_LEASH
        lead.velocity.x = 0.0


## Midpoint of the standing players (the camera frames them all), at render-rate interpolated
## positions so the camera moves as smoothly as the characters.
func _focus() -> Vector3:
    var standing: Array[Node3D] = Players.standing()
    if standing.is_empty():
        return player.get_global_transform_interpolated().origin
    var sum: Vector3 = Vector3.ZERO
    for p: Node3D in standing:
        sum += p.get_global_transform_interpolated().origin
    return sum / standing.size()


var _cam_focus: Vector3 = Vector3.INF
var _cam_lead: float = 0.0
var _cam_offset: Vector3 = Vector3.INF
var _cam_aim: Vector3 = Vector3.ZERO
## Follow rates (1/s): fast horizontally so turning never leaves the camera behind, softer
## vertically so jumps don't bob the whole view; look-ahead eases toward the facing side.
const CAM_FOLLOW_X: float = 12.0
const CAM_FOLLOW_Y: float = 5.0
const CAM_LOOK_AHEAD: float = 1.6
const CAM_LEAD_RATE: float = 2.5


func _update_camera(delta: float) -> void:
    var target: Vector3 = _focus()
    var in_3d: bool = bool(player.get("in_3d_mode"))
    if not in_3d and players.size() == 1:
        _cam_lead = lerpf(_cam_lead, float(player.get("facing_direction")) * CAM_LOOK_AHEAD, 1.0 - exp(-CAM_LEAD_RATE * delta))
        target.x += _cam_lead
    if _cam_focus == Vector3.INF or (target - _cam_focus).length() > 15.0:
        _cam_focus = target  # first frame or a teleport/respawn: cut, don't sweep
    _cam_focus.x = lerpf(_cam_focus.x, target.x, 1.0 - exp(-CAM_FOLLOW_X * delta))
    _cam_focus.y = lerpf(_cam_focus.y, target.y, 1.0 - exp(-CAM_FOLLOW_Y * delta))
    _cam_focus.z = lerpf(_cam_focus.z, target.z, 1.0 - exp(-CAM_FOLLOW_X * delta))
    # Position and aim come from the same smoothed point, so the view slides and never swivels;
    # only the framing offset itself eases (arena pull-back, co-op spread, 3D arena).
    var offset: Vector3 = _camera_goal_for(_cam_focus) - _cam_focus
    var aim: Vector3 = _camera_look_target_for(_cam_focus) - _cam_focus
    if _cam_offset == Vector3.INF:
        _cam_offset = offset
        _cam_aim = aim
    _cam_offset = _cam_offset.lerp(offset, 1.0 - exp(-4.0 * delta))
    _cam_aim = _cam_aim.lerp(aim, 1.0 - exp(-4.0 * delta))
    camera.global_position = _cam_focus + _cam_offset
    camera.look_at(_cam_focus + _cam_aim, Vector3.UP)


func _spread() -> float:
    var standing: Array[Node3D] = Players.standing()
    if standing.size() < 2:
        return 0.0
    return absf(standing[0].global_position.x - standing[1].global_position.x)


func _camera_goal() -> Vector3:
    return _camera_goal_for(_focus())


func _camera_goal_for(focus: Vector3) -> Vector3:
    var offset: Vector3 = Vector3(0.0, 4.8, 22.0)
    if bool(player.get("in_3d_mode")):
        offset = Vector3(0.0, 5.8, 11.5)
    elif focus.x > APPROACH_START_X + map_offset + 0.4:
        offset = Vector3(0.0, 6.5, 24.0)  # pull back so the Bishop fits in frame
    offset.z += clampf(_spread() - 6.0, 0.0, 12.0) * 0.9  # pull back as co-op players spread
    return focus + offset


func _camera_look_target() -> Vector3:
    return _camera_look_target_for(_focus())


func _camera_look_target_for(focus: Vector3) -> Vector3:
    var in_boss_arena: bool = not bool(player.get("in_3d_mode")) and focus.x > APPROACH_START_X + map_offset + 0.4
    return focus + Vector3(0.0, 4.0 if in_boss_arena else 1.2, 0.0)


## Called while the fracture fade is fully black: jump the camera to its new framing.
func _snap_camera() -> void:
    _cam_focus = Vector3.INF
    _cam_offset = Vector3.INF
    camera.global_position = _camera_goal() + Vector3(0.0, 1.5, 3.0)  # slightly wide, then eases in
    camera.look_at(_camera_look_target(), Vector3.UP)


## Spell out *why* a card was refused, so a refusal never reads as "the card is broken".
func _on_card_failed(card: CardData, _slot: int, reason: StringName) -> void:
    if card == null:
        return
    var why: String = ""
    match reason:
        &"no_target":
            match card.targeting:
                CardData.Targeting.ENEMY, CardData.Targeting.BOSS_WEAK_POINT:
                    why = "no enemy or exposed stigmata within %d m" % int(card.card_range)
                CardData.Targeting.BOSS_TELEGRAPH:
                    why = "only while the Bishop's hand is winding up a strike"
                _:
                    why = "no target"
        &"out_of_range":
            why = "target is beyond %d m — move closer" % int(card.card_range)
        &"not_exposed":
            why = "the stigmata is sealed — wait for the Bishop's hand to fall onto the causeway"
        &"energy":
            why = "needs %d blood (land hits to earn more)" % card.cost
        &"cooldown":
            why = "still recovering"
        &"blocked":
            why = "you cannot act right now"
        &"too_weak":
            why = "it would cost the last of your life"
        &"full_health":
            why = "you are already at full health"
    _flash("%s: %s" % [card.display_name, why], 2.0)


func _on_card_played(card: CardData, _slot: int) -> void:
    _flash(card.display_name.to_upper() + "!", 1.5)


## A big title whenever the Bishop enters a new fight phase (it roars meanwhile).
func _on_boss_phase_changed(_phase_name: String) -> void:
    var title: String = boss.phase_title()
    if title == "" or boss.phase == HollowBishop.Phase.PROCESSION:
        return
    phase_banner.text = "THE HOLLOW BISHOP
" + title
    phase_banner.visible = true
    phase_banner.modulate.a = 1.0
    _banner_left = 2.4


const CARD_SOUNDS: Dictionary = {
    &"blood_spear": &"card_spear", &"grave_shield": &"card_shield", &"ritual_chains": &"card_chains",
    &"bell_of_silence": &"card_bell", &"epitaph": &"card_epitaph", &"hemorrhage_pact": &"card_pact",
    &"ashen_choir": &"card_choir", &"transfusion": &"card_transfusion",
    &"shadow_step": &"card_step", &"grave_hook": &"card_hook", &"ossuary_bridge": &"card_bridge",
    &"blood_nova": &"card_nova", &"haste_sigil": &"card_haste",
}


## Sounds for gameplay events, driven by signals so gameplay scripts stay audio-free.
func _connect_audio() -> void:
    Audio.apply_volumes()
    Audio.music(&"music_level")
    for p: CharacterBody3D in players:
        p.connect("attack_started", _on_player_attack_audio)
        p.connect("dodge_started", func(_d: Vector3) -> void: Audio.sfx(&"dodge"))
        p.connect("dodge_refused", func() -> void:
            Audio.sfx(&"card_refused", 0.0)
            _flash("Not enough blood to dash (%.1f needed)." % float(p.get("dodge_blood_cost")), 1.2))
        p.connect("jumped", func() -> void: Audio.sfx(&"jump", 0.1, -6.0))
        p.connect("landed", func() -> void: Audio.sfx(&"land", 0.1, -8.0))
        p.connect("hurt", func(_i: DamageInfo) -> void: Audio.sfx(&"player_hurt"))
        p.connect("died", func() -> void:
            Audio.sfx(&"death")
            Audio.sfx(&"player_death", 0.0)
            if boss.fight_started and boss.is_active() and Players.standing().is_empty():
                get_tree().create_timer(1.2).timeout.connect(func() -> void: Audio.voice(&"vo_taunt", true)))
        var cards: CardSystem = cards_of(p)
        cards.card_played.connect(func(card: CardData, _slot: int) -> void: Audio.sfx(CARD_SOUNDS.get(card.effect, &"card_spear")))
        cards.card_failed.connect(func(_c: CardData, _slot: int, _r: StringName) -> void: Audio.sfx(&"card_refused", 0.0))


func _on_player_attack_audio(id: StringName) -> void:
    match id:
        &"player_light_finisher":
            Audio.sfx(&"slash_finisher")
            Audio.sfx(&"player_effort", 0.04, -3.0)
        &"player_heavy":
            Audio.sfx(&"heavy_swing")
            Audio.sfx(&"player_effort", 0.04)
        _:
            Audio.sfx(&"slash", 0.12)


const PHASE_LINES: Dictionary = {"COLLAPSE": &"vo_phase2", "COVENANT": &"vo_phase3", "UNMAKING": &"vo_phase4"}
const ATTACK_LINES: Dictionary = {
    &"slam": &"vo_slam", &"sunder": &"vo_slam", &"beam": &"vo_beam", &"summon": &"vo_summon",
    &"bone_rain": &"vo_rain", &"marrow_geyser": &"vo_geyser",
}


func _on_boss_audio_phase(phase_name: String) -> void:
    if phase_name in ["INTRO", "COLLAPSE", "COVENANT", "UNMAKING"]:
        Audio.sfx(&"bishop_roar", 0.03)
    if PHASE_LINES.has(phase_name):
        Audio.voice(PHASE_LINES[phase_name], true)
        _callout_cooldown = 6.0


func _on_boss_audio_attack(attack: StringName) -> void:
    # Callouts: never over another line, at most one every 4 s, so they stay menacing, not chatty.
    if ATTACK_LINES.has(attack) and _callout_cooldown <= 0.0 and boss.fight_started:
        if Audio.voice(ATTACK_LINES[attack]):
            _callout_cooldown = 4.0
    match attack:
        &"lance", &"lance_volley":
            Audio.sfx(&"lance_whistle")
        &"censer":
            Audio.sfx(&"censer_swing")
        &"beam":
            Audio.sfx(&"beam_charge", 0.0)
        &"summon":
            Audio.sfx(&"summon")
        &"bone_rain":
            Audio.sfx(&"bone_rain")
        &"marrow_geyser":
            Audio.sfx(&"geyser")


func _on_boss_defeated() -> void:
    Audio.stop_music()
    Audio.voice(&"vo_death", true)
    Audio.sfx(&"victory", 0.0)
    game_won = true
    for p: CharacterBody3D in players:
        p.set("game_frozen", true)
    Profile.pending_spoils += 1
    Profile.save()
    # The reliquary rises right beside the (frozen) player so it can be opened at once.
    loot_chest = LootChest.create(Vector3(player.global_position.x + float(player.get("facing_direction")) * 1.2, player.global_position.y - 0.85, 0.0))
    add_child(loot_chest)
    Audio.sfx(&"loot_drop", 0.0)
    _flash("VICTORY! The Bishop drops a reliquary: press E to claim an item. R: Armory and a new run.", 999999.0)


func _on_sunder_impact(x: float) -> void:
    if boss_arena.break_at(x):
        _flash("The causeway shatters! Jump the gap or drop to the rubble.", 2.5)


## Death and falls reset every temporary hazard so the route is always recoverable.
func _reset_hazards() -> void:
    for ambush: Ambush in ambushes:
        ambush.reset()
    boss_arena.restore_all()
    for slab: CollapsingSlab in collapsing_slabs:
        slab.restore()
    boss.on_player_respawn()
    for trap: Node3D in traps:
        trap.call("reset")


func _open_portcullis() -> void:
    (portcullis.get_child(0) as CollisionShape3D).set_deferred(&"disabled", true)
    var tween: Tween = create_tween()
    tween.tween_property(portcullis, "position:y", 6.5, 1.2).set_ease(Tween.EASE_OUT)


## Red edges, clear centre: the screen "bleeds" when the player is hit.
static func _vignette_material() -> ShaderMaterial:
    var shader: Shader = Shader.new()
    shader.code = """
shader_type canvas_item;
void fragment() {
    vec2 d = UV - vec2(0.5);
    float edge = smoothstep(0.28, 0.75, length(d * vec2(1.25, 1.0)));
    COLOR = vec4(COLOR.rgb, COLOR.a * edge);
}
"""
    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = shader
    return material


func _build_boss_bar(canvas: CanvasLayer) -> void:
    var box: VBoxContainer = VBoxContainer.new()
    box.name = "BossBar"
    box.anchor_left = 0.5
    box.anchor_right = 0.5
    box.anchor_top = 1.0
    box.anchor_bottom = 1.0
    box.offset_left = -240.0
    box.offset_right = 240.0
    box.offset_top = -86.0
    box.offset_bottom = -24.0
    box.visible = false
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(box)
    boss_label = Label.new()
    boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_label.add_theme_font_size_override("font_size", 18)
    boss_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.8))
    box.add_child(boss_label)
    boss_bar = ProgressBar.new()
    boss_bar.custom_minimum_size = Vector2(480, 18)
    boss_bar.show_percentage = false
    boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var fill: StyleBoxFlat = StyleBoxFlat.new()
    fill.bg_color = Color(0.62, 0.05, 0.08)
    var back: StyleBoxFlat = StyleBoxFlat.new()
    back.bg_color = Color(0.08, 0.05, 0.06, 0.85)
    back.border_color = Color(0.5, 0.42, 0.36)
    back.set_border_width_all(2)
    boss_bar.add_theme_stylebox_override("fill", fill)
    boss_bar.add_theme_stylebox_override("background", back)
    box.add_child(boss_bar)


func _update_boss_bar() -> void:
    var box: Control = boss_bar.get_parent() as Control
    var elite: Gravewarden = get_tree().get_first_node_in_group(&"elite") as Gravewarden
    if elite != null and not elite.is_dead() and absf(elite.global_position.x - player.global_position.x) < 24.0:
        box.visible = true
        boss_bar.max_value = elite.health.max_health
        boss_bar.value = elite.health.current
        boss_label.text = "THE GRAVEWARDEN" + (" — ENRAGED" if elite.enraged else "")
        return
    box.visible = boss.is_active() or (boss.phase == HollowBishop.Phase.INTRO and boss.fight_started)
    boss_bar.max_value = boss.health.max_health
    boss_bar.value = boss.health.current
    boss_label.text = "THE HOLLOW BISHOP — " + boss.phase_title()


## Called through the "camera_shaker" group by HitFeedback.
func add_trauma(amount: float) -> void:
    _trauma = minf(1.0, _trauma + amount)


func _apply_shake(delta: float) -> void:
    _trauma = maxf(0.0, _trauma - 2.2 * delta)
    var power: float = _trauma * _trauma * 0.35 * GameSettings.camera_shake
    camera.h_offset = randf_range(-1.0, 1.0) * power
    camera.v_offset = randf_range(-1.0, 1.0) * power


func _respawn(who: CharacterBody3D = null) -> void:
    if who == null:
        who = player
    if in_fracture(who):
        who.call("teleport_to", fracture.spawn_point)
        _flash("Fell from the arena — returned to its centre.", 3.5)
        return
    # Co-op: rejoin a partner who is safely on the ground, at the cost of 1 HP.
    var partner: CharacterBody3D = _partner_of(who)
    if partner != null and Players.is_standing(partner) and partner.is_on_floor() and partner.global_position.y > -2.0:
        who.call("teleport_to", partner.global_position + Vector3(-0.8, 0.5, 0.0))
        (who.get("health") as Health).apply_damage(1)
        _flash("Pulled from the abyss beside your partner (-1 HP).", 2.5)
        return
    for p: CharacterBody3D in players:
        p.call("teleport_to", respawn_point + Vector3(1.4 * int(p.get("player_index")), 0.0, 0.0))
    _reset_hazards()
    if checkpoint.is_active:
        _flash("Fell into the abyss — returned to the checkpoint.", 3.5)
    else:
        _flash("Fell into the abyss — returned to the safe start.", 3.5)


## Open 3D courses (DEC-052): where each player last stood on SAFE ground — flat, static,
## not crumbling, breakable or moving, not on a spike bed, at least 1 m from every edge —
## sampled 4 times a second while the third-person camera drives the run.
var safe_ground: Dictionary = {}  # player -> Vector3
var _safe_clock: float = 0.0
const SAFE_EDGE: float = 1.0


func _track_safe_ground(delta: float) -> void:
    _safe_clock -= delta
    if _safe_clock > 0.0:
        return
    _safe_clock = 0.25
    for p: CharacterBody3D in players:
        if p.is_on_floor() and Players.is_standing(p) and is_safe_ground(p.global_position, p):
            safe_ground[p] = p.global_position


## True if a body standing at `at` (its centre) is on safe ground (see `safe_ground`).
func is_safe_ground(at: Vector3, who: CharacterBody3D = null) -> bool:
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var exclude: Array[RID] = []
    if who != null:
        exclude.append(who.get_rid())
    var floor_y: float = NAN
    for offset: Vector3 in [Vector3.ZERO, Vector3(SAFE_EDGE, 0, 0), Vector3(-SAFE_EDGE, 0, 0), Vector3(0, 0, SAFE_EDGE), Vector3(0, 0, -SAFE_EDGE)]:
        var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + offset + Vector3.UP * 0.2, at + offset + Vector3.DOWN * 1.6)
        query.exclude = exclude
        var hit: Dictionary = space.intersect_ray(query)
        if hit.is_empty():
            return false
        var body: Object = hit["collider"]
        if not (body is StaticBody3D) or body is CollapsingSlab or body is BreakableFloor or (hit["normal"] as Vector3).y < 0.94:
            return false
        var y: float = (hit["position"] as Vector3).y
        if is_nan(floor_y):
            floor_y = y
        elif absf(y - floor_y) > 0.3:
            return false
    for node: Node in get_tree().get_nodes_in_group(&"spike_trap"):
        var trap: SpikeTrap = node as SpikeTrap
        var local: Vector3 = trap.global_position - at
        if absf(local.x) < trap.width * 0.5 + 1.0 and absf(local.z) < trap.depth * 0.5 + 1.0 and absf(local.y + 0.85) < 1.0:
            return false
    return true


## Falling below the course: in the open 3D run you land back on the last safe ground for
## 1 HP (the spec's death plane); otherwise (side view, co-op, a fight in progress, no safe
## spot yet) the checkpoint respawn as before.
func _fall_respawn(who: CharacterBody3D) -> void:
    if cam3d != null and safe_ground.has(who) and _active_ambush() == null and not in_fracture(who):
        who.call("teleport_to", (safe_ground[who] as Vector3) + Vector3(0.0, 0.2, 0.0))
        for slab: CollapsingSlab in collapsing_slabs:
            slab.restore()
        (who.get("health") as Health).apply_damage(1)
        _flash("Fell into the abyss — back on solid ground (-1 HP).", 2.5)
        return
    _respawn(who)


func _on_checkpoint_activated(reached: Checkpoint) -> void:
    respawn_point = reached.respawn_position
    _flash("Checkpoint reached.", 2.5)


func _flash(message: String, seconds: float) -> void:
    _message = message
    _message_until = seconds


func _build_greybox() -> void:
    var world_env: WorldEnvironment = WorldEnvironment.new()
    var env: Environment = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.021, 0.025, 0.039)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.29, 0.31, 0.46)
    env.ambient_light_energy = 0.75
    world_env.environment = env
    add_child(world_env)

    var moonlight: DirectionalLight3D = DirectionalLight3D.new()
    moonlight.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
    moonlight.light_color = Color(0.59, 0.66, 1.0)
    moonlight.light_energy = 1.3
    add_child(moonlight)

    # Side-scrolling platforms, with a gap narrow enough for the starter jump.
    _make_solid("Starting causeway", Vector3(-13.0, -0.5, 0.0), Vector3(12.0, 1.0, 4.0), Color(0.18, 0.19, 0.23))
    _make_solid("Broken stone span", Vector3(-4.5, 0.0, 0.0), Vector3(3.0, 0.7, 3.7), Color(0.23, 0.23, 0.28))
    # Starts at x=-1.5, leaving a 1.5 m gap after the broken span (wider than the player capsule).
    _make_solid("Battle causeway", Vector3(4.0, -0.5, 0.0), Vector3(11.0, 1.0, 4.0), Color(0.17, 0.18, 0.21))
    _make_solid("Gate causeway", Vector3(13.7, -0.5, 0.0), Vector3(9.0, 1.0, 4.0), Color(0.20, 0.19, 0.23))
    _make_solid("Raised step", Vector3(0.0, 1.15, -0.2), Vector3(2.0, 0.3, 2.6), Color(0.31, 0.27, 0.29))
    _add_trap(SpikeTrap.create("Spike trap: causeway", -10.5, 0.0, 2.0, 0.0))

    if not full_3d:  # the side view's painted-on backdrop; the 3D run has no backdrop
        # Far background silhouette: visual decoration only, NOT implemented boss AI.
        _make_visual("Distant Gothic silhouette (decorative only)", Vector3(5.0, 6.0, -22.0), Vector3(3.0, 12.0, 2.8), Color(0.10, 0.065, 0.09))
        _make_visual("Left tower", Vector3(-12.0, 5.0, -18.0), Vector3(3.5, 10.0, 3.0), Color(0.07, 0.085, 0.12))
        _make_visual("Distant tower", Vector3(11.0, 7.0, -26.0), Vector3(3.5, 14.0, 3.0), Color(0.055, 0.071, 0.09))

    checkpoint = Checkpoint.create(CHECKPOINT_POSITION)
    checkpoint.activated.connect(_on_checkpoint_activated)
    add_child(checkpoint)

    enemy = SOLDIER_SCENE.instantiate() as PlaguedSoldier
    enemy.position = ENEMY_POSITION
    if full_3d:
        enemy.plane_locked = false
        enemy.leash_radius = 7.0
    enemy.defeated.connect(_on_enemy_defeated)
    add_child(enemy)

    if not full_3d:  # the Reality Fracture's gate (closed in the 3D run)
        _make_visual("Arena entry — amber", Vector3(13.0, 2.0, -0.5), Vector3(0.45, 4.0, 0.55), Color(0.95, 0.54, 0.12))

    # Portcullis: sealed until the soldier dies, so the boss is always met in order.
    portcullis = StaticBody3D.new()
    portcullis.name = "Portcullis"
    portcullis.position = Vector3(PORTCULLIS_X, 2.5, 0.0)
    var bars: CollisionShape3D = CollisionShape3D.new()
    var bars_shape: BoxShape3D = BoxShape3D.new()
    bars_shape.size = Vector3(0.4, 5.0, Lane.depth())
    bars.shape = bars_shape
    portcullis.add_child(bars)
    add_child(portcullis)
    _make_visual("Portcullis bars", Vector3.ZERO, Vector3(0.3, 5.0, Lane.depth(3.6)), Color(0.32, 0.3, 0.34), portcullis)

    _build_sections()
    if full_3d:
        # Open courses (DEC-052): no side walls; the cathedral's back wall stays behind the
        # start, and practice stations float off both sides of the causeway.
        _make_solid("Opening back wall", Vector3(-19.3, -1.0, 0.0), Vector3(0.6, 26.0, Lane.DEPTH_3D + 1.2), Color(0.1, 0.1, 0.13))
        opening = OpeningGrounds.new()
        add_child(opening)
        opening.build_grounds()
        _wire_course(opening)
    _build_approach()
    # Ambushes: E1 after the soldier (its altar is the reward), E2 on the landing mid-pursuit.
    var e1_spawns: Array[Dictionary] = [{"type": &"husk", "x": 13.6}, {"type": &"hound", "x": 16.0}, {"type": &"archer", "x": 17.5}]
    var o: float = map_offset
    var e2_spawns: Array[Dictionary] = [{"type": &"hound", "x": 40.8 + o}, {"type": &"husk", "x": 41.6 + o}, {"type": &"archer", "x": 42.2 + o}, {"type": &"archer", "x": 43.2 + o}]
    for spec: Array in [["Ambush: Gate ossuary", 10.0, 9.3, 18.3, e1_spawns], ["Ambush: Landing", 38.6 + o, 37.8 + o, 43.8 + o, e2_spawns]]:
        var ambush: Ambush = Ambush.create(spec[0], spec[1], spec[2], spec[3], spec[4])
        if spec[0] == "Ambush: Landing":
            ambush.three_d = false  # the Pursuit Approach is played in the side view (phase 4 rebuilds it)
        ambush.started.connect(_on_ambush_started)
        ambush.cleared.connect(_on_ambush_cleared)
        add_child(ambush)
        ambushes.append(ambush)
    for spot: Vector3 in [Vector3(16.8, 0.0, 0.0), Vector3(40.7 + o, 0.0, 0.0)]:
        var altar: BloodAltar = BloodAltar.create("Blood Altar %d" % (altars.size() + 1), spot)
        add_child(altar)
        altars.append(altar)

    # The Hollow Bishop's causeway and the colossus itself, 22 m behind the play plane.
    boss_arena = BossArena.new()
    boss_arena.name = "BossArena"
    add_child(boss_arena)
    boss_arena.build(BOSS_ARENA_START_X + o)
    _make_solid("Cathedral door", Vector3(boss_arena.right_x() + 0.6, 3.0, 0.0), Vector3(1.2, 7.0, 4.0), Color(0.14, 0.1, 0.12))
    boss_checkpoint = Checkpoint.create(BOSS_CHECKPOINT_POSITION + Vector3(o, 0.0, 0.0))
    boss_checkpoint.name = "BossCheckpoint"
    boss_checkpoint.activated.connect(_on_checkpoint_activated)
    add_child(boss_checkpoint)
    boss = HollowBishop.new()
    boss.name = "HollowBishop"
    boss.position = Vector3(32.0 + o, 0.0, -22.0)
    # While it stalks the approach it follows the player across this span.
    boss.engage_min_x = APPROACH_START_X + o + 0.4  # never reaches back into the rooms
    boss.min_x = APPROACH_START_X + o + 6.0
    boss.max_x = BOSS_ARENA_START_X + o - 2.0
    add_child(boss)
    boss.defeated.connect(_on_boss_defeated)
    boss.phase_changed.connect(_on_boss_audio_phase)
    boss.attack_started.connect(_on_boss_audio_attack)
    boss.sunder_impact.connect(_on_sunder_impact)

    # Reality Fracture: the optional free-movement chapel, off the main play plane.
    fracture = RealityFracture.new()
    fracture.name = "RealityFracture"
    add_child(fracture)


## The Pursuit Approach between the portcullis and the arena (x 18.2 → 58.2).
## Route: causeway → three collapsing slabs over a pit (1 m gaps) → landing → moving platform
## across a 10 m gap → arena threshold. Every jump fits the ~5.6 m running jump; falling
## respawns at the approach checkpoint and restores the slabs.
func _build_approach() -> void:
    var o: float = map_offset
    _make_solid("Approach causeway", Vector3(22.2 + o, -0.5, 0.0), Vector3(8.0, 1.0, 4.0), Color(0.19, 0.18, 0.22))
    approach_checkpoint = Checkpoint.create(APPROACH_CHECKPOINT_POSITION + Vector3(o, 0.0, 0.0))
    approach_checkpoint.name = "ApproachCheckpoint"
    approach_checkpoint.activated.connect(_on_checkpoint_activated)
    add_child(approach_checkpoint)
    for i in 3:
        var slab: CollapsingSlab = CollapsingSlab.create("Collapsing slab %d" % i, Vector3(28.45 + o + 3.5 * i, -0.5, 0.0), Vector3(2.5, 1.0, 4.0))
        slab.collapse_delay = 0.5  # keep moving
        add_child(slab)
        collapsing_slabs.append(slab)
    _make_solid("Approach landing", Vector3(40.7 + o, -0.5, 0.0), Vector3(6.0, 1.0, 4.0), Color(0.18, 0.17, 0.21))
    ferry = MovingPlatform.create("Bone ferry", Vector3(45.25 + o, -0.3, 0.0), Vector3(52.15 + o, -0.3, 0.0), Vector3(3.0, 0.6, 4.0))
    ferry.travel_time = 2.1
    ferry.pause_time = 0.6
    add_child(ferry)
    _make_solid("Arena threshold", Vector3(55.95 + o, -0.5, 0.0), Vector3(4.5, 1.0, 4.0), Color(0.19, 0.17, 0.2))
    # Hazards on the run to the cathedral: spikes and a swinging blade on the approach causeway,
    # spikes on the threshold right off the ferry.
    _add_trap(SpikeTrap.create("Spike trap: approach", 22.8 + o, 0.0, 2.0, 0.9))
    _add_trap(PendulumBlade.create("Pendulum blade", Vector3(25.3 + o, 5.9, 0.0), 5.0, 0.0))
    _add_trap(SpikeTrap.create("Spike trap: threshold", 55.6 + o, 0.0, 1.6, 1.3))


## Builds the run's shuffled rooms (LevelLayout) from x = APPROACH_START_X onward and shifts the
## approach and arena after them by their total width.
func _build_sections() -> void:
    var x: float = APPROACH_START_X
    var run_seed: int = RunState.seed_value if RunState.active else 4242
    for script: Script in LevelLayout.plan(run_seed):
        var section: LevelSection = script.new() as LevelSection
        add_child(section)
        section.build(x)
        sections.append(section)
        _wire_course(section)
        section.checkpoint.activated.connect(_on_checkpoint_activated)
        x += section.width
    map_offset = x - APPROACH_START_X


## Hooks a built room (or the opening's practice grounds) into the level's rules: altars,
## ambushes, hazards reset on a fall, crumbling slabs, loose Bone Shards.
func _wire_course(section: LevelSection) -> void:
    altars.append_array(section.altars)
    for ambush: Ambush in section.ambushes:
        ambush.started.connect(_on_ambush_started)
        ambush.cleared.connect(_on_ambush_cleared)
        ambushes.append(ambush)
    traps.append_array(section.traps)
    collapsing_slabs.append_array(section.slabs)
    for pickup: ShardPickup in section.pickups:
        pickup.collected.connect(add_shards)


## 3D run → side view at the Pursuit Approach (until phase 4 rebuilds the Bishop in 3D): the
## player locks back to the play plane, the side camera takes over, a gate closes behind (the
## 3D rooms' zig-zag ledges are off the z = 0 line) and new enemies spawn plane-locked.
func enter_side_view() -> void:
    if cam3d == null:
        return
    for p: CharacterBody3D in players:
        p.set("in_3d_mode", false)
        p.set("view_camera", null)
        p.set("lock_target", null)
        p.call("teleport_to", Vector3(p.global_position.x, p.global_position.y, 0.0))
    cam3d.queue_free()
    cam3d = null
    targeting.camera = camera  # card aim follows the view
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    camera.current = true
    EnemyFactory.full_3d = false
    _snap_camera()
    _rear_gate = StaticBody3D.new()
    _rear_gate.name = "Cathedral rear gate"
    _rear_gate.position = Vector3(APPROACH_START_X + map_offset - 0.4, 3.0, 0.0)
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(0.6, 8.0, Lane.depth())
    shape.shape = box
    _rear_gate.add_child(shape)
    add_child(_rear_gate)
    _make_visual("Rear gate bars", Vector3.ZERO, box.size, Color(0.3, 0.28, 0.32), _rear_gate)
    _flash("The cathedral's causeway: the Bishop waits beyond (side view until the 3D Bishop arrives).", 4.0)


## The room the player is in ("" in the opening and the Bishop's approach).
func current_section() -> LevelSection:
    var px: float = player.global_position.x
    for section: LevelSection in sections:
        if px >= section.origin_x and px < section.origin_x + section.width:
            return section
    return null


func _add_trap(trap: Node3D) -> void:
    add_child(trap)
    traps.append(trap)


func _make_solid(label: String, center: Vector3, size: Vector3, color: Color) -> void:
    if full_3d and size.z >= 3.5:
        size.z = Lane.DEPTH_3D  # causeways become halls
    var block: StaticBody3D = StaticBody3D.new()
    block.name = label
    block.position = center
    var collision: CollisionShape3D = CollisionShape3D.new()
    var box_shape: BoxShape3D = BoxShape3D.new()
    box_shape.size = size
    collision.shape = box_shape
    block.add_child(collision)
    _make_visual(label + " appearance", Vector3.ZERO, size, color, block)
    add_child(block)


func _make_visual(label: String, center: Vector3, size: Vector3, color: Color, parent: Node3D = null) -> void:
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    mesh_node.name = label
    mesh_node.position = center
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    var kind: StringName = GothicMaterials.kind_for_label(label)  # stone / masonry look (DEC-054)
    if kind != &"":
        mesh_node.material_override = GothicMaterials.block(kind)
    else:
        var material: StandardMaterial3D = StandardMaterial3D.new()
        material.albedo_color = color
        material.metallic = 0.1
        material.roughness = 0.9
        mesh_node.material_override = material
    if parent == null:
        parent = self
    parent.add_child(mesh_node)
