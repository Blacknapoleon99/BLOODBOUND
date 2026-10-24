class_name CreatureRig
extends Node3D
## A creature model as a puppet of rigid parts (DEC-064). The GLB (tools/blender/
## build_creatures.py) is a node hierarchy whose part origins sit on the joints, so turning a
## part's node bends the body there. This keeps every part's rest transform and offers:
##   turn(part, euler)       local rotation about the joint, on top of the rest pose
##   blend(part, euler, w)   slerps whatever the part has now toward that pose by w
##   shift(part, offset)     moves the joint (in its parent's space) from rest
##   aim(part, rest_dir, v)  turns the part so its rest-local `rest_dir` points along world `v`
##   ik(upper, lower, end_local, target, pole)  analytic 2-bone IK onto a world point
##   level(part)             gives a part its rest orientation relative to the rig (flat feet)
##   overlay(color, k)       an additive rim/flash pass over every mesh (hit flash, telegraphs)
## Roles on the imported surfaces become CreatureMaterials; glow roles are per-rig copies
## (`glows[role]`) so scripts can flare them. `create` returns null when the GLB is missing.

const DIR: String = "res://assets/models/enemies/"
const OVERLAY_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 0.0;
uniform float rim_power = 2.0;
uniform float base = 0.25;
void fragment() {
    float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
    ALBEDO = tint.rgb * strength * (base + rim * 1.6);
}
"""

static var _overlay_shader: Shader

var parts: Dictionary = {}       # StringName -> Node3D
var rest: Dictionary = {}        # StringName -> Transform3D (local)
var rest_root: Dictionary = {}   # StringName -> Transform3D relative to the model root
var meshes: Array[MeshInstance3D] = []
var glows: Dictionary = {}       # role -> StandardMaterial3D (this rig's own copy)
var model: Node3D
var _overlay: ShaderMaterial
var _overlay_on: bool = false


static func create(asset: String) -> CreatureRig:
    var path: String = DIR + asset + ".glb"
    if not ResourceLoader.exists(path):
        return null
    var scene: PackedScene = load(path) as PackedScene
    if scene == null:
        return null
    var rig: CreatureRig = CreatureRig.new()
    rig.name = "CreatureRig"
    rig.model = scene.instantiate() as Node3D
    rig.add_child(rig.model)
    rig._index(rig.model, Transform3D.IDENTITY)
    return rig


func _index(node: Node, to_root: Transform3D) -> void:
    for child: Node in node.get_children():
        if not (child is Node3D):
            continue
        var n3: Node3D = child as Node3D
        var key: StringName = StringName(n3.name)
        parts[key] = n3
        rest[key] = n3.transform
        var tr: Transform3D = to_root * n3.transform
        rest_root[key] = tr
        if n3 is MeshInstance3D:
            var mi: MeshInstance3D = n3 as MeshInstance3D
            meshes.append(mi)
            for i in mi.mesh.get_surface_count():
                var role: StringName = GothicProps.role_of(mi.mesh, i)
                var m: Material
                if role in CreatureMaterials.INSTANCED:
                    if not glows.has(role):
                        glows[role] = CreatureMaterials.instanced(role)
                    m = glows[role]
                else:
                    m = CreatureMaterials.material(role)
                mi.set_surface_override_material(i, m)
            if mi.mesh.get_surface_count() == 1 and GothicProps.role_of(mi.mesh, 0) in [&"glow", &"glow_pale", &"flame"]:
                mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _index(n3, tr)


func has(part: StringName) -> bool:
    return parts.has(part)


func p(part: StringName) -> Node3D:
    return parts.get(part) as Node3D


## Back to the authored pose (rotation, position and scale of every part).
func reset() -> void:
    for key: StringName in parts:
        (parts[key] as Node3D).transform = rest[key]


func turn(part: StringName, euler: Vector3) -> void:
    var n: Node3D = parts.get(part)
    if n != null:
        n.basis = (rest[part] as Transform3D).basis * Basis.from_euler(euler)


func blend(part: StringName, euler: Vector3, w: float) -> void:
    var n: Node3D = parts.get(part)
    if n == null or w <= 0.0:
        return
    var want: Basis = (rest[part] as Transform3D).basis * Basis.from_euler(euler)
    n.basis = want if w >= 1.0 else n.basis.orthonormalized().slerp(want.orthonormalized(), w)


func shift(part: StringName, offset: Vector3) -> void:
    var n: Node3D = parts.get(part)
    if n != null:
        n.position = (rest[part] as Transform3D).origin + offset


## Turns `part` (from its rest orientation under its parent's current pose) so that its local
## `rest_dir` points along world `want`.
func aim(part: StringName, rest_dir: Vector3, want: Vector3) -> void:
    var n: Node3D = parts.get(part)
    if n == null or want.length_squared() < 1e-8:
        return
    var parent: Node3D = n.get_parent() as Node3D
    var rest_global: Basis = parent.global_basis * (rest[part] as Transform3D).basis
    var axis: Vector3 = (rest_global * rest_dir).normalized()
    var w: Vector3 = want.normalized()
    if axis.dot(w) > 0.99999:
        n.basis = (rest[part] as Transform3D).basis
        return
    if axis.dot(w) < -0.9999:
        w = (w + parent.global_basis.x * 0.01).normalized()
    n.global_basis = Basis(Quaternion(axis, w)) * rest_global


## Two-bone IK: bends `upper` and `lower` so the point `end_local` (in `lower`'s space) reaches
## world `target`, the middle joint bending toward world direction `pole`. Returns the reach (0..1).
func ik(upper: StringName, lower: StringName, end_local: Vector3, target: Vector3, pole: Vector3) -> float:
    var up: Node3D = parts.get(upper)
    var lo: Node3D = parts.get(lower)
    if up == null or lo == null:
        return 0.0
    var hip: Vector3 = up.global_position
    var a: float = (lo.global_position - hip).length()
    var b: float = (lo.global_transform * end_local - lo.global_position).length()
    var to: Vector3 = target - hip
    var dist: float = to.length()
    if dist < 0.0001 or a < 0.0001 or b < 0.0001:
        return 0.0
    var dir: Vector3 = to / dist
    var d: float = clampf(dist, absf(a - b) + 0.01, (a + b) * 0.999)
    var cos_a: float = clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
    var bend: Vector3 = pole - dir * pole.dot(dir)
    if bend.length_squared() < 1e-6:
        bend = dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT)
    bend = bend.normalized()
    var knee: Vector3 = hip + dir * a * cos_a + bend * a * sqrt(1.0 - cos_a * cos_a)
    aim(upper, (rest[lower] as Transform3D).origin, knee - hip)
    aim(lower, end_local, hip + dir * d - knee)
    return dist / (a + b)


## Gives `part` its authored orientation relative to the model root (e.g. a foot kept flat
## whatever the leg above it does).
func level(part: StringName, extra: Basis = Basis.IDENTITY) -> void:
    var n: Node3D = parts.get(part)
    if n != null:
        n.global_basis = model.global_basis * (rest_root[part] as Transform3D).basis * extra


## World position of `part`'s rest point in the model (where it would be standing at rest).
func rest_point(part: StringName) -> Vector3:
    return model.global_transform * (rest_root[part] as Transform3D).origin


## An additive pass over every mesh: a white flash, a red telegraph rim, a pale blink.
func overlay(color: Color, strength: float, rim_power: float = 2.0, base: float = 0.25) -> void:
    var on: bool = strength > 0.01
    if on:
        if _overlay == null:
            if _overlay_shader == null:
                _overlay_shader = Shader.new()
                _overlay_shader.code = OVERLAY_CODE
            _overlay = ShaderMaterial.new()
            _overlay.shader = _overlay_shader
        _overlay.set_shader_parameter(&"tint", color)
        _overlay.set_shader_parameter(&"strength", strength)
        _overlay.set_shader_parameter(&"rim_power", rim_power)
        _overlay.set_shader_parameter(&"base", base)
    if on == _overlay_on:
        return
    _overlay_on = on
    for mi: MeshInstance3D in meshes:
        mi.material_overlay = _overlay if on else null


## Scales the emission of this rig's own `role` material (eyes flaring on a telegraph).
func glow(role: StringName, energy: float, color: Color = Color(0, 0, 0, 0)) -> void:
    var m: StandardMaterial3D = glows.get(role) as StandardMaterial3D
    if m == null:
        return
    m.emission_energy_multiplier = energy
    if color.a > 0.0:
        m.emission = color
