class_name PendulumBlade
extends Node3D
## A great blade swinging across the causeway from a pivot above. It sweeps through waist
## height at the bottom of each swing (1 damage, knocked along the swing); pass under it while
## it is high on the far side, or jump over it. `PendulumBlade.enabled = false` parks it high.

static var enabled: bool = true

var arm_length: float = 5.0
var max_angle: float = 1.05  # radians either side of straight down
var period: float = 2.2  # seconds for a full back-and-forth
var phase_offset: float = 0.0
## Blade width across the swing (m); -1 = the default (the hall's depth in 3D, thin in the side view).
var blade_span: float = -1.0
var hitbox: Hitbox
var _t: float = 0.0
var _arm: Node3D


static func create(label: String, pivot: Vector3, length: float, offset: float = 0.0, span: float = -1.0) -> PendulumBlade:
    var blade: PendulumBlade = PendulumBlade.new()
    blade.blade_span = span
    blade.name = label
    blade.add_to_group(&"pendulum")
    blade.position = pivot
    blade.arm_length = length
    blade.phase_offset = offset
    blade._t = offset
    blade._build()
    return blade


func angle() -> float:
    return _arm.rotation.z


## World position of the blade's centre.
func blade_position() -> Vector3:
    return _arm.to_global(Vector3(0.0, -arm_length, 0.0))


func reset() -> void:
    _t = phase_offset


func _build() -> void:
    var iron: StandardMaterial3D = GothicMaterials.standard("rust_iron", Color(0.6, 0.5, 0.46), 0.6, false)  # DEC-054
    _arm = Node3D.new()
    add_child(_arm)
    var rod: MeshInstance3D = MeshInstance3D.new()
    rod.name = "Arm"
    # Modelled arm (pivot hub, flanged bar, clamp) stretched to the arm length (DEC-057).
    var arm_mesh: ArrayMesh = GothicProps.stretched("pendulum_arm", 1, -1.0, 0.15, -arm_length, 0.15, 0.25, {&"iron": iron})
    if arm_mesh != null:
        rod.mesh = arm_mesh
    else:
        var rod_mesh: BoxMesh = BoxMesh.new()
        rod_mesh.size = Vector3(0.12, arm_length, 0.12)
        rod.mesh = rod_mesh
        rod.material_override = iron
        rod.position.y = -arm_length * 0.5
    _arm.add_child(rod)
    var span: float = Lane.depth() - 1.0 if Lane.full_3d else 0.15  # 3D: no walking round it
    if blade_span > 0.0:
        span = blade_span  # open 3D courses size each blade to the walkway it guards
    var edge: StandardMaterial3D = GothicMaterials.standard("rust_iron", Color(1.0, 0.95, 0.92), 0.9, false)
    edge.emission_enabled = true
    edge.emission = Color(0.5, 0.05, 0.05) * 0.4
    var crescent: ArrayMesh = GothicProps.mesh("pendulum_crescent", {&"blade": edge, &"iron": iron})
    if crescent != null:
        # A row of crescent blades on an iron spine across the walkway (one in the side view).
        var blades: Node3D = Node3D.new()
        blades.name = "Blade"
        blades.position.y = -arm_length + 0.1
        _arm.add_child(blades)
        var n: int = 1 if span < 1.0 else maxi(2, ceili(span / 1.15))
        for k in n:
            var b: MeshInstance3D = MeshInstance3D.new()
            b.mesh = crescent
            b.position.z = 0.0 if n == 1 else lerpf(-span * 0.5 + 0.12, span * 0.5 - 0.12, float(k) / (n - 1))
            blades.add_child(b)
        if n > 1:
            var spine: MeshInstance3D = MeshInstance3D.new()
            spine.name = "Spine"
            spine.mesh = GothicProps.stretched("pendulum_spine", 2, -0.53, 0.53, -span * 0.5, span * 0.5, 0.08, {&"iron": iron})
            blades.add_child(spine)
    else:
        var blade: MeshInstance3D = MeshInstance3D.new()
        var blade_mesh: BoxMesh = BoxMesh.new()
        blade_mesh.size = Vector3(1.6, 0.5, span)
        blade.mesh = blade_mesh
        blade.material_override = edge
        blade.position.y = -arm_length
        _arm.add_child(blade)
    hitbox = Hitbox.new()
    hitbox.team = &"enemy"
    hitbox.damage = 1
    hitbox.category = &"hazard"
    hitbox.knockback = 7.0
    hitbox.knockback_up = 3.0
    hitbox.hitstun = 0.35
    hitbox.attack_id = &"pendulum"
    hitbox.rehit_interval = 1.0
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(1.5, 0.5, maxf(1.6, span))
    shape.shape = box
    shape.position.y = -arm_length
    hitbox.add_child(shape)
    _arm.add_child(hitbox)


func _physics_process(delta: float) -> void:
    if not enabled:
        _arm.rotation.z = max_angle  # parked high to one side
        hitbox.deactivate()
        return
    _t += delta
    _arm.rotation.z = max_angle * sin(TAU * _t / period)
    # Only the low part of the swing can reach the causeway.
    var low: bool = absf(_arm.rotation.z) < max_angle * 0.6
    if low and not hitbox.is_active():
        hitbox.activate()
    elif not low and hitbox.is_active():
        hitbox.deactivate()
