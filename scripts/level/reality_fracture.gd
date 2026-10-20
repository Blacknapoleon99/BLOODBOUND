class_name RealityFracture
extends Node3D
## A Reality Fracture: an optional free-movement 3D arena entered from a gate on the 2.5D path.
## The same player node (HP, blood energy, cards, attacks) crosses over; only the movement
## constraint and camera framing change.
##
## Flow: IDLE --enter()--> ENTERING (fade out, teleport, unlock X/Z, fade in) --> ACTIVE
##   ACTIVE: the guardian (an unlocked Plagued Soldier) fights on X/Z; the return portal is
##           sealed until it dies. Walking into the open portal exits.
##   EXITING (fade out, teleport back to the exact 2.5D spot the player entered from, re-lock
##           Z=0, fade in) --> CLEARED (guardian slain: full heal + blood reward, gate closes)
##                         --> IDLE    (player died inside: guardian reset, gate stays open)
## Input is frozen for the whole transition so nothing happens mid-teleport.

signal entered
signal exited(cleared: bool)
## Fired at the moment of the teleport, while the screen is black (camera snap point).
signal teleported(to_3d: bool)

enum State { IDLE, ENTERING, ACTIVE, EXITING, CLEARED }

const SOLDIER_SCENE: PackedScene = preload("res://scenes/enemies/plagued_soldier.tscn")

@export var center: Vector3 = Vector3(35.0, 0.0, 60.0)
@export var radius: float = 8.0
@export var fade_out_time: float = 0.25
@export var hold_time: float = 0.1
@export var fade_in_time: float = 0.3
@export var clear_blood_reward: float = 3.0

var state: State = State.IDLE
var guardian: PlaguedSoldier
var portal: Area3D
var spawn_point: Vector3
var return_point: Vector3
var fade: ColorRect
var portal_open: bool = false

var _player: CharacterBody3D
var _t: float = 0.0
var _teleported: bool = false
var _exit_cleared: bool = false
var _portal_material: StandardMaterial3D


func _ready() -> void:
    spawn_point = center + Vector3(-1.0, 2.0, 0.0)
    _build_chapel()
    _build_guardian()
    _build_portal()
    var layer: CanvasLayer = CanvasLayer.new()
    layer.layer = 5
    add_child(layer)
    fade = ColorRect.new()
    fade.name = "FractureFade"
    fade.color = Color(0.02, 0.0, 0.01, 0.0)
    fade.set_anchors_preset(Control.PRESET_FULL_RECT)
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(fade)


func is_transitioning() -> bool:
    return state == State.ENTERING or state == State.EXITING


func can_enter() -> bool:
    return state == State.IDLE


func enter(player: CharacterBody3D) -> bool:
    if not can_enter():
        return false
    _player = player
    return_point = Vector3(player.global_position.x, player.global_position.y + 0.1, 0.0)
    _begin(State.ENTERING)
    return true


## Player died inside: leave without the reward and reset the guardian for a retry.
func fail() -> void:
    if state != State.ACTIVE:
        return
    _exit_cleared = false
    _begin(State.EXITING)


func _begin(next: State) -> void:
    state = next
    _t = 0.0
    _teleported = false
    _player.set("game_frozen", true)


func _process(delta: float) -> void:
    if not is_transitioning():
        return
    _t += delta
    var to_3d: bool = state == State.ENTERING
    if _t < fade_out_time:
        fade.color.a = _t / fade_out_time
    elif not _teleported:
        fade.color.a = 1.0
        _teleported = true
        _swap_sides(to_3d)
    elif _t < fade_out_time + hold_time:
        fade.color.a = 1.0
    elif _t < fade_out_time + hold_time + fade_in_time:
        fade.color.a = 1.0 - (_t - fade_out_time - hold_time) / fade_in_time
    else:
        fade.color.a = 0.0
        _player.set("game_frozen", false)
        if to_3d:
            state = State.ACTIVE
            entered.emit()
        else:
            state = State.CLEARED if _exit_cleared else State.IDLE
            exited.emit(_exit_cleared)


func _swap_sides(to_3d: bool) -> void:
    if to_3d:
        _player.set("in_3d_mode", true)
        _player.call("teleport_to", spawn_point)
    else:
        _player.set("in_3d_mode", false)
        _player.call("teleport_to", return_point)
        if _exit_cleared:
            (_player.get("health") as Health).restore_full()
            (_player.get_node("BloodEnergy") as BloodEnergy).add(clear_blood_reward)
        else:
            (_player.get("health") as Health).restore_full()
            guardian.revive_at_home()
            _set_portal(false)
    teleported.emit(to_3d)


