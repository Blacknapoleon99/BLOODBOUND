class_name CreatureMaterials
extends RefCounted
## Materials for the full-3D creatures (DEC-064). The creature GLBs (tools/blender/
## build_creatures.py) carry geometry, a cavity shade in vertex colour and role-named surfaces;
## this maps each role to a material: wet flayed muscle and pale corpse skin from the generated
## sets in assets/models/enemies/creatures/tex/, bone, iron, wax and cloth from the gothic scans.
## Object-space triplanar (each part's own space), so moving limbs never swim through their
## texture. Plain StandardMaterial3D: Compatibility and Forward+ both render it.
## Glowing roles (eyes, the mourner's split, the lantern glass, flames) are per-creature copies
## so a telegraph can flare one creature's glow without touching the others.

const TEX: String = "res://assets/models/enemies/creatures/tex/"
## Roles whose material each rig gets its own copy of (animated emission).
const INSTANCED: Array[StringName] = [&"glow", &"glow_pale", &"glass", &"flame"]

static var _cache: Dictionary = {}


static func material(role: StringName) -> Material:
    if _cache.has(role):
        return _cache[role]
    var m: StandardMaterial3D
    match role:
        &"muscle":
            m = _pbr("muscle", Color(1.0, 0.86, 0.86), 0.3)
            m.roughness = 0.85
            m.metallic_specular = 0.75
            m.normal_scale = 1.4
            m.clearcoat_enabled = true
            m.clearcoat = 0.55
            m.clearcoat_roughness = 0.25
        &"flesh", &"seam":
            m = _pbr("muscle", Color(0.62, 0.22, 0.24) if role == &"flesh" else Color(0.5, 0.16, 0.16), 0.22)
            m.roughness = 0.45
            m.metallic_specular = 0.85
            m.clearcoat_enabled = true
            m.clearcoat = 0.8
            m.clearcoat_roughness = 0.15
        &"lips":
            m = _pbr("muscle", Color(0.62, 0.3, 0.34), 0.15)
            m.roughness = 0.5
            m.metallic_specular = 0.8
        &"sinew":
            m = _pbr("skin", Color(0.86, 0.6, 0.55), 0.18)
            m.roughness = 0.55
            m.metallic_specular = 0.7
        &"skin", &"skin_b", &"porcelain":
            var tint: Color = {&"skin": Color(0.56, 0.57, 0.47), &"skin_b": Color(0.47, 0.34, 0.37), &"porcelain": Color(0.9, 0.88, 0.86)}[role]
            m = _pbr("skin", tint, 0.7)
            m.normal_scale = 0.45
            m.roughness = 0.75
            m.metallic_specular = 0.6
            if role == &"porcelain":
                m.emission_enabled = true
                m.emission = Color(0.55, 0.6, 0.7)
                m.emission_energy_multiplier = 0.12
                m.roughness = 0.6
                m.metallic_specular = 0.7
                m.rim_enabled = true
                m.rim = 0.5
                m.rim_tint = 0.2
        &"bone", &"teeth":
            m = GothicMaterials.standard("bone", Color(0.92, 0.86, 0.74) if role == &"bone" else Color(0.95, 0.88, 0.62), 0.25, false)
            m.vertex_color_use_as_albedo = true
            if role == &"teeth":
                m.roughness = 0.6
        &"iron", &"blade":
            m = GothicMaterials.standard("rust_iron", Color(0.62, 0.52, 0.48) if role == &"iron" else Color(0.62, 0.64, 0.68), 0.35, false)
            m.vertex_color_use_as_albedo = true
            if role == &"blade":
                m.metallic_texture = null
                m.metallic = 0.85
                m.roughness = 0.55
        &"wax":
            m = GothicMaterials.standard("wax", Color(0.62, 0.61, 0.6), 0.3, false)
            m.roughness_texture = null
            m.roughness = 0.82
            m.metallic_specular = 0.35
            m.vertex_color_use_as_albedo = true
            m.emission_enabled = true
            m.emission = Color(0.35, 0.16, 0.05) * 0.1
        &"dress", &"cloth_black", &"apron":
            var tint2: Color = {&"dress": Color(0.15, 0.14, 0.17), &"cloth_black": Color(0.09, 0.085, 0.085), &"apron": Color(0.3, 0.12, 0.09)}[role]
            m = GothicMaterials.standard("cloth", tint2, 0.4, false)
            m.vertex_color_use_as_albedo = true
            m.cull_mode = BaseMaterial3D.CULL_DISABLED
            if role == &"dress":
                m.rim_enabled = true
                m.rim = 0.35
                m.rim_tint = 0.5
        &"lace":
            m = StandardMaterial3D.new()
            m.albedo_texture = _tex("lace_diff.png")
            m.albedo_color = Color(0.6, 0.58, 0.64)
            m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
            m.alpha_scissor_threshold = 0.45
            m.cull_mode = BaseMaterial3D.CULL_DISABLED
            m.uv1_triplanar = true
            m.uv1_scale = Vector3.ONE / 0.32
            m.roughness = 0.9
            m.rim_enabled = true
            m.rim = 0.4
        &"blood":
            m = StandardMaterial3D.new()
            m.albedo_color = Color(0.2, 0.0, 0.01)
            m.roughness = 0.06
            m.metallic = 0.2
            m.metallic_specular = 0.9
        &"stitch":
            m = StandardMaterial3D.new()
            m.albedo_color = Color(0.05, 0.04, 0.035)
            m.roughness = 0.75
        &"glow":
            m = _emissive(Color(0.5, 0.05, 0.02), Color(1.0, 0.22, 0.06), 2.6)
        &"glow_pale":
            m = _emissive(Color(0.8, 0.85, 0.95), Color(0.7, 0.82, 1.0), 3.5)
            m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        &"glass":
            m = _emissive(Color(0.35, 0.3, 0.15), Color(1.0, 0.72, 0.32), 1.6)
            m.roughness = 0.1
            m.metallic_specular = 1.0
        &"flame":
            m = _emissive(Color(1.0, 0.7, 0.3), Color(1.0, 0.5, 0.15), 3.2)
            m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _:  # dark and anything unknown: a wet black cavity
            m = StandardMaterial3D.new()
            m.albedo_color = Color(0.025, 0.012, 0.012)
            m.roughness = 0.4
    _cache[role] = m
    return m


## A fresh copy for one creature (glows it animates).
static func instanced(role: StringName) -> Material:
    return material(role).duplicate()


static func _pbr(set_name: String, tint: Color, scale: float) -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_texture = _tex(set_name + "_diff.jpg")
    m.albedo_color = tint
    m.vertex_color_use_as_albedo = true
    m.normal_enabled = true
    m.normal_texture = _tex(set_name + "_nor.jpg")
    m.ao_enabled = true
    m.ao_texture = _tex(set_name + "_arm.jpg")
    m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    m.ao_light_affect = 0.4
    m.roughness_texture = _tex(set_name + "_arm.jpg")
    m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    m.uv1_triplanar = true
    m.uv1_world_triplanar = false
    m.uv1_triplanar_sharpness = 4.0
    m.uv1_scale = Vector3.ONE / scale
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return m


static func _emissive(albedo: Color, glow: Color, energy: float) -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = albedo
    m.roughness = 0.2
    m.emission_enabled = true
    m.emission = glow
    m.emission_energy_multiplier = energy
    return m


static func _tex(file: String) -> Texture2D:
    var path: String = TEX + file
    return load(path) as Texture2D if ResourceLoader.exists(path) else null
