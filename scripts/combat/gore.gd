class_name Gore
extends RefCounted
## Presentation-only gore for hits and deaths: arterial spurts and mist along the hit direction,
## simulated droplets that leave splats where they land, blood decals (Decal on Forward+/Mobile, a
## flat alpha quad on Compatibility), spreading pools under corpses and tumbling gibs.
## Each combatant bleeds its own fluid, chosen by class: red blood (soldiers, hounds, knights, the
## Gravewarden, the Bishop, the hero), dark ichor and bone shards (Bone Archer, Bone Crawler) and a
## burst of black mist (Flying Wraith); anything else (a breakable slab) only puffs stone dust.
## GameSettings.reduced_gore turns every fluid into grey ash and skips decals, pools and gibs.
## Hooks: HitFeedback.play() calls hit(); Health calls on_death() when a combatant dies.
## Nothing here reads or writes combat state, so it can never change an outcome.

enum Fluid { BLOOD, ICHOR, ECTO, DUST }

## Tints applied to the grayscale splat textures and to droplets: deep, wet and dark.
const BLOOD_TINT: Color = Color(0.42, 0.006, 0.018)
const ICHOR_TINT: Color = Color(0.2, 0.085, 0.035)
const ECTO_TINT: Color = Color(0.1, 0.06, 0.14)
const ASH_TINT: Color = Color(0.22, 0.21, 0.24)
const DUST_TINT: Color = Color(0.36, 0.33, 0.3)
## The colour reported on a hit's "hit_fx" node (`spray_color` meta), as HitFeedback always did.
const BLOOD_FX_COLOR: Color = Color(0.55, 0.02, 0.04)
const FLESH_COLOR: Color = Color(0.3, 0.035, 0.04)
const BONE_COLOR: Color = Color(0.74, 0.68, 0.56)

## Live splats/pools; past this the oldest fade out first.
const MAX_DECALS: int = 120
## Live gibs; past this the oldest shrink away.
const MAX_GIBS: int = 28
const WORLD_MASK: int = 1

static var _decals: Array[Node3D] = []
static var _gibs: Array[Node3D] = []
static var _quad_materials: Dictionary = {}
static var _mist_material: StandardMaterial3D
static var _gib_materials: Dictionary = {}
static var _decal_support: int = -1
## Forces the flat-quad fallback even where Decal works (tests, capture comparisons).
static var force_fallback: bool = false
## Splats/pools ever spawned (diagnostics and tests).
static var spawned_splats: int = 0


# --- entry points ---------------------------------------------------------------------------

