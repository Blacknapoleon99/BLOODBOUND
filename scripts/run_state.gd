class_name RunState
extends RefCounted
## The current roguelike run: its seed and the deck chosen in the draft / at altars.
## Static so it survives scene changes (draft → level → restart). When no run is active
## (e.g. the level scene is opened directly), the level falls back to the default deck.

const DRAFT_ROUNDS: int = 3
const OFFER_SIZE: int = 3

static var active: bool = false
static var seed_value: int = 0
static var deck: Array[CardData] = []
static var rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Starts a fresh run. A negative seed picks a random one.
static func new_run(run_seed: int = -1) -> void:
    if run_seed < 0:
        var r: RandomNumberGenerator = RandomNumberGenerator.new()
        r.randomize()
        run_seed = r.randi_range(1, 2147483646)
    seed_value = run_seed
    rng.seed = run_seed
    deck.clear()
    active = true


static func end_run() -> void:
    active = false
    deck.clear()


## Next random offer for this run, never repeating cards already in the deck when avoidable.
static func next_offer(count: int = OFFER_SIZE) -> Array[CardData]:
    var owned: Array = deck.map(func(c: CardData) -> StringName: return c.id)
    return CardPool.offer(rng, count, owned)


static func draft_done() -> bool:
    return deck.size() >= DRAFT_ROUNDS
