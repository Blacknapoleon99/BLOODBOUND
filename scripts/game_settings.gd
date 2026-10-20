class_name GameSettings
extends RefCounted
## Player-facing accessibility/presentation options, persisted to user://settings.cfg.
## Gameplay code must never depend on these values (they only change presentation).

const DEFAULT_PATH: String = "user://settings.cfg"

## Automated tests switch this off so they never read or overwrite the player's real file
## (explicit non-default paths still work, for round-trip tests).
static var persistence_enabled: bool = true

## Replaces red blood with dark ash and fewer particles.
static var reduced_gore: bool = false
## 0 = no camera shake, 1 = default.
static var camera_shake: float = 1.0
## Brief global slow-down on hit. Disable for testing or comfort.
static var hitstop_enabled: bool = true
## The player swings automatically at enemies in reach (holding J still chains the combo).
static var auto_attack: bool = true


static func load_settings(path: String = DEFAULT_PATH) -> void:
    if path == DEFAULT_PATH and not persistence_enabled:
        return
    var config: ConfigFile = ConfigFile.new()
    if config.load(path) != OK:
        return
    reduced_gore = bool(config.get_value("presentation", "reduced_gore", reduced_gore))
    camera_shake = clampf(float(config.get_value("presentation", "camera_shake", camera_shake)), 0.0, 1.0)
    hitstop_enabled = bool(config.get_value("presentation", "hitstop", hitstop_enabled))
    auto_attack = bool(config.get_value("gameplay", "auto_attack", auto_attack))


static func save_settings(path: String = DEFAULT_PATH) -> Error:
    if path == DEFAULT_PATH and not persistence_enabled:
        return OK
    var config: ConfigFile = ConfigFile.new()
    config.set_value("presentation", "reduced_gore", reduced_gore)
    config.set_value("presentation", "camera_shake", camera_shake)
    config.set_value("presentation", "hitstop", hitstop_enabled)
    config.set_value("gameplay", "auto_attack", auto_attack)
    return config.save(path)


static func reset_defaults() -> void:
    reduced_gore = false
    camera_shake = 1.0
    hitstop_enabled = true
    auto_attack = true