## A landed hit on `victim` (the hurtbox owner): spurts and mist along the hit direction, harder
## for heavy hits and kills. Returns the node tagged "hit_fx" (with `spray_color` meta).
static func hit(tree: SceneTree, info: DamageInfo, victim: Node, team: StringName, strength: float, killed: bool) -> Node3D:
    var host: Node = tree.current_scene
    if host == null:
        return null
    var fluid: Fluid = fluid_for(victim, team)
    var tint: Color = tint_for(fluid)
    var gore_on: bool = not GameSettings.reduced_gore and fluid != Fluid.DUST
    var dir: Vector3 = _hit_direction(info, victim)
    var at: Vector3 = info.hit_position
    var s: float = strength + (0.3 if killed else 0.0)
    if team == &"player":
        s *= 0.8
    var fx_color: Color = ASH_TINT
    if not GameSettings.reduced_gore:
        fx_color = BLOOD_FX_COLOR if fluid == Fluid.BLOOD else tint
    var mist_amount: int = int((14 if gore_on else 10) * s)
    var mist: CPUParticles3D = _mist(host, at, dir, _mist_color(fluid), mist_amount, 3.2 * s, 32.0, 0.75, 1.3)
    mist.add_to_group(&"hit_fx")
    mist.set_meta(&"spray_color", fx_color)
    if fluid == Fluid.DUST:
        return mist
    var droplets: BloodDroplets = _droplets(host)
    # Arterial spurts: tight jets pumped out in a couple of pulses along the hit direction.
    var jets: int = 1 + (1 if s > 1.3 else 0) + (1 if s > 2.0 else 0)
    for j in jets:
        var jet_dir: Vector3 = _jitter(dir, 0.35)
        var count: int = int((5 if not gore_on else 14) * s)
        for k in count:
            var pulse: float = 0.0 if k < count * 0.6 else 0.09
            var v: Vector3 = _jitter(jet_dir, 0.12) * randf_range(4.5, 8.5) * (0.85 + 0.15 * s)
            var splat_size: float = randf_range(0.28, 0.55) if gore_on and k % 3 == 0 else 0.0
            droplets.add(at, v, randf_range(0.02, 0.036), tint, 1.6, k * 0.01 + pulse + j * 0.03, splat_size)
    # Back-spatter toward the attacker (and so the camera): a short spit out of the entry wound.
    var back: Vector3 = Vector3(-dir.x, absf(dir.y) + 0.5, -dir.z).normalized()
    for k in int((3 if not gore_on else 6) * s):
        var v: Vector3 = _jitter(back, 0.45) * randf_range(2.0, 4.0)
        droplets.add(at, v, randf_range(0.014, 0.026), tint, 1.2, randf() * 0.04, randf_range(0.15, 0.28) if gore_on and k % 3 == 0 else 0.0)
    # Coarse spatter thrown wider, and a few heavy drops that just fall off the wound.
    for k in int((6 if not gore_on else 12) * s):
        var v: Vector3 = _jitter(dir, 0.75) * randf_range(1.8, 4.8)
        droplets.add(at, v, randf_range(0.012, 0.024), tint, 1.4, randf() * 0.05, randf_range(0.14, 0.3) if gore_on and k % 4 == 0 else 0.0)
    if gore_on:
        for k in int(3 * s):
            droplets.add(at + _rand_unit() * 0.12, Vector3(randf_range(-0.4, 0.4), randf_range(-0.5, 0.6), randf_range(-0.4, 0.4)), randf_range(0.02, 0.032), tint, 2.0, randf() * 0.25, randf_range(0.18, 0.34))
        if team == &"player" and victim is Node3D:
            DripTrail.attach(host, victim as Node3D, tint, 1.1)
    return mist


