class_name InputBindings
extends RefCounted
## Single source of default input bindings. Gameplay code reads only action names,
## so a future rebinding menu just edits InputMap (or project settings) — no code changes.
## Actions already defined in Project Settings are left untouched.

const KEYS: Dictionary = {
    &"move_left": [KEY_A, KEY_LEFT],
    &"move_right": [KEY_D, KEY_RIGHT],
    &"move_forward": [KEY_W, KEY_UP],
    &"move_back": [KEY_S, KEY_DOWN],
    &"jump": [KEY_SPACE],
    &"attack": [KEY_J],
    &"heavy_attack": [KEY_L],
    &"dodge": [KEY_K, KEY_SHIFT],
    &"crouch": [KEY_CTRL, KEY_C],
    &"interact": [KEY_E],
    &"restart": [KEY_R],
    &"pause": [KEY_ESCAPE, KEY_P],
    &"card_1": [KEY_1],
    &"card_2": [KEY_2],
    &"card_3": [KEY_3],
    &"lock_on": [KEY_Q],
    &"lock_next": [KEY_TAB],
    &"look_left": [],
    &"look_right": [],
    &"look_up": [],
    &"look_down": [],
}

const PAD_BUTTONS: Dictionary = {
    &"jump": [JOY_BUTTON_A],
    &"attack": [JOY_BUTTON_X],
    &"heavy_attack": [JOY_BUTTON_RIGHT_SHOULDER],
    &"dodge": [JOY_BUTTON_B],
    &"crouch": [JOY_BUTTON_LEFT_SHOULDER],
    &"interact": [JOY_BUTTON_Y],
    &"restart": [JOY_BUTTON_BACK],
    &"pause": [JOY_BUTTON_START],
    &"card_1": [JOY_BUTTON_DPAD_LEFT],
    &"card_2": [JOY_BUTTON_DPAD_UP],
    &"card_3": [JOY_BUTTON_DPAD_RIGHT],
    &"lock_on": [JOY_BUTTON_RIGHT_STICK],
}

## Mouse: left click = light attack, right click = heavy. While a card is armed for targeting,
## CardTargeting consumes clicks first (left picks the target, right cancels).
const MOUSE_BUTTONS: Dictionary = {
    &"attack": [MOUSE_BUTTON_LEFT],
    &"heavy_attack": [MOUSE_BUTTON_RIGHT],
    &"lock_on": [MOUSE_BUTTON_MIDDLE],
    &"lock_next": [MOUSE_BUTTON_WHEEL_UP],
}

## Player 2 (local co-op) on the keyboard's right side, when no gamepad is free for them.
const P2_KEYS: Dictionary = {
    &"move_left": [KEY_LEFT],
    &"move_right": [KEY_RIGHT],
    &"move_forward": [],
    &"move_back": [KEY_DOWN],
    &"jump": [KEY_UP],
    &"attack": [KEY_KP_4],
    &"heavy_attack": [KEY_KP_5],
    &"dodge": [KEY_KP_6],
    &"crouch": [KEY_KP_0],
    &"interact": [KEY_KP_ENTER],
    &"card_1": [KEY_KP_1],
    &"card_2": [KEY_KP_2],
    &"card_3": [KEY_KP_3],
}
const PLAYER_ACTIONS: Array[StringName] = [
    &"move_left", &"move_right", &"move_forward", &"move_back", &"jump", &"attack",
    &"heavy_attack", &"dodge", &"crouch", &"interact", &"card_1", &"card_2", &"card_3",
]

## [action, axis, direction]
const PAD_AXES: Array = [
    [&"move_left", JOY_AXIS_LEFT_X, -1.0],
    [&"move_right", JOY_AXIS_LEFT_X, 1.0],
    [&"move_forward", JOY_AXIS_LEFT_Y, -1.0],
    [&"move_back", JOY_AXIS_LEFT_Y, 1.0],
    [&"look_left", JOY_AXIS_RIGHT_X, -1.0],
    [&"look_right", JOY_AXIS_RIGHT_X, 1.0],
    [&"look_up", JOY_AXIS_RIGHT_Y, -1.0],
    [&"look_down", JOY_AXIS_RIGHT_Y, 1.0],
]


