## A full-screen colour grade: a subtle warm wash plus a soft vignette, sitting
## above the world but below the UI. Unifies the scene and adds depth, like the
## warm, slightly-darkened-edges look of the source's jungle stages.
class_name Grade
extends CanvasLayer

const VIGNETTE := preload("res://assets/sprites/vignette.png")

func _ready() -> void:
	layer = 2  # above the world (0), below the caste panel / HUD (5 / 6)

	var warm := ColorRect.new()
	warm.color = Color(1.0, 0.82, 0.52, 0.06)
	warm.set_anchors_preset(Control.PRESET_FULL_RECT)
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(warm)

	var vig := TextureRect.new()
	vig.texture = VIGNETTE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
