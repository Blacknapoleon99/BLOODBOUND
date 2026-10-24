class_name BloodTextures
extends RefCounted
## Procedural blood splatter textures for Gore (no image assets): built once on first use and
## cached for the session. Each texture set is a grayscale albedo with an alpha mask (tinted per
## fluid by Decal.modulate / the fallback material colour), a normal map that makes thick blood
## bulge, and an ORM map with very low roughness so splats read wet under the moonlight.
## Shapes are metaball fields (Wyvill kernel), so lobes merge organically: a splat is a core,
## spiky arms that thin to beads and satellite droplets; a pool is a broad lobed puddle.

const SPLAT_SIZE: int = 96
const POOL_SIZE: int = 160
const SPLAT_VARIANTS: int = 5
## Field value where the surface edge sits (the kernel is 0.5625 at a ball's nominal radius).
const THRESHOLD: float = 0.5

static var _splats: Array[Dictionary] = []
static var _pool: Dictionary = {}
static var _soft: Texture2D


## One of the cached splat sets: {albedo, normal, orm} Texture2Ds.
static func splat(variant: int) -> Dictionary:
    _ensure()
    return _splats[posmod(variant, _splats.size())]


static func random_splat() -> Dictionary:
    return splat(randi())


## The broad pool set used under corpses.
static func pool() -> Dictionary:
    _ensure()
    return _pool


## A soft round particle sprite (white, radial alpha falloff) for mist.
static func soft_dot() -> Texture2D:
    if _soft == null:
        var n: int = 32
        var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
        for y in n:
            for x in n:
                var d: float = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
                var a: float = 1.0 - smoothstep(0.15, 1.0, d)
                img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
        img.generate_mipmaps()
        _soft = ImageTexture.create_from_image(img)
    return _soft


static func is_built() -> bool:
    return not _splats.is_empty()


static func _ensure() -> void:
    if not _splats.is_empty():
        return
    for i in SPLAT_VARIANTS:
        _splats.append(_build(SPLAT_SIZE, 9100 + i * 37, false))
    _pool = _build(POOL_SIZE, 4242, true)


## Metaballs as [x, y, r] in pixels, kept inside the image so edges stay transparent.
static func _layout(size: int, rng: RandomNumberGenerator, is_pool: bool) -> Array[Vector3]:
    var balls: Array[Vector3] = []
    var c: float = size * 0.5
    var s: float = float(size)
    if is_pool:
        for i in 7:
            var a: float = rng.randf() * TAU
            var d: float = rng.randf_range(0.0, 0.11) * s
            balls.append(Vector3(c + cos(a) * d, c + sin(a) * d, rng.randf_range(0.13, 0.19) * s))
        for i in 16:
            var a: float = TAU * i / 16.0 + rng.randf_range(-0.2, 0.2)
            var d: float = rng.randf_range(0.2, 0.3) * s
            balls.append(Vector3(c + cos(a) * d, c + sin(a) * d, rng.randf_range(0.035, 0.075) * s))
        for i in 10:
            var a: float = rng.randf() * TAU
            var d: float = rng.randf_range(0.34, 0.42) * s
            balls.append(Vector3(c + cos(a) * d, c + sin(a) * d, rng.randf_range(0.01, 0.025) * s))
    else:
        # Lumpy core: overlapping lobes pushed off-centre so the outline is never a disc.
        for i in rng.randi_range(5, 8):
            var a: float = rng.randf() * TAU
            var d: float = rng.randf_range(0.02, 0.12) * s
            balls.append(Vector3(c + cos(a) * d, c + sin(a) * d, rng.randf_range(0.06, 0.13) * s))
        # A few uneven arms: chains of shrinking beads flung outward, most of them short.
        var arms: int = rng.randi_range(3, 6)
        for i in arms:
            var a: float = rng.randf() * TAU
            var reach: float = (rng.randf_range(0.3, 0.44) if i < 2 else rng.randf_range(0.18, 0.3)) * s
            var r0: float = rng.randf_range(0.025, 0.05) * s
            var t: float = 0.1 * s
            while t < reach:
                var k: float = (t - 0.1 * s) / maxf(reach - 0.1 * s, 1.0)
                var r: float = lerpf(r0, 0.01 * s, k) * rng.randf_range(0.8, 1.15)
                var wob: float = rng.randf_range(-0.012, 0.012) * s
                balls.append(Vector3(c + cos(a) * t - sin(a) * wob, c + sin(a) * t + cos(a) * wob, r))
                t += r * 1.1
            # A bead at the tip, as flung blood gathers at the end of a streak.
            if rng.randf() < 0.7:
                var tip: float = reach + rng.randf_range(0.02, 0.05) * s
                balls.append(Vector3(c + cos(a) * tip, c + sin(a) * tip, rng.randf_range(0.015, 0.028) * s))
        # Satellite droplets, denser on one side (the way the spray was travelling).
        var bias: float = rng.randf() * TAU
        for i in rng.randi_range(14, 24):
            var a: float = bias + rng.randfn(0.0, 1.1)
            var d: float = rng.randf_range(0.2, 0.46) * s
            balls.append(Vector3(c + cos(a) * d, c + sin(a) * d, rng.randf_range(0.007, 0.022) * s))
    var limit: float = s * 0.5 - 1.5
    var kept: Array[Vector3] = []
    for b: Vector3 in balls:
        var reach_out: float = Vector2(b.x - c, b.y - c).length() + b.z * 1.6
        if reach_out < limit:
            kept.append(b)
    return kept


