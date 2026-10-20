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
    &"dodge": [KEY_K, KEY_SHIFT],
    &"interact": [KEY_E],
    &"restart": [KEY_R],
}

const PAD_BUTTONS: Dictionary = {
    &"jump": [JOY_BUTTON_A],
    &"attack": [JOY_BUTTON_X],
    &"dodge": [JOY_BUTTON_B],
    &"interact": [JOY_BUTTON_Y],
    &"restart": [JOY_BUTTON_START],
}

## [action, axis, direction]
const PAD_AXES: Array = [
    [&"move_left", JOY_AXIS_LEFT_X, -1.0],
    [&"move_right", JOY_AXIS_LEFT_X, 1.0],
    [&"move_forward", JOY_AXIS_LEFT_Y, -1.0],
    [&"move_back", JOY_AXIS_LEFT_Y, 1.0],
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
        for entry: Array in PAD_AXES:
            if entry[0] == action:
                var axis_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
                axis_event.axis = entry[1]
                axis_event.axis_value = entry[2]
                InputMap.action_add_event(action, axis_event)
