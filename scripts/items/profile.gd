class_name Profile
extends RefCounted
## What persists between runs: owned items (the stash), what is equipped in each slot, and
## spoils waiting to be claimed in the Armory (earned by defeating the Bishop; a new profile
## starts with one). Saved to user://profile.cfg unless GameSettings.persistence_enabled is off.

const DEFAULT_PATH: String = "user://profile.cfg"

static var stash: Array[StringName] = []
static var equipped: Dictionary = {}  # ItemData.Slot -> item id (&"" = empty)
static var pending_spoils: int = 1
static var _loaded: bool = false


static func reset() -> void:
    stash = ItemPool.STARTERS.duplicate()
    equipped = {ItemData.Slot.WEAPON: &"rusted_blade", ItemData.Slot.ARMOR: &"pilgrim_rags", ItemData.Slot.CHARM: &""}
    pending_spoils = 1
    _loaded = true


## Loads once per session (or resets to a fresh profile when there is no save).
static func ensure_loaded() -> void:
    if not _loaded:
        load_from(DEFAULT_PATH)


## Replaces the in-memory profile with the saved one at `path` (a fresh profile if none).
static func load_from(path: String) -> void:
    reset()
    if path == DEFAULT_PATH and not GameSettings.persistence_enabled:
        return
    var config: ConfigFile = ConfigFile.new()
    if config.load(path) != OK:
        return
    stash.clear()
    for id: String in config.get_value("items", "stash", PackedStringArray()):
        if ItemPool.by_id(StringName(id)) != null and not stash.has(StringName(id)):
            stash.append(StringName(id))
    for starter: StringName in ItemPool.STARTERS:
        if not stash.has(starter):
            stash.append(starter)
    for slot: int in [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.CHARM]:
        var id: StringName = StringName(config.get_value("equipped", ItemData.slot_name(slot), equipped[slot]))
        var item: ItemData = ItemPool.by_id(id)
        equipped[slot] = id if item != null and item.slot == slot and stash.has(id) else equipped[slot]
    pending_spoils = int(config.get_value("items", "pending_spoils", pending_spoils))


static func save(path: String = DEFAULT_PATH) -> Error:
    if path == DEFAULT_PATH and not GameSettings.persistence_enabled:
        return OK
    var config: ConfigFile = ConfigFile.new()
    config.set_value("items", "stash", PackedStringArray(stash.map(func(id: StringName) -> String: return String(id))))
    config.set_value("items", "pending_spoils", pending_spoils)
    for slot: int in equipped:
        config.set_value("equipped", ItemData.slot_name(slot), String(equipped[slot]))
    return config.save(path)


static func add_item(id: StringName) -> void:
    ensure_loaded()
    if not stash.has(id) and ItemPool.by_id(id) != null:
        stash.append(id)


## Equips an owned item into its slot. Returns false for unknown or unowned items.
static func equip(id: StringName) -> bool:
    ensure_loaded()
    var item: ItemData = ItemPool.by_id(id)
    if item == null or not stash.has(id):
        return false
    equipped[item.slot] = id
    return true


static func item_in(slot: ItemData.Slot) -> ItemData:
    ensure_loaded()
    return ItemPool.by_id(equipped.get(slot, &""))


static func equipped_items() -> Array[ItemData]:
    var items: Array[ItemData] = []
    for slot: int in [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.CHARM]:
        var item: ItemData = item_in(slot)
        if item != null:
            items.append(item)
    return items
