extends SceneTree
## Dev audit (DEC-054 follow-up): lists every MeshInstance3D in a 3D run that still renders with a
## plain untextured, lit StandardMaterial3D (or the default material) and is bigger than 0.5 m, with its path.
##   godot --headless --path . -s res://tools/dev/audit_materials.gd


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    GameSettings.persistence_enabled = false
    LevelLayout.classic = false
    RunState.full_3d = true
    RunState.new_run(77)
    change_scene_to_file("res://scenes/main.tscn")
    for i in 20:
        await process_frame
    var counts: Dictionary = {}
    for node: Node in current_scene.find_children("*", "MeshInstance3D", true, false):
        var mi: MeshInstance3D = node as MeshInstance3D
        if mi.mesh == null:
            continue
        var mat: Material = mi.material_override
        if mat == null and mi.mesh.get_surface_count() > 0:
            mat = mi.get_active_material(0)
        if mat is ShaderMaterial:
            continue
        if mat is StandardMaterial3D and ((mat as StandardMaterial3D).albedo_texture != null                 or (mat as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED):
            continue  # textured (GothicMaterials.standard) or a deliberate glow
        var size: Vector3 = mi.mesh.get_aabb().size * mi.global_transform.basis.get_scale()
        if maxf(size.x, maxf(size.y, size.z)) < 0.5:
            continue
        if not mi.is_visible_in_tree():
            continue
        var owner_node: Node = mi.get_parent()
        while owner_node != null and owner_node.get_script() == null:
            owner_node = owner_node.get_parent()
        if owner_node is CharacterBody3D:
            continue  # characters keep their own look
        var script_path: String = owner_node.get_script().resource_path.get_file() if owner_node else "-"
        var key: String = "%s <- %s | %s | %s" % [mi.name if not mi.name.begins_with("@") else "@", script_path, size.snapped(Vector3.ONE * 0.1), mat.resource_name if mat else "default"]
        counts[key] = int(counts.get(key, 0)) + 1
    for k: String in counts:
        print("%3d  %s" % [counts[k], k])
    RunState.full_3d = false
    RunState.end_run()
    quit()
