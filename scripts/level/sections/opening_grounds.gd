class_name OpeningGrounds
extends LevelSection
## The opening as a tutorial course (3D run only, DEC-052). The causeway itself, the plagued
## soldier, the portcullis and the gate ossuary stay as main.gd builds them; around them, off
## both sides of the causeway, float optional practice stations, each with a carved hint and a
## Bone Shard (or a cache) as its reward:
##   north: JUMP (rising columns), TRIPLE JUMP (a 3 m ledge past a run-up), LONG JUMP (a far
##          island), LEDGE GRAB (a 3 m wall by the gate);
##   south: CLIMB (a handhold wall), GROUND POUND (a cellar), WALL KICK (a shaft).
## Built in world coordinates (origin_x = 0). Not one of the run's rooms: no pads, no
## checkpoint (the opening has its own). Every station stays well back from the portcullis, so
## no perch is a springboard past the plagued soldier.

func _init() -> void:
    id = &"opening_grounds"
    title = "The Causeway"
    act = 0
    width = 37.2
    _palette = Color(0.2, 0.2, 0.25)


## Builds the stations (no pads, no checkpoint).
func build_grounds() -> void:
    origin_x = 0.0
    name = "Opening grounds"
    _course()
    _finish_course()
    Backdrop3D.attach(self)  # background world (DEC-055)


func _course() -> void:
    # The causeway main.gd builds, recorded so the validator knows where you stand.
    _platform(Rect2(-19.0, 0.0, 12.0, 0.0), Vector2(-5.0, 5.0))
    _platform(Rect2(-6.0, 0.35, 3.0, 0.0), Vector2(-5.0, 5.0))
    _platform(Rect2(-1.5, 0.0, 11.0, 0.0), Vector2(-5.0, 5.0))
    _platform(Rect2(9.2, 0.0, 9.0, 0.0), Vector2(-5.0, 5.0))
    route(&"side")
    # North: jump, triple jump, long jump, ledge grab.
    pillar(-14.0, -7.5, 2.5, 1.2, "Jump column")
    pillar(-11.0, -9.5, 2.5, 2.4, "Jump column")
    pillar(-8.0, -11.5, 2.5, 3.6, "Jump column")
    shard(-8.0, -11.5, 3.6)
    hint("JUMP\nSpace (hold for height)", -14.0, -7.5, 1.2)
    plat(-1.0, -10.0, 10.0, 5.0, 0.0, "Run-up")
    plat(6.5, -10.0, 3.0, 4.0, 3.0, "Triple ledge", 3.0)
    shard(6.5, -10.0, 3.0)
    hint("TRIPLE JUMP\nrun, and jump again as you land, twice", 3.0, -10.0, 0.0)
    plat(-1.0, -20.0, 4.0, 4.0, 0.0, "Far island")
    shard(-1.0, -20.0, 0.0, 5)
    hint("LONG JUMP\nrun, Ctrl, Space", -1.0, -12.0, 0.0)
    plat(-17.5, -6.5, 3.0, 3.0, 3.0, "Grab wall", 3.0)
    shard(-17.5, -6.5, 3.0)
    hint("LEDGE GRAB\njump at the wall: hang, then W", -17.5, -3.5, 0.0)
    # South: climb, ground pound, wall kick.
    climb(-12.0, 7.0, 4.0, 2.0, -3.0, 6.0, "Handhold wall")
    shard(-12.0, 7.0, 6.0, 5)
    hint("CLIMB\njump into the handholds, WASD to climb", -15.5, 4.0, 0.0)
    cellar(2.0, 9.0, 0.0, &"shards", 15)
    hint("GROUND POUND\njump, then Ctrl: smash the cracked floor", 2.0, 5.0, 0.0)
    var base: int = plat(9.5, 9.5, 6.0, 5.0, 0.0, "Shaft floor")
    var top: int = kick_shaft(9.5, 9.5, base, 6.0, false, "Kick shaft")
    shard(9.5, 13.5, platforms[top].position.y, 5)
    hint("WALL KICK\njump into a wall, Space as you touch it", 9.5, 6.0, 0.0)
