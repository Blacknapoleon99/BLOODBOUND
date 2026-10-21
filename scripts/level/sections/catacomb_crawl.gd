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
