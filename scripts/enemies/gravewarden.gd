class_name Gravewarden
extends CodeEnemy
## The Gravewarden: Act I's elite mini-boss, a huge armoured knight in a sealed hall.
## Moves (all telegraphed, chosen in a fixed rotation):
##   Crypt Charge: glows and paints a red lane (`charge_windup` s), then charges across the hall
##     (1 damage, big knockback). Dodge it and it slams into the wall: DAZED for `daze_time` s.
##   Grave Quake: raises its maul (`quake_windup` s), slams: a spike burst at its feet, then spike
##     waves run along the floor both ways — jump them.
##   Raise Guard: calls up to two Bone Crawlers.
## Below half health it ENRAGES: faster wind-ups, shorter rests, and its charge comes twice.
## Drops 40 Bone Shards (its hall then raises a relic reliquary).

signal enraged_now

@export var walk_speed: float = 1.8
@export var charge_windup: float = 0.8
@export var charge_speed: float = 13.0
@export var charge_max_time: float = 1.4
@export var daze_time: float = 1.4
@export var quake_windup: float = 0.9
@export var summon_windup: float = 0.7
@export var rest_time: float = 1.2

var charge_hitbox: Hitbox
var enraged: bool = false
var moves: Array[StringName] = []  # every move started, for tests
var _rotation: Array[StringName] = [&"charge", &"quake", &"charge", &"summon"]
var _rotation_index: int = 0
var _charges_left: int = 0
var _lane: MeshInstance3D
var _quake_steps: int = 0


func _init() -> void:
    max_health = 30
    poise_max = 6
    shard_value = 40
    _base_color = Color(0.42, 0.4, 0.38)


func _ready() -> void:
    super._ready()
    add_to_group(&"elite")


func _build_body() -> void:
    _add_collider(Vector3(1.4, 2.6, 0.9), 0.4)
    _add_hurt_shape(Vector3(1.5, 2.7, 1.1), 0.4)
    _add_mesh(Vector3(1.4, 2.5, 0.9), Vector3(0.0, 0.4, 0.0), null, "Armour")
    var iron: StandardMaterial3D = StandardMaterial3D.new()
    iron.albedo_color = Color(0.25, 0.23, 0.24)
    iron.metallic = 0.7
    _add_mesh(Vector3(0.35, 1.8, 0.35), Vector3(0.95, 0.6, 0.0), iron, "Maul handle")
    _add_mesh(Vector3(0.9, 0.6, 0.7), Vector3(0.95, 1.5, 0.0), iron, "Maul head")
    _add_mesh(Vector3(0.7, 0.5, 0.7), Vector3(0.0, 1.95, 0.0), iron, "Helm")
    charge_hitbox = _make_hitbox(Vector3(1.8, 2.4, 1.4), Vector3(0.0, 0.4, 0.0), 1, &"warden_charge", 9.0)
    _lane = MeshInstance3D.new()
    var lane_mesh: BoxMesh = BoxMesh.new()
    lane_mesh.size = Vector3(12.0, 0.05, 1.6)
    _lane.mesh = lane_mesh
    _lane.material_override = BishopHand._warning_material()
    _lane.top_level = true
    _lane.visible = false
    add_child(_lane)


func phase_title() -> String:
    return "ENRAGED" if enraged else ""


func _tick(delta: float, target: Node3D) -> void:
    var speed_scale: float = 1.3 if enraged else 1.0
    match state:
        &"idle":
            velocity.x = 0.0
            if not ai_enabled or target == null:
                return
            var dx: float = target.global_position.x - global_position.x
            if absf(dx) > 0.05:
                facing = signf(dx)
            if absf(dx) > 2.5:
                velocity.x = facing * walk_speed * speed_scale
            if _t >= rest_time / speed_scale and _silenced_left <= 0.0 and is_on_floor():
                start_move(_rotation[_rotation_index % _rotation.size()])
                _rotation_index += 1
        &"charge_windup":
            velocity.x = 0.0
            _lane.visible = true
            _lane.global_position = global_position + Vector3(facing * 6.5, -0.85, 0.0)
            if _t >= charge_windup / speed_scale:
                _lane.visible = false
                charge_hitbox.activate()
                _ghost_player(true)  # the charge runs through you (after hitting you)
                Audio.sfx(&"soldier_lunge", 0.0, 3.0)
                set_state(&"charging")
        &"charging":
            velocity.x = facing * charge_speed * speed_scale
            var blocked: bool = _hit_static_wall() or (global_position.x <= min_x + 0.4 and facing < 0.0) or (global_position.x >= max_x - 0.4 and facing > 0.0)
            if blocked and _t > 0.1:
                charge_hitbox.deactivate()
                velocity.x = -facing * 3.0
                Audio.sfx(&"bishop_slam", 0.05, -6.0)
                get_tree().call_group(&"camera_shaker", &"add_trauma", 0.4)
                _stun_left = daze_time
                set_state(&"stagger")  # dazed against the wall: the punish window
            elif _t >= charge_max_time:
                charge_hitbox.deactivate()
                _after_move()
        &"quake_windup":
            velocity.x = 0.0
            if _t >= quake_windup / speed_scale:
                _quake()
                set_state(&"quake")
        &"quake":
            velocity.x = 0.0
            if _t >= 0.9:
                _after_move()
        &"summon_windup":
            velocity.x = 0.0
            if _t >= summon_windup / speed_scale:
                _summon()
                _after_move()