static func _build(size: int, seed_value: int, is_pool: bool) -> Dictionary:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = seed_value
    var field: PackedFloat32Array = PackedFloat32Array()
    field.resize(size * size)
    for b: Vector3 in _layout(size, rng, is_pool):
        var support: float = b.z * 2.0
        var s2: float = support * support
        var x0: int = maxi(0, int(b.x - support))
        var x1: int = mini(size - 1, int(b.x + support) + 1)
        var y0: int = maxi(0, int(b.y - support))
        var y1: int = mini(size - 1, int(b.y + support) + 1)
        for y in range(y0, y1 + 1):
            var dy: float = y + 0.5 - b.y
            for x in range(x0, x1 + 1):
                var dx: float = x + 0.5 - b.x
                var d2: float = dx * dx + dy * dy
                if d2 < s2:
                    var k: float = 1.0 - d2 / s2
                    field[y * size + x] += k * k
    var albedo: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
    var height: PackedFloat32Array = PackedFloat32Array()
    height.resize(size * size)
    var grain: FastNoiseLite = FastNoiseLite.new()
    grain.seed = seed_value
    grain.frequency = 0.09
    for y in size:
        for x in size:
            var f: float = field[y * size + x]
            var a: float = smoothstep(THRESHOLD - 0.05, THRESHOLD + 0.05, f)
            var thick: float = clampf((f - THRESHOLD) / 1.1, 0.0, 1.0)
            height[y * size + x] = a * 0.35 + sqrt(thick) * 0.65
            # Thick blood is darker; a thin dried rim is a touch darker again (coffee ring).
            var rim: float = a * (1.0 - smoothstep(0.0, 0.12, thick))
            var v: float = lerpf(1.0, 0.55, sqrt(thick)) - rim * 0.18 + grain.get_noise_2d(x, y) * 0.06
            albedo.set_pixel(x, y, Color(v, v, v, a))
    var normal: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
    var orm: Image = Image.create(size, size, false, Image.FORMAT_RGB8)
    var bump: float = 1.1 if is_pool else 1.6
    for y in size:
        for x in size:
            var hl: float = height[y * size + maxi(x - 1, 0)]
            var hr: float = height[y * size + mini(x + 1, size - 1)]
            var hu: float = height[maxi(y - 1, 0) * size + x]
            var hd: float = height[mini(y + 1, size - 1) * size + x]
            var n: Vector3 = Vector3((hl - hr) * bump, (hu - hd) * bump, 1.0).normalized()
            normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
            var h: float = height[y * size + x]
            orm.set_pixel(x, y, Color(1.0, lerpf(0.42, 0.1, clampf(h * 1.6, 0.0, 1.0)), 0.0))
    albedo.generate_mipmaps()
    normal.generate_mipmaps()
    orm.generate_mipmaps()
    return {
        &"albedo": ImageTexture.create_from_image(albedo),
        &"normal": ImageTexture.create_from_image(normal),
        &"orm": ImageTexture.create_from_image(orm),
    }
