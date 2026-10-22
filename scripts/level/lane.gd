class_name Lane
extends RefCounted
## The play space's depth. Side view (default): a 4 m causeway the camera looks across, the
## player locked to z = 0. Full 3D (`Lane.full_3d`, the 3D run): every room is an open course
## (DEC-052, see LevelSection._course); `DEPTH_3D` is still the depth of the opening's
## causeway, its portcullis and checkpoint triggers. Set before the level builds; level pieces
## read it when they are created.

static var full_3d: bool = false

const SIDE_DEPTH: float = 4.0
const DEPTH_3D: float = 10.0


## Full depth of a floor or wall: `side` in the side view, the hall's depth in 3D.
static func depth(side: float = SIDE_DEPTH) -> float:
    return DEPTH_3D if full_3d else side


## Half the hall's depth (its open edge: past it you fall into the abyss).
static func half() -> float:
    return depth() * 0.5
