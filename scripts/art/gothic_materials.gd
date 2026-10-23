class_name GothicMaterials
extends RefCounted
## The level-geometry material library (DEC-054): PBR stone/iron for every platform, pillar,
## wall, climb wall, mover and slab, from CC0 Poly Haven scans (assets/textures/gothic/,
## credits in assets/textures/gothic/CREDITS.md) driven by two shaders that work in both the
## Compatibility and Forward+ renderers:
## - scripts/art/shaders/gothic_block.gdshader — boxes: walkable top vs. masonry sides, fake
##   bevel rim, sides sinking into darkness, moss, blood, per-block variation.
## - scripts/art/shaders/gothic_triplanar.gdshader — irregular meshes (rubble, columns, iron).
##
## Materials are cached per (kind, room tint) and shared, so blocks batch. Kinds:
##   floor        worn cathedral flagstone top, mossy masonry sides
##   floor_cobble wet cobble top (puddled, glossy), masonry sides
##   floor_blood  flagstone top with blood pools and drips
##   pillar       flagstone top, darker masonry shaft fading into the void
##   wall         rough dark masonry all round (kick walls, tunnel roofs, cover)
##   ossuary      bone-tinted inlay stone (the cellar dais round a secret)
##   climb        pale rough block wall behind the bone handholds (ClimbWall)
##   iron         rusted iron with an ember rim glow (moving / orbiting platforms)
##   cracked      broken bricks (collapsing slabs; per-instance: they flash red)
##   breakable    cracked slab with faint red light in the cracks (secret floors)
##   rubble       triplanar rock for the broken undersides of floating platforms
##   column       triplanar masonry for broken columns
##   rust         triplanar rusted iron for fence spikes

const TEX: String = "res://assets/textures/gothic/"
const BLOCK_SHADER: String = "res://scripts/art/shaders/gothic_block.gdshader"
const TRIPLANAR_SHADER: String = "res://scripts/art/shaders/gothic_triplanar.gdshader"

static var _cache: Dictionary = {}
static var _textures: Dictionary = {}


## The shared material for `kind`, tinted toward a room's palette colour (optional).
static func block(kind: StringName, room_tint: Color = Color(0, 0, 0, 0)) -> ShaderMaterial:
    var key: String = "%s|%s" % [kind, room_tint.to_html()]
    if _cache.has(key):
        return _cache[key]
    var m: ShaderMaterial = _make(kind, _room_tint(room_tint))
    _cache[key] = m
    return m


## The kind for one of main.gd's greybox solids by its label (&"" = keep its flat colour: bars,
## gates, the decorative silhouettes).
static func kind_for_label(label: String) -> StringName:
    var l: String = label.to_lower()
    if l.contains("bars"):
        return &"rust"
    if l.contains("amber") or l.contains("silhouette") or l.contains("tower"):
        return &""
    if l.contains("wall") or l.contains("door"):
        return &"wall"
    if l.contains("causeway") or l.contains("span") or l.contains("step") or l.contains("landing") or l.contains("threshold"):
        return &"floor"
    return &""


## A fresh (unshared) copy: for blocks that animate their material (collapsing slabs).
static func unique(kind: StringName, room_tint: Color = Color(0, 0, 0, 0)) -> ShaderMaterial:
    return block(kind, room_tint).duplicate() as ShaderMaterial


## The room's palette as a gentle multiplier (luminance-normalised, mostly white).
static func _room_tint(c: Color) -> Color:
    if c.a <= 0.0:
        return Color.WHITE
    var lum: float = maxf(0.001, c.r * 0.3 + c.g * 0.59 + c.b * 0.11)
    var hue: Color = Color(c.r / lum, c.g / lum, c.b / lum)
    return Color.WHITE.lerp(hue, 0.12)


static func _tex(set_name: String, map: String) -> Texture2D:
    var path: String = TEX + set_name + "_" + map + ".jpg"
    if not _textures.has(path):
        _textures[path] = load(path) if ResourceLoader.exists(path) else null
    return _textures[path]


static func _block_material(top_set: String, side_set: String) -> ShaderMaterial:
    var m: ShaderMaterial = ShaderMaterial.new()
    m.shader = load(BLOCK_SHADER)
    m.set_shader_parameter(&"top_albedo", _tex(top_set, "diff"))
    m.set_shader_parameter(&"top_normal", _tex(top_set, "nor"))
    m.set_shader_parameter(&"top_arm", _tex(top_set, "arm"))
    m.set_shader_parameter(&"side_albedo", _tex(side_set, "diff"))
    m.set_shader_parameter(&"side_normal", _tex(side_set, "nor"))
    m.set_shader_parameter(&"side_arm", _tex(side_set, "arm"))
    return m


static func _triplanar(set_name: String, scale: float) -> ShaderMaterial:
    var m: ShaderMaterial = ShaderMaterial.new()
    m.shader = load(TRIPLANAR_SHADER)
    m.set_shader_parameter(&"albedo_tex", _tex(set_name, "diff"))
    m.set_shader_parameter(&"normal_tex", _tex(set_name, "nor"))
    m.set_shader_parameter(&"arm_tex", _tex(set_name, "arm"))
    m.set_shader_parameter(&"tex_scale", scale)
    return m


