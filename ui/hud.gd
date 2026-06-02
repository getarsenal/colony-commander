## The game HUD: top status bar + Call-Wave / speed / pause controls + the
## victory/defeat overlay (handoff §7 level flow, with the original's UI feel).
##
## Runs on its own CanvasLayer above the world and the caste panel, and is set to
## PROCESS_MODE_ALWAYS so its buttons keep working while the game is paused.
class_name HUD
extends CanvasLayer

const _TOPBAR := preload("res://ui/hud_topbar.gd")

var colony = null
var director = null
var main = null

var _topbar: Control
var _call_btn: Button
var _speed_btn: Button
var _pause_btn: Button
var _overlay: Control
var _overlay_title: Label
var _overlay_sub: Label
var _restart_btn: Button
var _fast := false

func _ready() -> void:
	layer = 6  # above the world (0) and the caste panel (5)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_topbar = _TOPBAR.new()
	_topbar.colony = colony
	_topbar.director = director
	_topbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_topbar.offset_bottom = 54
	_topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_topbar)

	_call_btn = _make_button("Call Wave", Color(0.55, 0.40, 0.12), Vector2(132, 38))
	_call_btn.pressed.connect(_on_call)
	add_child(_call_btn)
	_speed_btn = _make_button("1x", Color(0.20, 0.22, 0.26), Vector2(46, 36))
	_speed_btn.pressed.connect(_on_speed)
	add_child(_speed_btn)
	_pause_btn = _make_button("Pause", Color(0.20, 0.22, 0.26), Vector2(70, 36))
	_pause_btn.pressed.connect(_on_pause)
	add_child(_pause_btn)

	_build_overlay()

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	_overlay_title = _make_label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_overlay.add_child(_overlay_title)
	_overlay_sub = _make_label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_overlay_sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	_overlay.add_child(_overlay_sub)

	_restart_btn = _make_button("Restart Level", Color(0.30, 0.45, 0.30), Vector2(190, 48))
	_restart_btn.pressed.connect(_on_restart)
	_overlay.add_child(_restart_btn)

func _process(_delta: float) -> void:
	if director == null:
		return
	var vp := get_viewport().get_visible_rect().size

	# top-right controls
	_pause_btn.position = Vector2(vp.x - _pause_btn.size.x - 10, 9)
	_speed_btn.position = Vector2(_pause_btn.position.x - _speed_btn.size.x - 6, 9)

	# Call Wave: only during prep, centred just under the wave readout
	_call_btn.visible = director.is_prep()
	_call_btn.position = Vector2((vp.x - _call_btn.size.x) * 0.5, 56)

	# win/lose overlay
	if director.is_victory() or director.is_defeat():
		_overlay.visible = true
		if director.is_victory():
			_overlay_title.text = "VICTORY"
			_overlay_title.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
			_overlay_sub.text = "You held the colony through every wave."
		else:
			_overlay_title.text = "DEFEAT"
			_overlay_title.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4))
			_overlay_sub.text = "The hill was overrun. Try a tighter line."
		_center(_overlay_title, vp, -54)
		_center(_overlay_sub, vp, 0)
		_center(_restart_btn, vp, 56)
	else:
		_overlay.visible = false

func _center(c: Control, vp: Vector2, dy: float) -> void:
	c.size = c.get_combined_minimum_size()
	c.position = Vector2((vp.x - c.size.x) * 0.5, vp.y * 0.5 - c.size.y * 0.5 + dy)

# --- button callbacks ---------------------------------------------------------

func _on_call() -> void:
	director.call_wave()

func _on_speed() -> void:
	_fast = not _fast
	_speed_btn.text = "2x" if _fast else "1x"
	if main != null:
		main.set_game_speed(_fast)

func _on_pause() -> void:
	var paused: bool = main.toggle_pause() if main != null else false
	_pause_btn.text = "Resume" if paused else "Pause"

func _on_restart() -> void:
	# leaving any paused/fast state cleanly
	_fast = false
	_speed_btn.text = "1x"
	_pause_btn.text = "Pause"
	if main != null:
		main.restart_level()

# --- builders -----------------------------------------------------------------

func _make_button(text: String, bg: Color, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.96, 0.96, 0.92))
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(2)
	sb.border_color = bg.lightened(0.25)
	sb.set_content_margin_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	return b

func _make_label(font_size: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", Color.WHITE)
	return l
