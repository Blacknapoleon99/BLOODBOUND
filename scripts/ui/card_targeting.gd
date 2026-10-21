class_name CardTargeting
extends Node
## Mouse play for Bloodbound Cards (keys 1-3 still auto-target).
## - Click a card: self/telegraph cards (Grave Shield, Ritual Chains) play at once; an
##   enemy-targeting card (Blood Spear) is ARMED: its slot is outlined, the cursor becomes a
##   crosshair, and the next left-click in the world picks the target.
## - While armed: left-click near an enemy fires at it (validated by CardSystem, which explains
##   any refusal); a click on nothing — or on the Bishop's body, which is never a target — keeps
##   the card armed and says why. Right-click, clicking the same card again, or 8 s idle cancels.

signal hint(text: String)

## How close (in screen pixels) a click must land to an enemy's aim point to select it.
const PICK_RADIUS_PX: float = 90.0
const ARM_TIMEOUT: float = 8.0

var cards: CardSystem
var ui: CardHandUI
var camera: Camera3D
var boss: Node3D
var armed_slot: int = -1
var _armed_left: float = 0.0


static func create(card_system: CardSystem, hand_ui: CardHandUI, view_camera: Camera3D, bishop: Node3D) -> CardTargeting:
    var targeting: CardTargeting = CardTargeting.new()
    targeting.name = "CardTargeting"
    targeting.cards = card_system
    targeting.ui = hand_ui
    targeting.camera = view_camera
    targeting.boss = bishop
    hand_ui.slot_clicked.connect(targeting._on_slot_clicked)
    card_system.card_played.connect(func(_c: CardData, _s: int) -> void: targeting.disarm())
    return targeting


func _process(delta: float) -> void:
    if armed_slot < 0:
        return
    _armed_left -= delta
    if _armed_left <= 0.0:
        disarm()


func disarm() -> void:
    armed_slot = -1
    ui.armed_slot = -1
    Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _on_slot_clicked(slot: int) -> void:
    var card: CardData = cards.deck.card_in_slot(slot)
    if card == null:
        return
    if armed_slot == slot:
        disarm()
        return
    if card.targeting == CardData.Targeting.ENEMY or card.targeting == CardData.Targeting.BOSS_WEAK_POINT:
        armed_slot = slot
        ui.armed_slot = slot
        _armed_left = ARM_TIMEOUT
        Input.set_default_cursor_shape(Input.CURSOR_CROSS)
        hint.emit("%s ready — click a target (right-click to cancel)" % card.display_name)
    else:
        disarm()
        cards.play_slot(slot)


func _unhandled_input(event: InputEvent) -> void:
    if armed_slot < 0:
        return
    var mb: InputEventMouseButton = event as InputEventMouseButton
    if mb == null or not mb.pressed:
        return
    get_viewport().set_input_as_handled()
    if mb.button_index == MOUSE_BUTTON_RIGHT:
        disarm()
        hint.emit("Targeting cancelled.")
        return
    if mb.button_index != MOUSE_BUTTON_LEFT:
        return
    _armed_left = ARM_TIMEOUT
    var target: Hurtbox = pick_hurtbox(mb.position)
    if target != null:
        var result: StringName = cards.play_slot(armed_slot, target)
        if result == &"queued":
            disarm()
        return  # on success card_played disarms; on refusal CardSystem/HUD explain, stay armed
    if _over_boss_body(mb.position):
        hint.emit("The Hollow Bishop can only be wounded at the glowing stigmata on its fallen hand.")
    else:
        hint.emit("No target there — click an enemy (right-click to cancel).")


## Nearest enemy hurtbox to a screen point, within PICK_RADIUS_PX. Sealed weak points are
## included on purpose, so clicking one gets the "not exposed" explanation instead of a miss.
func pick_hurtbox(screen_pos: Vector2) -> Hurtbox:
    var best: Hurtbox = null
    var best_px: float = PICK_RADIUS_PX
    for node: Node in get_tree().get_nodes_in_group(&"hurtboxes"):
        var hurtbox: Hurtbox = node as Hurtbox
        if hurtbox == null or hurtbox.team == &"player" or hurtbox.is_in_group(&"no_card_target") or hurtbox.health == null or hurtbox.health.is_dead():
            continue
        var shape: CollisionShape3D = hurtbox.get_child(0) as CollisionShape3D
        var aim: Vector3 = shape.global_position if shape else hurtbox.global_position
        if camera.is_position_behind(aim):
            continue
        var px: float = camera.unproject_position(aim).distance_to(screen_pos)
        if px < best_px:
            best = hurtbox
            best_px = px
    return best


## Rough screen-space silhouette of the Bishop (robe, ribs and skull), for a helpful message.
func _over_boss_body(screen_pos: Vector2) -> bool:
    if boss == null or not boss.visible:
        return false
    var base: Vector3 = boss.global_position
    var top: Vector2 = camera.unproject_position(base + Vector3(0.0, 17.0, 0.0))
    var bottom: Vector2 = camera.unproject_position(base + Vector3(0.0, -8.0, 0.0))
    var left: Vector2 = camera.unproject_position(base + Vector3(-5.0, 6.0, 0.0))
    var right: Vector2 = camera.unproject_position(base + Vector3(5.0, 6.0, 0.0))
    return screen_pos.x >= left.x and screen_pos.x <= right.x and screen_pos.y >= top.y and screen_pos.y <= bottom.y


func _exit_tree() -> void:
    Input.set_default_cursor_shape(Input.CURSOR_ARROW)  # never leave the crosshair behind
