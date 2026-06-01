## On-screen touch controls for mobile / web (the target platform has no keyboard).
##
## Phones can't press 1/2/3/E/C, so this draws a finger-sized button bar along the
## bottom of the screen that drives the same TrailDrawer command surface the
## keyboard does (set_caste / toggle_erase / clear_all). Drag-to-draw already works
## on touch via the project's emulate-mouse-from-touch, so trails need no buttons.
##
## Built entirely from code (like the rest of the slice) and parented to a
## CanvasLayer so it floats above the world and doesn't scroll with it.
class_name TouchControls
extends CanvasLayer

const BTN_SIZE := Vector2(118, 66)   # generous tap targets (>= ~44pt)
const GAP := 8                       # px between buttons
const MARGIN := 14                   # px from the bottom screen edge
const FONT_SIZE := 22

var drawer: TrailDrawer

var _bar: HBoxContainer
var _caste_buttons := {}             # AntTypes.Type -> Button
var _erase_button: Button
# cached styleboxes so per-frame highlight swaps never allocate
var _caste_style := {}               # type -> { "on": StyleBoxFlat, "off": StyleBoxFlat }
var _erase_on: StyleBoxFlat
var _erase_off: StyleBoxFlat

func _ready() -> void:
	layer = 5  # above the world's CanvasLayer HUD text underlay
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", GAP)
	add_child(_bar)

	for t in [AntTypes.Type.WORKER, AntTypes.Type.SOLDIER, AntTypes.Type.SPITTER]:
		var col: Color = AntTypes.color_of(t)
		var b := _make_button(AntTypes.name_of(t))
		_caste_style[t] = {
			"off": _stylebox(col.darkened(0.55), col.darkened(0.2), 2),
			"on": _stylebox(col.darkened(0.05), Color.WHITE, 3),
		}
		b.pressed.connect(_on_caste.bind(t))
		_caste_buttons[t] = b
		_bar.add_child(b)

	var erase_col := Color(0.85, 0.45, 0.20)
	_erase_off = _stylebox(Color(0.20, 0.20, 0.22), Color(0.45, 0.45, 0.48), 2)
	_erase_on = _stylebox(erase_col.darkened(0.05), Color.WHITE, 3)
	_erase_button = _make_button("Erase")
	_erase_button.pressed.connect(_on_erase)
	_bar.add_child(_erase_button)

	var clear_btn := _make_button("Clear")
	clear_btn.add_theme_stylebox_override("normal",
		_stylebox(Color(0.20, 0.20, 0.22), Color(0.45, 0.45, 0.48), 2))
	clear_btn.pressed.connect(_on_clear)
	_bar.add_child(clear_btn)

func _process(_delta: float) -> void:
	if drawer == null:
		return
	_reposition()
	_update_highlights()

# --- button callbacks ---------------------------------------------------------

func _on_caste(type: int) -> void:
	drawer.set_caste(type)

func _on_erase() -> void:
	drawer.toggle_erase()

func _on_clear() -> void:
	drawer.clear_all()

# --- layout + visual state ----------------------------------------------------

func _reposition() -> void:
	# Centre the bar along the bottom; recompute against the live viewport so it
	# tracks browser-window / device rotation resizes.
	var vp := get_viewport().get_visible_rect().size
	_bar.size = _bar.get_combined_minimum_size()
	_bar.position = Vector2((vp.x - _bar.size.x) * 0.5, vp.y - _bar.size.y - MARGIN)

func _update_highlights() -> void:
	for t in _caste_buttons:
		var selected: bool = not drawer.erase_mode and drawer.current_type == t
		var style: StyleBoxFlat = _caste_style[t]["on" if selected else "off"]
		_caste_buttons[t].add_theme_stylebox_override("normal", style)
	_erase_button.add_theme_stylebox_override("normal",
		_erase_on if drawer.erase_mode else _erase_off)

# --- builders -----------------------------------------------------------------

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN_SIZE
	b.focus_mode = Control.FOCUS_NONE   # no keyboard-focus ring on a touch UI
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.add_theme_color_override("font_color", Color(0.96, 0.96, 0.94))
	return b

func _stylebox(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	return sb
