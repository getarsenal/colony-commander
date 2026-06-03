## Title screen: our original "Colony Commander" emblem over the live world,
## shown at launch. Pauses the game until the player taps to start. Runs
## PROCESS_MODE_ALWAYS so it works while the tree is paused.
class_name TitleScreen
extends CanvasLayer

const EMBLEM := preload("res://assets/sprites/emblem.png")

var _tap: Label
var _t := 0.0

func _ready() -> void:
	layer = 8  # above the HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_input)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vb)

	var em := TextureRect.new()
	em.texture = EMBLEM
	em.custom_minimum_size = Vector2(230, 230)
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	em.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(em)

	vb.add_child(_label("COLONY COMMANDER", 58, Color(0.97, 0.90, 0.58)))
	_tap = _label("Tap to start", 26, Color(0.9, 0.9, 0.85))
	vb.add_child(_tap)

func _label(t: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _process(delta: float) -> void:
	_t += delta
	if _tap:
		_tap.modulate.a = 0.45 + 0.45 * sin(_t * 3.0)

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start()

func _start() -> void:
	Audio.sfx("click", -6.0)
	get_tree().paused = false
	queue_free()