## Death gore for a combatant that just hit 0 HP (called by Health). Ignores non-combatants.
static func on_death(body: Node) -> void:
    if not (body is Node3D) or not body.is_inside_tree():
        return
    var team: StringName = _team_of(body)
    if team == &"" or team == &"breakable":
        return
    var tree: SceneTree = body.get_tree()
    var host: Node = tree.current_scene
    if host == null:
        return
    var node: Node3D = body as Node3D
    var fluid: Fluid = fluid_for(body, team)
    var tint: Color = tint_for(fluid)
    var gore_on: bool = not GameSettings.reduced_gore
    var is_player: bool = team == &"player"
    var scale: float = 1.0
    if body is HollowBishop:
        scale = 2.2
    elif body is Gravewarden:
        scale = 1.6
    var center: Vector3 = node.global_position + Vector3(0.0, 0.35 if not is_player else 0.9, 0.0)
    var ground: Dictionary = _ground_below(node, center)
    var droplets: BloodDroplets = _droplets(host)
    if fluid == Fluid.ECTO:
        _mist(host, center, Vector3.UP, _mist_color(fluid), int(60 * scale), 3.5, 180.0, 1.6, 2.6)
    else:
        _mist(host, center, Vector3.UP, _mist_color(fluid), int((30 if fluid == Fluid.BLOOD else 18) * scale), 4.5, 75.0, 1.0, 1.7)
    # The burst: a fountain of spurts in every direction, biased upward.
    var count: int = int((70 if fluid == Fluid.BLOOD else 40 if fluid == Fluid.ICHOR else 24) * scale)
    if not gore_on:
        count = int(count * 0.4)
    for k in count:
        var d: Vector3 = _rand_unit()
        d.y = absf(d.y) * 1.4 + 0.25
        var v: Vector3 = d.normalized() * randf_range(2.5, 7.5) * sqrt(scale)
        var splat_size: float = randf_range(0.3, 0.7) * sqrt(scale) if gore_on and k % (4 if fluid != Fluid.ECTO else 8) == 0 else 0.0
        droplets.add(center + _rand_unit() * 0.15, v, randf_range(0.02, 0.042), tint, 2.0, randf() * 0.18, splat_size)
    tree.call_group(&"camera_shaker", &"add_trauma", 0.18 * scale)
    if not gore_on:
        return
    # Gibs: meat for the living, shards for bone things; wraiths leave nothing solid.
    var flesh: int = 0
    var bones: int = 0
    match fluid:
        Fluid.BLOOD:
            flesh = 0 if is_player else int(5 * scale)
            bones = 0 if is_player else int(2 * scale)
        Fluid.ICHOR:
            bones = int(8 * scale)
            flesh = 1
    for k in flesh:
        _gib(host, center, false, tint)
    for k in bones:
        _gib(host, center, true, tint if fluid == Fluid.ICHOR else BLOOD_TINT)
    # A pool spreading under the body (not under a wraith: it has no body left to bleed).
    if fluid != Fluid.ECTO and not ground.is_empty():
        var radius: float = (0.8 if is_player else 1.15 if fluid == Fluid.BLOOD else 0.7) * scale
        pool(host, ground[&"position"], ground[&"normal"], radius, tint, 0.25, 1.5)


## Lays a splat of `size` m at `pos` on a surface with `normal`, stretched along the impact's
## slide direction. Returns the decal/quad node (null with reduced gore or no scene).
static func splat(from_node: Node, pos: Vector3, normal: Vector3, size: float, tint: Color, impact: Vector3 = Vector3.ZERO) -> Node3D:
    if GameSettings.reduced_gore or from_node == null or not from_node.is_inside_tree():
        return null
    var host: Node = from_node.get_tree().current_scene
    if host == null:
        return null
    var n: Vector3 = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
    var slide: Vector3 = impact - n * impact.dot(n)
    var stretch: float = clampf(1.0 + slide.length() * 0.07, 1.0, 1.9)
    var basis: Basis = _surface_basis(n, slide if slide.length_squared() > 0.25 else Vector3.ZERO)
    var dims: Vector2 = Vector2(size * stretch, size)
    var node: Node3D = _place_splat(host, pos, n, basis, dims, tint, BloodTextures.random_splat(), false)
    # Splash in: the splat flicks out to full size as it lands.
    _grow(node, 0.55, 1.0, 0.0, 0.07)
    return node


## A spreading pool: starts small after `delay` s and grows to `radius` over `grow_time` s.
static func pool(host: Node, pos: Vector3, normal: Vector3, radius: float, tint: Color, delay: float, grow_time: float) -> Node3D:
    if GameSettings.reduced_gore or host == null:
        return null
    var n: Vector3 = normal.normalized()
    var basis: Basis = _surface_basis(n, Vector3.ZERO)
    var dims: Vector2 = Vector2(radius * 2.0, radius * 2.0 * randf_range(0.8, 1.0))
    var node: Node3D = _place_splat(host, pos, n, basis, dims, tint, BloodTextures.pool(), true)
    node.add_to_group(&"gore_pool")
    _grow(node, 0.12, 1.0, delay, grow_time)
    return node