static func _make(kind: StringName, tint: Color) -> ShaderMaterial:
    var m: ShaderMaterial
    match kind:
        &"floor_cobble":
            m = _block_material("cobble", "masonry")
            m.set_shader_parameter(&"top_scale", 2.2)
            m.set_shader_parameter(&"roughness_bias", -0.28)
            m.set_shader_parameter(&"top_tint", Color(0.62, 0.62, 0.66) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.45, 0.43, 0.45) * tint)
            m.set_shader_parameter(&"moss", 0.45)
        &"floor_blood":
            m = _block_material("flagstone", "masonry")
            m.set_shader_parameter(&"top_tint", Color(0.72, 0.66, 0.64) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.45, 0.4, 0.4) * tint)
            m.set_shader_parameter(&"blood", 1.0)
            m.set_shader_parameter(&"moss", 0.15)
        &"pillar":
            m = _block_material("flagstone", "masonry")
            m.set_shader_parameter(&"top_tint", Color(0.7, 0.68, 0.68) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.48, 0.46, 0.48) * tint)
            m.set_shader_parameter(&"side_fade", 6.5)
            m.set_shader_parameter(&"moss", 0.5)
        &"wall":
            m = _block_material("masonry", "masonry")
            m.set_shader_parameter(&"top_tint", Color(0.42, 0.4, 0.42) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.42, 0.4, 0.42) * tint)
            m.set_shader_parameter(&"side_fade", 9.0)
            m.set_shader_parameter(&"side_dark", 0.3)
            m.set_shader_parameter(&"moss", 0.55)
        &"ossuary":
            m = _block_material("flagstone", "cracked")
            m.set_shader_parameter(&"top_tint", Color(0.95, 0.86, 0.7) * tint)
            m.set_shader_parameter(&"side_tint", Color(1.05, 0.92, 0.74))
            m.set_shader_parameter(&"side_scale", 1.6)
            m.set_shader_parameter(&"moss", 0.1)
            m.set_shader_parameter(&"blood", 0.4)
        &"climb":
            m = _block_material("climb", "climb")
            m.set_shader_parameter(&"top_tint", Color(0.8, 0.74, 0.66) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.82, 0.74, 0.64))
            m.set_shader_parameter(&"side_scale", 2.0)
            m.set_shader_parameter(&"side_fade", 14.0)
            m.set_shader_parameter(&"side_dark", 0.45)
            m.set_shader_parameter(&"moss", 0.25)
        &"iron":
            m = _block_material("rust_iron", "rust_iron")
            m.set_shader_parameter(&"local_space", true)
            m.set_shader_parameter(&"top_scale", 1.5)
            m.set_shader_parameter(&"side_scale", 1.0)
            m.set_shader_parameter(&"top_tint", Color(0.75, 0.62, 0.55))
            m.set_shader_parameter(&"side_tint", Color(0.6, 0.48, 0.42))
            m.set_shader_parameter(&"side_fade", 0.9)
            m.set_shader_parameter(&"side_dark", 0.35)
            m.set_shader_parameter(&"moss", 0.0)
            m.set_shader_parameter(&"variation", 0.1)
            m.set_shader_parameter(&"edge_width", 0.1)
            m.set_shader_parameter(&"emission_color", Color(1.0, 0.32, 0.08))
            m.set_shader_parameter(&"emission_rim", 0.9)
        &"cracked":
            m = _block_material("cracked", "cracked")
            m.set_shader_parameter(&"top_scale", 1.6)
            m.set_shader_parameter(&"side_scale", 1.6)
            m.set_shader_parameter(&"top_tint", Color(0.66, 0.56, 0.52) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.5, 0.42, 0.4) * tint)
            m.set_shader_parameter(&"side_fade", 1.0)
            m.set_shader_parameter(&"side_dark", 0.3)
            m.set_shader_parameter(&"emission_color", Color(0.7, 0.12, 0.05))
            m.set_shader_parameter(&"emission_cracks", 0.35)
            m.set_shader_parameter(&"moss", 0.0)
        &"breakable":
            m = _block_material("cracked", "cracked")
            m.set_shader_parameter(&"top_scale", 1.4)
            m.set_shader_parameter(&"side_scale", 1.4)
            m.set_shader_parameter(&"top_tint", Color(0.7, 0.6, 0.56))
            m.set_shader_parameter(&"side_tint", Color(0.55, 0.46, 0.44))
            m.set_shader_parameter(&"side_fade", 1.0)
            m.set_shader_parameter(&"emission_color", Color(0.9, 0.12, 0.05))
            m.set_shader_parameter(&"emission_cracks", 0.9)
            m.set_shader_parameter(&"moss", 0.0)
        &"rubble":
            m = _triplanar("rubble", 2.6)
            m.set_shader_parameter(&"tint", Color(0.5, 0.47, 0.47) * tint)
            m.set_shader_parameter(&"fade_dark", 0.08)
        &"column":
            m = _triplanar("masonry", 1.6)
            m.set_shader_parameter(&"tint", Color(0.62, 0.6, 0.6) * tint)
            m.set_shader_parameter(&"fade_top", 2.0)
            m.set_shader_parameter(&"fade_bottom", -0.2)
            m.set_shader_parameter(&"fade_dark", 0.55)
        &"rust":
            m = _triplanar("rust_iron", 0.8)
            m.set_shader_parameter(&"tint", Color(0.55, 0.45, 0.4))
            m.set_shader_parameter(&"fade_top", 1.0)
            m.set_shader_parameter(&"fade_bottom", 0.0)
            m.set_shader_parameter(&"fade_dark", 0.6)
        _:  # &"floor"
            m = _block_material("flagstone", "masonry")
            m.set_shader_parameter(&"top_tint", Color(0.76, 0.73, 0.66) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.44, 0.42, 0.43) * tint)
            m.set_shader_parameter(&"blood", 0.0)
    return m
