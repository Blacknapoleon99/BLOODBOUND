class_name ClimbWall
extends StaticBody3D
## A climbable block (3D platformer phase 2). Not every wall climbs: only these, marked by rows of
## bone handholds on their sides so a climb route reads at a glance. The PlatformerMotor climbs
## any face of a body in group "climbable": 8-way movement, leaps along the face, a jump off
## backwards, a mantle over the top.


## `visual` false: the caller draws it (a LevelSection adds it to the room's kit batch).
static func create(label: String, center: Vector3, size: Vector3, color: Color = Color(0.3, 0.26, 0.28), visual: bool = true) -> ClimbWall:
    var wall: ClimbWall = ClimbWall.new()
    wall.name = label
    wall.position = center
    wall.add_to_group(&"climbable")
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape.shape = box
    wall.add_child(shape)
    if visual:
        # Pale masonry with carved corbel-and-bone handholds (DEC-056).
        var kit: GothicKit.Batch = GothicKit.Batch.new()
        kit.offset = center
        kit.tint = color
        kit.add_box(Vector3.ZERO, size, &"climb", label)
        kit.add_handholds(Vector3.ZERO, size)
        kit.commit(wall, "Kit")
        if not GothicKit.available():
            wall.add_child(_handholds(size))
    return wall


## Fallback (no kit GLB): staggered bone studs on the four vertical faces (one MultiMesh).
static func _handholds(size: Vector3) -> MultiMeshInstance3D:
    var stud: BoxMesh = BoxMesh.new()
    stud.size = Vector3(0.32, 0.12, 0.12)
    var bone: StandardMaterial3D = StandardMaterial3D.new()
    bone.albedo_color = Color(0.82, 0.77, 0.66)
    bone.emission_enabled = true
    bone.emission = Color(0.35, 0.28, 0.18) * 0.35
    stud.material = bone
    var transforms: Array[Transform3D] = GothicKit.handhold_transforms(size)
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