## One droplet into the scene's shared droplet system (used by gibs and drip trails).
static func drop(from_node: Node, at: Vector3, velocity: Vector3, radius: float, tint: Color, delay: float = 0.0, splat_size: float = 0.0) -> void:
    if from_node == null or not from_node.is_inside_tree():
        return
    var host: Node = from_node.get_tree().current_scene
    if host == null:
        return
    _droplets(host).add(at, velocity, radius, tint, 2.0, delay, 0.0 if GameSettings.reduced_gore else splat_size)


## Live (not yet evicted) splats and pools.
static func live_decals() -> int:
    _prune()
    return _decals.size()


static func live_gibs() -> int:
    var kept: Array[Node3D] = []
    for g: Variant in _gibs:
        if is_instance_valid(g) and not (g as GoreGib).is_queued_for_deletion() and (g as GoreGib).life > 0.0:
            kept.append(g)
    _gibs = kept
    return _gibs.size()


## True when Decal renders (Forward+ / Mobile); Compatibility gets flat quads instead.
static func supports_decals() -> bool:
    if force_fallback:
        return false
    if _decal_support < 0:
        _decal_support = 0 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1
    return _decal_support == 1


static func fluid_for(victim: Node, team: StringName = &"") -> Fluid:
    if victim is BoneArcher or victim is BoneCrawler:
        return Fluid.ICHOR
    if victim is FlyingWraith:
        return Fluid.ECTO
    if team == &"breakable" or team == &"neutral" and not (victim is CharacterBody3D):
        return Fluid.DUST
    return Fluid.BLOOD


static func tint_for(fluid: Fluid) -> Color:
    if GameSettings.reduced_gore:
        return ASH_TINT
    match fluid:
        Fluid.ICHOR:
            return ICHOR_TINT
        Fluid.ECTO:
            return ECTO_TINT
        Fluid.DUST:
            return DUST_TINT
    return BLOOD_TINT


# --- internals ------------------------------------------------------------------------------

static func _team_of(body: Node) -> StringName:
    var hb: Variant = body.get(&"hurtbox")
    if hb is Hurtbox:
        return (hb as Hurtbox).team
    if body is HollowBishop or body is CodeEnemy or body is PlaguedSoldier or body is CryptHound or body is BoneArcher:
        return &"enemy"
    return &""


static func _mist_color(fluid: Fluid) -> Color:
    if GameSettings.reduced_gore:
        return Color(0.3, 0.29, 0.31, 0.75)
    match fluid:
        Fluid.ICHOR:
            return Color(0.32, 0.22, 0.14, 0.8)
        Fluid.ECTO:
            return Color(0.12, 0.07, 0.16, 0.85)
        Fluid.DUST:
            return Color(0.45, 0.42, 0.38, 0.7)
    return Color(0.72, 0.04, 0.05, 0.8)


static func _droplets(host: Node) -> BloodDroplets:
    for n: Node in host.get_tree().get_nodes_in_group(&"gore_droplets"):
        if n.get_parent() == host and not n.is_queued_for_deletion():
            return n as BloodDroplets
    var d: BloodDroplets = BloodDroplets.create()
    host.add_child(d)
    return d


static func _hit_direction(info: DamageInfo, victim: Node) -> Vector3:
    var push: Vector3 = info.knockback
    push.y = 0.0
    if push.length_squared() < 0.01 and info.source != null and is_instance_valid(info.source) and victim is Node3D:
        push = (victim as Node3D).global_position - info.source.global_position
        push.y = 0.0
    if push.length_squared() < 0.0001:
        push = _rand_unit()
        push.y = 0.0
    return (push.normalized() + Vector3.UP * 0.45).normalized()


static func _rand_unit() -> Vector3:
    var v: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
    return v.normalized() if v.length_squared() > 0.0001 else Vector3.UP


## `dir` nudged by up to `amount` (0 = exact, 1 = roughly a hemisphere).
static func _jitter(dir: Vector3, amount: float) -> Vector3:
    return (dir + _rand_unit() * amount * randf()).normalized()


