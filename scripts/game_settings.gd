class_name GameSettings
extends RefCounted
## Player-facing accessibility/presentation options. In-memory for now; a settings menu
## and persistence arrive with M6. Gameplay code must never depend on these values.

## Replaces red blood with dark ash and fewer particles.
static var reduced_gore: bool = false
## 0 = no camera shake, 1 = default.
static var camera_shake: float = 1.0
## Brief global slow-down on hit. Disable for testing or comfort.
static var hitstop_enabled: bool = true
