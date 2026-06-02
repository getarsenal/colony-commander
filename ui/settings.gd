## Tiny persisted settings singleton (autoload "Settings"). Holds the on-screen
## UI scale so the player can size the icons/buttons to their device, saved to
## user:// so it sticks between sessions.
extends Node

const PATH := "user://settings.cfg"
const MIN := 0.45
const MAX := 1.4

var ui_scale := 1.0

func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		ui_scale = clampf(float(c.get_value("ui", "scale", 1.0)), MIN, MAX)
	else:
		# first run: phones want big touch targets; desktop/mouse wants smaller
		ui_scale = 1.0 if DisplayServer.is_touchscreen_available() else 0.65

func set_ui_scale(s: float) -> void:
	ui_scale = clampf(s, MIN, MAX)
	var c := ConfigFile.new()
	c.set_value("ui", "scale", ui_scale)
	c.save(PATH)