## A basis whose +Y is the surface normal (Decal projects along -Y; PlaneMesh faces +Y) and whose
## +X follows `along` when given, else a random spin about the normal.
static func _surface_basis(n: Vector3, along: Vector3) -> Basis:
    var ref: Vector3 = Vector3.FORWARD if absf(n.dot(Vector3.UP)) > 0.9 else Vector3.UP
    var x: Vector3 = along - n * along.dot(n)
    if x.length_squared() < 0.0001:
        x = ref.cross(n).normalized().rotated(n, randf() * TAU)
    x = x.normalized()
    var z: Vector3 = x.cross(n).normalized()
    return Basis(x, n, z)


static func _place_splat(host: Node, pos: Vector3, n: Vector3, basis: Basis, dims: Vector2, tint: Color, tex: Dictionary, is_pool: bool) -> Node3D:
    _make_room()
    var node: Node3D
    if supports_decals():
        var decal: Decal = Decal.new()
        decal.name = "BloodPool" if is_pool else "BloodSplat"
        decal.size = Vector3(dims.x, 0.7, dims.y)
        decal.texture_albedo = tex[&"albedo"]
        decal.texture_normal = tex[&"normal"]
        decal.texture_orm = tex[&"orm"]
        decal.modulate = tint
        decal.albedo_mix = 1.0
        decal.normal_fade = 0.35
        decal.upper_fade = 0.15
        decal.lower_fade = 0.4
        decal.distance_fade_enabled = true
        decal.distance_fade_begin = 45.0
        decal.distance_fade_length = 10.0
        decal.set_meta(&"full_size", decal.size)
        node = decal
        host.add_child(node)
        node.global_transform = Transform3D(basis, pos + n * 0.08)
    else:
        var quad: MeshInstance3D = MeshInstance3D.new()
        quad.name = "BloodPoolQuad" if is_pool else "BloodSplatQuad"
        var plane: PlaneMesh = PlaneMesh.new()
        plane.size = Vector2.ONE
        quad.mesh = plane
        quad.material_override = _quad_material(tex, tint)
        quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node = quad
        host.add_child(node)
        # Pools sit lowest; later splats stack a hair higher so overlaps never z-fight.
        var lift: float = 0.012 + (0.0 if is_pool else 0.004 + float(spawned_splats % 16) * 0.0006)
        node.global_transform = Transform3D(basis * Basis.from_scale(Vector3(dims.x, 1.0, dims.y)), pos + n * lift)
        node.set_meta(&"full_size", Vector3(dims.x, 1.0, dims.y))
    node.add_to_group(&"gore_decal")
    _decals.append(node)
    spawned_splats += 1
    return node


static func _quad_material(tex: Dictionary, tint: Color) -> StandardMaterial3D:
    var key: String = "%d|%s" % [(tex[&"albedo"] as Texture2D).get_rid().get_id(), tint.to_html()]
    if _quad_materials.has(key):
        return _quad_materials[key]
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_texture = tex[&"albedo"]
    m.albedo_color = tint
    m.normal_enabled = true
    m.normal_texture = tex[&"normal"]
    m.roughness = 1.0
    m.roughness_texture = tex[&"orm"]
    m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    m.metallic_specular = 0.75
    _quad_materials[key] = m
    return m


## Scales a splat/pool from `from_k` to `to_k` of its full size.
static func _grow(node: Node3D, from_k: float, to_k: float, delay: float, seconds: float) -> void:
    var full: Vector3 = node.get_meta(&"full_size")
    var tween: Tween = node.create_tween()
    if node is Decal:
        var d: Decal = node as Decal
        d.size = Vector3(full.x * from_k, full.y, full.z * from_k)
        tween.tween_property(d, "size", Vector3(full.x * to_k, full.y, full.z * to_k), seconds).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    else:
        var basis: Basis = node.global_transform.basis.orthonormalized()
        var origin: Vector3 = node.global_position
        var apply: Callable = func(k: float) -> void:
            if is_instance_valid(node) and not node.has_meta(&"evicted"):
                node.global_transform = Transform3D(basis * Basis.from_scale(Vector3(full.x * k, 1.0, full.z * k)), origin)
        apply.call(from_k)
        tween.tween_method(apply, from_k, to_k, seconds).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _prune() -> void:
    var kept: Array[Node3D] = []
    for d: Variant in _decals:
        if is_instance_valid(d) and not (d as Node3D).is_queued_for_deletion() and not (d as Node3D).has_meta(&"evicted"):
            kept.append(d)
    _decals = kept


