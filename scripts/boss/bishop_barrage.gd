class_name BishopBarrage
extends Node3D
## Two Bishop attacks built from StrikeZones (an actor, like CenserSweep / RequiemBeam):
##   Bone Rain (&"bone_rain"): five bones fall on marked spots around the player, then a second,
##     offset wave lands in the gaps — read the rings and step between waves.
##   Marrow Geyser (&"marrow_geyser"): three spikes erupt one after another under wherever the
##     player is standing when each is marked — keep moving.

const RAIN_OFFSETS: Array[float] = [-6.0, -3.0, 0.0, 3.0, 6.0]
const RAIN_WAVE_GAP: float = 0.55
const GEYSER_COUNT: int = 3
const GEYSER_GAP: float = 0.5

var mode: StringName = &"bone_rain"
var center_x: float = 0.0
var min_x: float = -INF
var max_x: float = INF
var zone_delay: float = 0.85
var done: bool = false
var zones: Array[StrikeZone] = []
var _t: float = 0.0
var _spawned: int = 0


static func create(attack: StringName, x: float, lo: float, hi: float) -> BishopBarrage:
    var barrage: BishopBarrage = BishopBarrage.new()
    barrage.name = "BoneRain" if attack == &"bone_rain" else "MarrowGeyser"
    barrage.add_to_group(&"boss_barrage")
    barrage.mode = attack
    barrage.center_x = x
    barrage.min_x = lo
    barrage.max_x = hi
    barrage.zone_delay = 0.85 if attack == &"bone_rain" else 0.6
    return barrage


## True until the first strike lands (silence can still cancel it).
func is_telegraphing() -> bool:
    for zone: StrikeZone in zones:
        if is_instance_valid(zone) and zone.landed:
            return false
    return not done


func cancel() -> void:
    for zone: StrikeZone in zones:
        if is_instance_valid(zone):
            zone.cancel()
    zones.clear()
    done = true
    queue_free()


func _physics_process(delta: float) -> void:
    if done:
        return
    _t += delta
    if mode == &"bone_rain":
        if _spawned == 0:
            _rain_wave(0.0)
        elif _spawned == 1 and _t >= RAIN_WAVE_GAP:
            _rain_wave(1.5)
        var waves_done: bool = _spawned >= 2
        if waves_done and _all_zones_done():
            _finish()
    else:
        if _spawned < GEYSER_COUNT and _t >= _spawned * GEYSER_GAP:
            var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
            var x: float = player.global_position.x if player != null else center_x
            _add_zone(x, 0.75, 2.6, &"spike", &"bishop_geyser")
            _spawned += 1
        if _spawned >= GEYSER_COUNT and _all_zones_done():
            _finish()


func _rain_wave(shift: float) -> void:
    for offset: float in RAIN_OFFSETS:
        var x: float = center_x + offset + shift
        if x >= min_x and x <= max_x:
            _add_zone(x, 0.8, 1.8, &"bone", &"bishop_bone_rain")
    _spawned += 1


func _add_zone(x: float, radius: float, height: float, style: StringName, id: StringName) -> void:
    var zone: StrikeZone = StrikeZone.create(Vector3(x, 0.0, 0.0), radius, height, zone_delay, 1, id, style)
    zones.append(zone)
    add_child(zone)


func _all_zones_done() -> bool:
    for zone: StrikeZone in zones:
        if is_instance_valid(zone) and not zone.done:
            return false
    return true


func _finish() -> void:
    done = true
    queue_free()
