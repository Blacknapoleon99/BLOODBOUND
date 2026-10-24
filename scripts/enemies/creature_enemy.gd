class_name CreatureEnemy
extends CodeEnemy
## Base for the five full-3D creatures (DEC-064): Flayed Stalker, Stitched Brute, Limb Spider,
## Hollow Mourner and Lantern Wight. Adds to CodeEnemy (health, poise, roaming, hitboxes):
##   - a CreatureRig puppet (modelled GLB) under `_visual`, feet at FEET below the origin,
##     model front (+Z) turned to the visual's front (+X); a box stand-in if the GLB is missing;
##   - `_animate(delta)` / `_animate_death(delta)` hooks run every physics frame after the
##     facing is updated, plus a CreatureGait when the creature has legs;
##   - jerky `twitch` offsets (snap to a random pose, hold, snap again);
##   - hit flash / telegraph glow drawn as a rim overlay on the model (from `_glow()`);
##   - a death that plays the creature's own collapse instead of CodeEnemy's tip-over;
##   - `hitbox_ahead`: keeps a melee hitbox in front of the creature as it turns.
## AI stays in each subclass's `_tick`, written with the CodeEnemy helpers (roam_idle, engage,
## face, move_dir, chase_dir) so it runs in full 3D and, in a basic way, in the side view.

## Feet height below the body origin (EnemyFactory spawns ~1 m above the floor).
const FEET: float = -1.0

var rig: CreatureRig
var gait: CreatureGait
var anim_t: float = 0.0
var death_t: float = -1.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _twitches: Dictionary = {}


func _build_rig(asset: String, fallback_size: Vector3) -> void:
    rng.seed = hash([asset, get_instance_id()])
    rig = CreatureRig.create(asset)
    if rig == null:
        push_warning("%s: %s.glb missing, using a stand-in" % [name, asset])
        _add_mesh(fallback_size, Vector3(0.0, FEET + fallback_size.y * 0.5, 0.0), null, "Body")
        return
    _visual.add_child(rig)
    rig.position = Vector3(0.0, FEET, 0.0)
    rig.rotation.y = PI * 0.5  # model front +Z -> the visual's front +X


## The rig's model root (null without a rig).
func model() -> Node3D:
    return rig.model if rig != null else null


func _update_look() -> void:
    super._update_look()
    var delta: float = get_physics_process_delta_time()
    if rig == null:
        return
    if _dead:
        death_t += delta
        rig.overlay(Color.BLACK, 0.0)
        _animate_death(delta)
        return
    anim_t += delta
    _animate(delta)
    _update_overlay()


## Override: pose the rig for this frame (alive).
func _animate(_delta: float) -> void:
    pass


## Override: the collapse (death_t counts up from 0).
func _animate_death(_delta: float) -> void:
    pass


func _update_overlay() -> void:
    if _flash_left > 0.0:
        rig.overlay(Color(1.0, 0.92, 0.85), 1.4 * (_flash_left / 0.12), 1.2, 0.6)
        return
    if _silenced_left > 0.0:
        rig.overlay(Color(0.3, 0.4, 1.0), 0.7, 2.0, 0.1)
        return
    var g: Color = _glow()
    var k: float = maxf(g.r, maxf(g.g, g.b))
    if k > 0.01:
        rig.overlay(Color(g.r / k, g.g / k, g.b / k), k * 1.3, 2.2, 0.08)
    else:
        rig.overlay(Color.BLACK, 0.0)


## Smoothed random snaps for a "key" (a part's twitch), in ±amount, a new pose every
## 0.08..hold s; returns the current offset. `rate` 0 relaxes the twitch to zero.
func twitch(key: StringName, amount: Vector3, hold: float, delta: float, rate: float = 1.0) -> Vector3:
    var st: Array = _twitches.get(key, [Vector3.ZERO, Vector3.ZERO, 0.0])
    var cur: Vector3 = st[0]
    var to: Vector3 = st[1]
    var left: float = float(st[2]) - delta * rate
    if left <= 0.0:
        left = rng.randf_range(0.08, maxf(0.1, hold))
        to = Vector3.ZERO if rng.randf() < 0.35 else Vector3(rng.randf_range(-1.0, 1.0) * amount.x, rng.randf_range(-1.0, 1.0) * amount.y, rng.randf_range(-1.0, 1.0) * amount.z)
    if rate <= 0.0:
        to = Vector3.ZERO
    cur = cur.lerp(to, 1.0 - exp(-delta * 38.0))  # a snap, not a drift
    _twitches[key] = [cur, to, left]
    return cur


## Keeps `hb` `reach` m ahead of the creature at height `y`, turned with it.
func hitbox_ahead(hb: Hitbox, reach: float, y: float) -> void:
    var fwd: Vector3 = heading if not plane_locked else Vector3(facing, 0.0, 0.0)
    hb.position = Vector3(fwd.x * reach, y, fwd.z * reach)
    hb.rotation.y = atan2(-fwd.z, fwd.x)


## World height of the floor the creature stands on (its feet).
func feet_y() -> float:
    return global_position.y + FEET


## Planar speed (m/s).
func speed() -> float:
    return Vector2(velocity.x, velocity.z).length()


## A ground warning shape (the shared red telegraph material), top-level, hidden.
func _warning(size: Vector3, round_disc: bool = false) -> MeshInstance3D:
    var mi: MeshInstance3D = MeshInstance3D.new()
    if round_disc:
        var disc: CylinderMesh = CylinderMesh.new()
        disc.top_radius = size.x
        disc.bottom_radius = size.x
        disc.height = 0.04
        disc.radial_segments = 48
        mi.mesh = disc
    else:
        var bm: BoxMesh = BoxMesh.new()
        bm.size = size
        mi.mesh = bm
    mi.material_override = BishopHand._warning_material()
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.top_level = true
    mi.visible = false
    add_child(mi)
    return mi


## Shows `marker` on the floor `ahead` m in front (0 = centred), turned with the creature.
func _place_marker(marker: MeshInstance3D, ahead: float) -> void:
    var fwd: Vector3 = heading if not plane_locked else Vector3(facing, 0.0, 0.0)
    marker.visible = true
    marker.global_position = Vector3(global_position.x, feet_y() + 0.04, global_position.z) + fwd * ahead
    marker.rotation = Vector3(0.0, atan2(-fwd.z, fwd.x), 0.0)


func _on_died() -> void:
    _dead = true
    set_state(&"dead")
    hurtbox.set_enabled(false)
    set_deferred(&"collision_layer", 0)
    death_t = 0.0
    if gait != null:
        gait.enabled = false
    _on_death_fx()
    if rig == null:
        var tween: Tween = create_tween()
        tween.tween_property(_visual, "rotation:z", (-facing if plane_locked else -1.0) * PI * 0.5, 0.35)
        tween.tween_property(_visual, "position:y", -0.6, 0.5)
    defeated.emit()


## Override: extra death effects (embers, a dropped lantern, a shriek).
func _on_death_fx() -> void:
    pass