## Keeps the live count under MAX_DECALS: the oldest fade out (and stop counting) at once.
static func _make_room() -> void:
    _prune()
    while _decals.size() >= MAX_DECALS:
        # Oldest splat first; pools (one per corpse) only go once no plain splat is left.
        var victim: int = 0
        for i in _decals.size():
            if not _decals[i].is_in_group(&"gore_pool"):
                victim = i
                break
        _evict(_decals.pop_at(victim))


static func _evict(node: Node3D) -> void:
    node.remove_from_group(&"gore_decal")
    node.set_meta(&"evicted", true)
    var tween: Tween = node.create_tween()
    if node is Decal:
        tween.tween_property(node, "modulate:a", 0.0, 0.6)
    else:
        tween.tween_property(node, "scale", Vector3(0.01, 1.0, 0.01), 0.6)
    tween.tween_callback(node.queue_free)


static func _mist(host: Node, at: Vector3, dir: Vector3, color: Color, amount: int, speed: float, spread: float, life: float, size: float) -> CPUParticles3D:
    var p: CPUParticles3D = CPUParticles3D.new()
    p.name = "GoreMist"
    p.one_shot = true
    p.explosiveness = 0.92
    p.amount = maxi(amount, 1)
    p.lifetime = life
    p.direction = dir
    p.spread = spread
    p.initial_velocity_min = speed * 0.25
    p.initial_velocity_max = speed
    p.damping_min = 2.5
    p.damping_max = 5.0
    p.gravity = Vector3(0.0, -2.5, 0.0)
    p.scale_amount_min = size * 0.5
    p.scale_amount_max = size
    var grow: Curve = Curve.new()
    grow.add_point(Vector2(0.0, 0.5))
    grow.add_point(Vector2(1.0, 1.0))
    p.scale_amount_curve = grow
    var ramp: Gradient = Gradient.new()
    ramp.set_color(0, color)
    ramp.set_color(1, Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.0))
    p.color_ramp = ramp
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2.ONE
    quad.material = _mist_mat()
    p.mesh = quad
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    host.add_child(p)
    p.global_position = at
    p.emitting = true
    # Freed on a game-time timer (it slows with hitstop like the particles themselves do).
    host.get_tree().create_timer(life + 0.4, false).timeout.connect(func() -> void:
        if is_instance_valid(p):
            p.queue_free())
    return p


static func _mist_mat() -> StandardMaterial3D:
    if _mist_material == null:
        var m: StandardMaterial3D = StandardMaterial3D.new()
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.vertex_color_use_as_albedo = true
        m.albedo_texture = BloodTextures.soft_dot()
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.billboard_keep_scale = true
        _mist_material = m
    return _mist_material


