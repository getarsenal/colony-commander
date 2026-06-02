## The bottom command panel (mobile/web is the target platform): tactile caste
## icon buttons plus Erase / Clear, styled to feel like the original's caste bar.
##
## Drives the same TrailDrawer command surface the keyboard does. Drag-to-draw
## works on touch via the project's emulate-mouse-from-touch, so trails need no
## button. Runs PROCESS_MODE_ALWAYS so it stays tappable while paused.
class_name TouchControls
extends CanvasLayer

const _BTN := preload("res://ui/caste_button.gd")
const GAP := 10
const MARGIN := 16

var drawer: TrailDrawer

var _bg: Panel
var _bar: HBoxContainer
var _caste_buttons := {}   # AntTypes.Type -> CasteButton
var _erase_button: CasteButton

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS

	_bg = Panel.new()
	var bgsb := StyleBoxFlat.new()
	bgsb.bg_color = Color(0.09, 0.08, 0.06, 0.74)
	bgsb.set_corner_radius_all(18)
	bgsb.set_border_width_all(2)
	bgsb.border_color = Color(0.0, 0.0, 0.0, 0.4)
	_bg.add_theme_stylebox_override("panel", bgsb)
	add_child(_bg)

	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", GAP)
	add_child(_bar)

	for t in [AntTypes.Type.WORKER, AntTypes.Type.SOLDIER, AntTypes.Type.SPITTER]:
		var b: CasteButton = _BTN.new()
		b.kind = CasteButton.Kind.CASTE
		b.caste_type = t
		b.label_text = AntTypes.name_of(t)
		b.accent = AntTypes.color_of(t)
		b.pressed.connect(_on_caste.bind(t))
		_caste_buttons[t] = b
		_bar.add_child(b)

	_erase_button = _BTN.new()
	_erase_button.kind = CasteButton.Kind.ERASE
	_erase_button.label_text = "Erase"
	_erase_button.accent = Color(0.93, 0.48, 0.45)
	_erase_button.pressed.connect(_on_erase)
	_bar.add_child(_erase_button)

	var clear_btn: CasteButton = _BTN.new()
	clear_btn.kind = CasteButton.Kind.CLEAR
	clear_btn.label_text = "Clear"
	clear_btn.accent = Color(0.72, 0.74, 0.76)
	clear_btn.pressed.connect(_on_clear)
	_bar.add_child(clear_btn)

func _process(_delta: float) -> void:
	if drawer == null:
		return
	_reposition()
	for t in _caste_buttons:
		_caste_buttons[t].selected = not drawer.erase_mode and drawer.current_type == t
	_erase_button.selected = drawer.erase_mode

func _reposition() -> void:
	var vp := get_viewport().get_visible_rect().size
	_bar.size = _bar.get_combined_minimum_size()
	_bar.position = Vector2((vp.x - _bar.size.x) * 0.5, vp.y - _bar.size.y - MARGIN)
	var pad := 10.0
	_bg.position = _bar.position - Vector2(pad, pad)
	_bg.size = _bar.size + Vector2(pad * 2.0, pad * 2.0)

func _on_caste(type: int) -> void:
	drawer.set_caste(type)

func _on_erase() -> void:
	drawer.toggle_erase()

func _on_clear() -> void:
	drawer.clear_all()
