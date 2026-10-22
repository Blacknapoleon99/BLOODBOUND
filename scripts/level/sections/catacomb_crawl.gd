extends LevelSection
## Catacomb Crawl (Act 1, difficulty 2): Low catacomb tunnels (ceilings at 3 m: short hops only) infested with Bone Crawlers,
## with a pit between the tunnels.

const DIFFICULTY: int = 2


func _init() -> void:
    id = &"catacomb_crawl"
    title = "Catacomb Crawl"
    act = 1
    difficulty = DIFFICULTY
    width = 50.0
    _palette = Color(0.17, 0.16, 0.18)


func _design() -> void:
    ground(0.0, 22.0)
    block(8.0, 20.0, 3.0, 4.0, "Tunnel ceiling")
    enemy(&"crawler", 14.0, 6.0, 21.5)
    enemy(&"crawler", 18.0, 6.0, 21.5)
    ground(25.0, 44.0)
    secret_cellar(44.0, &"shards", 25)
    ground(46.0, 50.0)
    block(28.0, 40.0, 3.0, 4.0, "Tunnel ceiling")
    enemy(&"crawler", 33.0, 25.5, 41.0)
    enemy(&"crawler", 37.0, 25.5, 41.0)
    enemy(&"husk", 45.0, 41.0, 49.5)


## 3D course (DEC-052): two catacomb tunnels over a pit, read from three heights. TUNNELS
## (ground): under 3 m ceilings, crawlers in each (short hops only). ROOFS (high): up the steps
## onto the tunnel roofs, over a crumbling slab between them. CHUTE (south): the ossuary chute,
## low crawlspaces you crouch or slide through (a shard waits under the first). Off the paths:
## the shard cellar past the chute, and a wall-kick shaft to a perch in the north.
func _course() -> void:
    pads()
    route(&"tunnels")
    plat(17.0, 0.0, 14.0, 6.0, 0.0, "Catacomb tunnel", 1.5)
    plat(33.0, 0.0, 12.0, 6.0, 0.0, "Catacomb tunnel", 1.5)
    foe(&"crawler", 15.0, 0.0)
    foe(&"crawler", 20.0, 0.0)
    foe(&"crawler", 31.0, 0.0)
    foe(&"crawler", 35.0, 0.0)
    route(&"roofs")
    plat(8.0, 5.5, 4.0, 3.0, 1.4, "Catacomb step")
    plat(11.5, 5.0, 3.0, 3.0, 2.8, "Catacomb step")
    plat(17.5, 0.0, 11.0, 6.0, 4.0, "Tunnel roof", 1.0)
    crumble(25.5, 0.0, 4.0)
    plat(33.0, 0.0, 10.0, 6.0, 4.0, "Tunnel roof", 1.0)
    shard(33.0, 0.0, 4.0)
    route(&"chute")
    plat(14.0, 9.0, 8.0, 4.0, 0.0, "Ossuary chute")
    wall3(16.0, 9.0, 4.0, 4.0, 1.2, 3.0, "Chute roof")
    plat(26.0, 10.0, 12.0, 4.0, 0.0, "Ossuary chute")
    wall3(26.0, 10.0, 6.0, 4.0, 1.2, 2.2, "Chute roof")
    plat(37.0, 8.0, 6.0, 4.0, 0.0, "Ossuary chute")
    shard(16.0, 9.0, 0.0, 4)
    route(&"side")
    cellar(37.0, 15.0, 0.0, &"shards", 25)
    var base: int = plat(16.0, -9.0, 6.0, 6.0, 0.0, "Shaft floor")
    var perch: int = kick_shaft(18.0, -9.0, base, 6.0, true, "Kick shaft")
    shard(22.0, -9.0, platforms[perch].position.y, 5)
