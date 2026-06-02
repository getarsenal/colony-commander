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
var _mute_btn: Button
var _overlay: Control
var _overlay_title: Label
var _overlay_sub: Label
var _restart_btn: Button
var _slider: HSlider
var _size_label: Label
var _fast := false
var _applied_scale := -1.0

# base (scale-1.0) sizes for the top controls
const _CALL := Vector2(256, 80)
const _SPEED := Vector2(82, 78)
const _PAUSE := Vector2(162, 78)
const _MUTE := Vector2(132, 78)
const _RESTART := Vector2(330, 88)

func _ready() -> void:
	layer = 6  # above the world (0) and the caste panel (5)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_topbar = _TOPBAR.new()
	_topbar.colony = colony
	_topbar.director = director
	_topbar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_topbar)

	_call_btn = _make_button("Call Wave", Color(0.55, 0.40, 0.12), _CALL)
	_call_btn.pressed.connect(_on_call)
	add_child(_call_btn)
	_speed_btn = _make_button("1x", Color(0.20, 0.22, 0.26), _SPEED)
	_speed_btn.pressed.connect(_on_speed)
	add_child(_speed_btn)
	_pause_btn = _make_button("Pause", Color(0.20, 0.22, 0.26), _PAUSE)
	_pause_btn.pressed.connect(_on_pause)
	add_child(_pause_btn)
	_mute_btn = _make_button("Sound", Color(0.20, 0.22, 0.26), _MUTE)
	_mute_btn.pressed.connect(_on_mute)
	add_child(_mute_btn)

	_build_overlay()
	_build_size_slider()
	_apply_ui_scale(Settings.ui_scale)

func _build_size_slider() -> void:
	_size_label = _make_label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_size_label.text = "Icon size"
	_size_label.add_theme_color_override("font_color", Color(0.86, 0.85, 0.78, 0.8))
	_size_label.size = Vector2(240, 22)
	add_child(_size_label)

	_slider = HSlider.new()
	_slider.min_value = Settings.MIN
	_slider.max_value = Settings.MAX
	_slider.step = 0.05
	_slider.value = Settings.ui_scale
	_slider.custom_minimum_size = Vector2(240, 30)
	_slider.size = Vector2(240, 30)
	_slider.value_changed.connect(_on_size)
	add_child(_slider)

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

	_overlay_title = _make_label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_overlay.add_child(_overlay_title)
	_overlay_sub = _make_label(26, HORIZONTAL_ALIGNMENT_CENTER)
	_overlay_sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	_overlay.add_child(_overlay_sub)

	_restart_btn = _make_button("Restart Level", Color(0.30, 0.45, 0.30), Vector2(330, 88))
	_restart_btn.pressed.connect(_on_restart)
	_overlay.add_child(_restart_btn)

func _process(_delta: float) -> void:
	if director == null:
		return
	var vp := get_viewport().get_visible_rect().size

	# re-apply the size setting whenever the slider moves
	if absf(Settings.ui_scale - _applied_scale) > 0.001:
		_apply_ui_scale(Settings.ui_scale)

	# icon-size slider, bottom-centre (the corners hold the caste/spawn panels)
	_slider.position = Vector2((vp.x - _slider.size.x) * 0.5, vp.y - 40)
	_size_label.position = Vector2((vp.x - _size_label.size.x) * 0.5, vp.y - 66)

	# top-right controls
	_pause_btn.position = Vector2(vp.x - _pause_btn.size.x - 16, 14)
	_speed_btn.position = Vector2(_pause_btn.position.x - _speed_btn.size.x - 10, 14)
	_mute_btn.position = Vector2(_speed_btn.position.x - _mute_btn.size.x - 10, 14)

	# Call Wave: only during prep, centred near the top (below the Food readout)
	_call_btn.visible = director.is_prep()
	_call_btn.position = Vector2((vp.x - _call_btn.size.x) * 0.5, 58)

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

func _on_size(v: float) -> void:
	Settings.set_ui_scale(v)

func _apply_ui_scale(s: float) -> void:
	_applied_scale = s
	_set_btn(_call_btn, _CALL, s)
	_set_btn(_speed_btn, _SPEED, s)
	_set_btn(_pause_btn, _PAUSE, s)
	_set_btn(_mute_btn, _MUTE, s)
	_set_btn(_restart_btn, _RESTART, s)
	_overlay_title.add_theme_font_size_override("font_size", int(round(64 * s)))
	_overlay_sub.add_theme_font_size_override("font_size", int(round(26 * s)))

func _set_btn(b: Button, base: Vector2, s: float) -> void:
	b.custom_minimum_size = base * s
	b.size = base * s
	b.add_theme_font_size_override("font_size", int(round(28 * s)))

func _center(c: Control, vp: Vector2, dy: float) -> void:
	c.size = c.get_combined_minimum_size()
	c.position = Vector2((vp.x - c.size.x) * 0.5, vp.y * 0.5 - c.size.y * 0.5 + dy)

# --- button callbacks ---------------------------------------------------------

func _on_call() -> void:
	Audio.sfx("click", -8.0)
	director.call_wave()

func _on_speed() -> void:
	Audio.sfx("click", -10.0)
	_fast = not _fast
	_speed_btn.text = "2x" if _fast else "1x"
	if main != null:
		main.set_game_speed(_fast)

func _on_pause() -> void:
	Audio.sfx("click", -10.0)
	var paused: bool = main.toggle_pause() if main != null else false
	_pause_btn.text = "Resume" if paused else "Pause"

func _on_mute() -> void:
	Audio.muted = not Audio.muted
	Audio.set_muted(Audio.muted)
	_mute_btn.text = "Muted" if Audio.muted else "Sound"

func _on_restart() -> void:
	Audio.sfx("click", -8.0)
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
	b.add_theme_font_size_override("font_size", 28)
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