static func _gib(host: Node, at: Vector3, bone: bool, fluid: Color) -> void:
    live_gibs()
    while _gibs.size() >= MAX_GIBS:
        var old: Node3D = _gibs.pop_front()
        (old as GoreGib).expire()
    var g: GoreGib = GoreGib.new()
    g.name = "BoneShard" if bone else "FleshGib"
    if bone:
        var shard: CylinderMesh = CylinderMesh.new()
        shard.top_radius = randf_range(0.006, 0.014)
        shard.bottom_radius = randf_range(0.022, 0.034)
        shard.height = randf_range(0.16, 0.3)
        shard.radial_segments = 5
        shard.rings = 1
        shard.material = _gib_mat(true)
        g.mesh = shard
        g.half_extent = 0.03
        g.fluid = Color(fluid.r, fluid.g, fluid.b, 1.0 if randf() < 0.5 else 0.0)
    else:
        var lump: SphereMesh = SphereMesh.new()
        var r: float = randf_range(0.06, 0.11)
        lump.radius = r
        lump.height = r * randf_range(1.2, 2.0)
        lump.radial_segments = 5
        lump.rings = 3
        lump.material = _gib_mat(false)
        g.mesh = lump
        g.half_extent = r * 0.7
        g.fluid = Color(fluid.r, fluid.g, fluid.b, 1.0)
    var d: Vector3 = _rand_unit()
    d.y = absf(d.y) + 0.6
    g.velocity = d.normalized() * randf_range(3.5, 7.5)
    g.spin = _rand_unit() * randf_range(6.0, 16.0)
    g.life = randf_range(3.5, 5.0)
    host.add_child(g)
    g.global_position = at + _rand_unit() * 0.2
    g.rotation = _rand_unit() * PI
    g.scale = Vector3(randf_range(0.8, 1.3), randf_range(0.8, 1.3), randf_range(0.8, 1.3))
    _gibs.append(g)


static func _gib_mat(bone: bool) -> StandardMaterial3D:
    if not _gib_materials.has(bone):
        var m: StandardMaterial3D = StandardMaterial3D.new()
        m.albedo_color = BONE_COLOR if bone else FLESH_COLOR
        m.roughness = 0.55 if bone else 0.22
        m.metallic_specular = 0.4 if bone else 0.75
        _gib_materials[bone] = m
    return _gib_materials[bone]


## The world surface under `body` (ignoring itself and other characters), or {}.
static func _ground_below(body: Node3D, from: Vector3) -> Dictionary:
    var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
    if space == null:
        return {}
    var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.3, from + Vector3.DOWN * 10.0, WORLD_MASK)
    var skip: Array[RID] = []
    if body is CollisionObject3D:
        skip.append((body as CollisionObject3D).get_rid())
    for attempt in 4:
        q.exclude = skip
        var hit: Dictionary = space.intersect_ray(q)
        if hit.is_empty():
            return {}
        var c: Variant = hit.get(&"collider")
        if c is CharacterBody3D or c is RigidBody3D:
            skip.append(hit[&"rid"])
            continue
        return hit
    return {}


## A faint drip trail for a wounded body: a drop every few frames for `seconds`.
class DripTrail:
    extends Node3D

    var target: WeakRef
    var tint: Color
    var left: float = 1.0
    var _next: float = 0.0

    static func attach(host: Node, body: Node3D, color: Color, seconds: float) -> void:
        for n: Node in host.get_children():
            if n is DripTrail and (n as DripTrail).target.get_ref() == body:
                (n as DripTrail).left = maxf((n as DripTrail).left, seconds)
                return
        var t: DripTrail = DripTrail.new()
        t.name = "GoreDripTrail"
        t.target = weakref(body)
        t.tint = color
        t.left = seconds
        host.add_child(t)

    func _physics_process(delta: float) -> void:
        var body: Node3D = target.get_ref() as Node3D
        left -= delta
        if body == null or not body.is_inside_tree() or left <= 0.0:
            queue_free()
            return
        _next -= delta
        if _next <= 0.0:
            _next = randf_range(0.06, 0.12)
            var at: Vector3 = body.global_position + Vector3(randf_range(-0.2, 0.2), randf_range(0.5, 1.1), randf_range(-0.2, 0.2))
            Gore.drop(self, at, Vector3(0.0, -0.5, 0.0), randf_range(0.012, 0.02), tint, 0.0, randf_range(0.1, 0.2))
