class_name ClimbWall
extends StaticBody3D
## A climbable block (3D platformer phase 2). Not every wall climbs: only these, marked by rows of
## bone handholds on their sides so a climb route reads at a glance. The PlatformerMotor climbs
## any face of a body in group "climbable": 8-way movement, leaps along the face, a jump off
## backwards, a mantle over the top.


static func create(label: String, center: Vector3, size: Vector3, color: Color = Color(0.3, 0.26, 0.28)) -> ClimbWall:
    var wall: ClimbWall = ClimbWall.new()
    wall.name = label
    wall.position = center
    wall.add_to_group(&"climbable")
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape.shape = box
    wall.add_child(shape)
    var body_mesh: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    body_mesh.mesh = mesh
    body_mesh.material_override = GothicMaterials.block(&"climb", color)  # pale block masonry (DEC-054)
    wall.add_child(body_mesh)
    wall.add_child(_handholds(size))
    return wall


## Staggered bone studs on the four vertical faces (one MultiMesh: cheap however tall the wall).
static func _handholds(size: Vector3) -> MultiMeshInstance3D:
    var stud: BoxMesh = BoxMesh.new()
    stud.size = Vector3(0.32, 0.12, 0.12)
    var bone: StandardMaterial3D = StandardMaterial3D.new()
    bone.albedo_color = Color(0.82, 0.77, 0.66)
    bone.emission_enabled = true
    bone.emission = Color(0.35, 0.28, 0.18) * 0.35
    stud.material = bone
    var transforms: Array[Transform3D] = []
    var rows: int = maxi(1, int(size.y / 0.6))
    for face: int in 4:
        var normal: Vector3 = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT][face]
        var span: float = size.x if face < 2 else size.z
        var depth: float = size.z if face < 2 else size.x
        var columns: int = maxi(1, int(span / 0.9))
        var along: Vector3 = Vector3.RIGHT if face < 2 else Vector3.BACK
        var facing: Basis = Basis(Vector3.UP, 0.0 if face < 2 else PI * 0.5)
        for r in rows:
            for c in columns:
                var offset: float = (c + (0.25 if r % 2 == 0 else 0.75)) * span / columns - span * 0.5
                if absf(offset) > span * 0.5 - 0.15:
                    continue
                var at: Vector3 = along * offset + Vector3.UP * (-size.y * 0.5 + (r + 0.5) * size.y / rows) + normal * (depth * 0.5 + 0.05)
                transforms.append(Transform3D(facing, at))
    var multi: MultiMesh = MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = stud
    multi.instance_count = transforms.size()
    for i in transforms.size():
        multi.set_instance_transform(i, transforms[i])
    var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
    node.name = "Handholds"
    node.multimesh = multi
    return node