func _ghost_player(on: bool) -> void:
    var player: PhysicsBody3D = get_tree().get_first_node_in_group(&"player") as PhysicsBody3D
    if player == null:
        return
    if on:
        add_collision_exception_with(player)
    else:
        remove_collision_exception_with(player)


func set_state(next: StringName) -> void:
    if state == &"charging" and next != &"charging":
        _ghost_player(false)
    super.set_state(next)


## Only real walls daze it (bodies such as the player do not count).
func _hit_static_wall() -> bool:
    for i in get_slide_collision_count():
        var hit: KinematicCollision3D = get_slide_collision(i)
        if hit.get_collider() is StaticBody3D and hit.get_normal().x * facing < -0.5:
            return true
    return false


## Starts a move now (AI rotation, or tests/debug).
func start_move(move: StringName) -> void:
    moves.append(move)
    match move:
        &"charge":
            _charges_left = 1 if enraged else 0
            set_state(&"charge_windup")
        &"quake":
            set_state(&"quake_windup")
        &"summon":
            set_state(&"summon_windup")


func _after_move() -> void:
    if state == &"charging" and _charges_left > 0:
        _charges_left -= 1
        facing = -facing
        set_state(&"charge_windup")
        return
    set_state(&"idle")


func _quake() -> void:
    var feet: Vector3 = global_position + Vector3(0.0, -0.9, 0.0)
    get_parent().add_child(StrikeZone.create(feet, 1.6, 1.2, 0.05, 1, &"warden_quake", &"spike"))
    Audio.sfx(&"bishop_slam", 0.05)
    get_tree().call_group(&"camera_shaker", &"add_trauma", 0.5)
    # Spike waves both ways: low spikes (0.9 m) stepping outward — jump them.
    for side: float in [-1.0, 1.0]:
        for step in range(1, 9):
            var x: float = feet.x + side * (1.2 + step * 1.3)
            if x < min_x - 1.0 or x > max_x + 1.0:
                continue
            var wave: StrikeZone = StrikeZone.create(Vector3(x, feet.y, 0.0), 0.55, 0.9, 0.12 + step * 0.11, 1, &"warden_wave", &"wave")
            get_parent().add_child(wave)


func _summon() -> void:
    var alive: int = get_tree().get_nodes_in_group(&"warden_minion").filter(func(n: Node) -> bool: return not bool(n.call("is_dead"))).size()
    for side: float in [-1.0, 1.0]:
        if alive >= 2:
            break
        var crawler: Node3D = EnemyFactory.spawn(&"crawler", get_parent(), global_position.x + side * 2.5, min_x, max_x, global_position.y)
        crawler.add_to_group(&"warden_minion")
        alive += 1
    Audio.sfx(&"summon", 0.05)


func _on_hit(info: DamageInfo) -> void:
    super._on_hit(info)
    if not enraged and not _dead and health.current * 2 <= health.max_health:
        enraged = true
        _base_color = Color(0.6, 0.18, 0.12)
        enraged_now.emit()
        Audio.sfx(&"bishop_roar", 0.1, -4.0)


func _on_poise_break(info: DamageInfo) -> void:
    # Too heavy to be knocked around: a poise break only interrupts a wind-up.
    if state in [&"charge_windup", &"quake_windup", &"summon_windup"]:
        _lane.visible = false
        _stun_left = 0.8
        set_state(&"stagger")
    velocity.x = info.knockback.x * 0.2


func _on_silenced() -> void:
    if state in [&"charge_windup", &"quake_windup", &"summon_windup"]:
        _lane.visible = false
        set_state(&"idle")


func _on_died() -> void:
    charge_hitbox.deactivate()
    _lane.visible = false
    for minion: Node in get_tree().get_nodes_in_group(&"warden_minion"):
        if not bool(minion.call("is_dead")):
            (minion.get("health") as Health).apply_damage(99)
    super._on_died()


## Freed by a hall reset (player died mid-fight): take the summoned crawlers with it.
func _exit_tree() -> void:
    for minion: Node in get_tree().get_nodes_in_group(&"warden_minion"):
        minion.queue_free()


func _glow() -> Color:
    match state:
        &"charge_windup", &"quake_windup", &"summon_windup":
            return Color(1.0, 0.25, 0.05) * (0.5 + 0.5 * sin(_t * 18.0))
        &"stagger":
            return Color(0.9, 0.8, 0.2) * 0.5
    return Color(0.6, 0.05, 0.05) * 0.5 if enraged else Color.BLACK