static func ensure_defaults() -> void:
    for action: StringName in KEYS:
        if InputMap.has_action(action):
            continue
        InputMap.add_action(action, 0.25)
        for code: Key in KEYS[action]:
            var key_event: InputEventKey = InputEventKey.new()
            key_event.physical_keycode = code
            InputMap.action_add_event(action, key_event)
        for button: JoyButton in PAD_BUTTONS.get(action, []):
            var pad_event: InputEventJoypadButton = InputEventJoypadButton.new()
            pad_event.button_index = button
            InputMap.action_add_event(action, pad_event)
        for mouse_button: MouseButton in MOUSE_BUTTONS.get(action, []):
            var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
            mouse_event.button_index = mouse_button
            InputMap.action_add_event(action, mouse_event)
        for entry: Array in PAD_AXES:
            if entry[0] == action:
                var axis_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
                axis_event.axis = entry[1]
                axis_event.axis_value = entry[2]
                InputMap.action_add_event(action, axis_event)


## Solo: player 1 gets everything (keyboard, mouse, any gamepad).
## Co-op: player 1 = keyboard + mouse (+ gamepad #1 if two pads are connected); player 2 =
## the other gamepad (pad #1 when only one is connected) + the right-side keys (P2_KEYS).
## Player 2's actions are the same names prefixed "p2_" (see Player.act / CardSystem.slot_action).
static func configure_players(coop: bool) -> void:
    ensure_defaults()
    var pads: Array[int] = Input.get_connected_joypads()
    var p1_pad: int = pads[0] if coop and pads.size() >= 2 else (-1 if not coop else -2)
    var p2_pad: int = (pads[1] if pads.size() >= 2 else (pads[0] if pads.size() == 1 else 0)) if coop else -2
    for action: StringName in PLAYER_ACTIONS:
        # Player 1: rebuild the pad part of the action for the chosen device (-1 = any, -2 = none).
        for event: InputEvent in InputMap.action_get_events(action):
            if event is InputEventJoypadButton or event is InputEventJoypadMotion:
                InputMap.action_erase_event(action, event)
        if coop:
            # Arrow keys belong to player 2 in co-op.
            for event: InputEvent in InputMap.action_get_events(action):
                if event is InputEventKey and (event as InputEventKey).physical_keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
                    InputMap.action_erase_event(action, event)
        elif action in KEYS:
            for code: Key in KEYS[action]:
                if code in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
                    var restore: InputEventKey = InputEventKey.new()
                    restore.physical_keycode = code
                    if not InputMap.action_has_event(action, restore):
                        InputMap.action_add_event(action, restore)
        if p1_pad != -2:
            _add_pad_events(action, action, p1_pad)
        # Player 2.
        var p2: StringName = StringName("p2_" + String(action))
        if InputMap.has_action(p2):
            InputMap.erase_action(p2)
        if coop:
            InputMap.add_action(p2, 0.25)
            for code: Key in P2_KEYS.get(action, []):
                var key_event: InputEventKey = InputEventKey.new()
                key_event.physical_keycode = code
                InputMap.action_add_event(p2, key_event)
            _add_pad_events(action, p2, p2_pad)


static func _add_pad_events(source: StringName, target: StringName, device: int) -> void:
    for button: JoyButton in PAD_BUTTONS.get(source, []):
        var pad_event: InputEventJoypadButton = InputEventJoypadButton.new()
        pad_event.button_index = button
        pad_event.device = device
        InputMap.action_add_event(target, pad_event)
    for entry: Array in PAD_AXES:
        if entry[0] == source:
            var axis_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
            axis_event.axis = entry[1]
            axis_event.axis_value = entry[2]
            axis_event.device = device
            InputMap.action_add_event(target, axis_event)