func _on_guardian_defeated() -> void:
    _set_portal(true)


func _on_portal_body_entered(body: Node3D) -> void:
    if state == State.ACTIVE and portal_open and body == _player:
        _exit_cleared = true
        _begin(State.EXITING)


func _set_portal(open: bool) -> void:
    portal_open = open
    portal.set_deferred(&"monitoring", open)
    _portal_material.albedo_color = Color(0.95, 0.55, 0.15, 0.85) if open else Color(0.25, 0.2, 0.22, 0.6)
    _portal_material.emission = Color(1.0, 0.5, 0.1) * 2.0 if open else Color(0.05, 0.03, 0.03)


# --- Construction ---------------------------------------------------------------

func _build_chapel() -> void:
    var floor_body: StaticBody3D = StaticBody3D.new()
    floor_body.name = "ChapelFloor"
    floor_body.position = center + Vector3(0.0, -0.5, 0.0)
    var shape: CollisionShape3D = CollisionShape3D.new()
    var cylinder: CylinderShape3D = CylinderShape3D.new()
    cylinder.radius = radius
    cylinder.height = 1.0
    shape.shape = cylinder
    floor_body.add_child(shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = 1.0
    mesh.radial_segments = 24
    mesh_node.mesh = mesh
    mesh_node.material_override = _material(Color(0.2, 0.17, 0.25))
    floor_body.add_child(mesh_node)
    add_child(floor_body)
    # Broken pillar ring: solid cover that also frames the circle. The side nearest the
    # camera (+Z) is left open so pillars never hide the fight.
    for i in 7:
        var angle: float = PI * 0.85 + PI * 1.3 * float(i) / 6.0  # 153°..387°: back half + flanks
        var height: float = 3.2 if i % 2 == 0 else 1.8
        var at: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * (radius - 1.2) + Vector3(0.0, height * 0.5, 0.0)
        _add_solid("Chapel pillar %d" % i, at, Vector3(1.1, height, 1.1), Color(0.33, 0.27, 0.36))
    # Veil: hides the main level (which lies toward -Z) so the fracture reads as its own pocket.
    # The side-view camera always looks toward -Z from z <= 25, so it never sees this.
    var veil: MeshInstance3D = MeshInstance3D.new()
    veil.name = "FractureVeil"
    var plane: BoxMesh = BoxMesh.new()
    plane.size = Vector3(90.0, 60.0, 0.2)
    veil.mesh = plane
    var veil_material: StandardMaterial3D = StandardMaterial3D.new()
    veil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    veil_material.albedo_color = Color(0.07, 0.015, 0.03)
    veil.material_override = veil_material
    veil.position = center + Vector3(0.0, 0.0, -(radius + 6.0))
    add_child(veil)


func _build_guardian() -> void:
    guardian = SOLDIER_SCENE.instantiate() as PlaguedSoldier
    guardian.name = "FractureGuardian"
    guardian.plane_locked = false
    guardian.leash_radius = radius - 2.0
    guardian.patrol_min_x = center.x + 1.0
    guardian.patrol_max_x = center.x + 4.0
    guardian.aggro_range = 7.0
    guardian.position = center + Vector3(3.0, 1.0, -2.0)
    guardian.defeated.connect(_on_guardian_defeated)
    add_child(guardian)


func _build_portal() -> void:
    portal = Area3D.new()
    portal.name = "ReturnPortal"
    portal.position = center + Vector3(-4.0, 1.4, 4.0)
    portal.monitoring = false
    portal.monitorable = false
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(1.6, 2.6, 1.6)
    shape.shape = box
    portal.add_child(shape)
    var ring: MeshInstance3D = MeshInstance3D.new()
    ring.name = "PortalRing"
    var torus: TorusMesh = TorusMesh.new()
    torus.inner_radius = 0.9
    torus.outer_radius = 1.2
    ring.mesh = torus
    ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
    _portal_material = _material(Color(0.25, 0.2, 0.22, 0.6))
    _portal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _portal_material.emission_enabled = true
    ring.material_override = _portal_material
    portal.add_child(ring)
    portal.body_entered.connect(_on_portal_body_entered)
    add_child(portal)
    _set_portal(false)


func _add_solid(label: String, at: Vector3, size: Vector3, color: Color) -> void:
    var body: StaticBody3D = StaticBody3D.new()
    body.name = label
    body.position = at
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.material_override = _material(color)
    body.add_child(mesh_node)
    add_child(body)


static func _material(color: Color) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    return material
