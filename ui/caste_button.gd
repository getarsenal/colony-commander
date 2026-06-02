## A single tactile control-panel button drawn to feel like the original's caste
## icons: a rounded earthy tile with a drawn glyph (an ant in the caste colour,
## or an erase / clear symbol) and a label, with a clear selected state.
class_name CasteButton
extends Control

signal pressed

enum Kind { CASTE, ERASE, CLEAR }

const W := 132.0
const HT := 118.0

var kind: int = Kind.CASTE
var caste_type: int = 0
var label_text := ""
var accent := Color.WHITE
var selected := false

var _normal: StyleBoxFlat
var _selected: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = Vector2(W, HT)
	_normal = _panel(Color(0.17, 0.13, 0.09, 0.97), Color(0.0, 0.0, 0.0, 0.55), 2)
	_selected = _panel(Color(0.26, 0.20, 0.12, 0.99), accent, 3)

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		pressed.emit()
		accept_event()

func _panel(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(bw)
	sb.border_color = border
	return sb

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	(_selected if selected else _normal).draw(get_canvas_item(), r)
	var k := size.y / 86.0   # glyph scale, so icons grow with the button
	var c := Vector2(size.x * 0.5, size.y * 0.40)
	match kind:
		Kind.CASTE:
			_draw_ant(c, k)
		Kind.ERASE:
			_draw_erase(c, k)
		Kind.CLEAR:
			_draw_clear(c, k)
	# label
	var f := ThemeDB.fallback_font
	if f != null:
		var sz := int(round(20 * k))
		var tw := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var col := accent.lerp(Color.WHITE, 0.4) if selected else Color(0.90, 0.88, 0.82)
		draw_string(f, Vector2((size.x - tw) * 0.5, size.y - 14 * k), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _draw_ant(c: Vector2, k: float) -> void:
	var dark := Color(0.11, 0.08, 0.06)
	for s in [-1.0, 1.0]:
		draw_line(c, c + Vector2(8 * s, -4) * k, dark, 1.5 * k)
		draw_line(c, c + Vector2(9 * s, 1) * k, dark, 1.5 * k)
		draw_line(c, c + Vector2(8 * s, 6) * k, dark, 1.5 * k)
	draw_circle(c + Vector2(0, 6) * k, 4.6 * k, dark)    # abdomen
	draw_circle(c, 3.4 * k, dark)                        # thorax
	draw_circle(c + Vector2(0, -6) * k, 3.2 * k, dark)   # head
	draw_circle(c + Vector2(0, 6) * k, 2.4 * k, accent)  # caste marker
	draw_line(c + Vector2(0, -6) * k, c + Vector2(-3.5, -10) * k, dark, 1.2 * k)
	draw_line(c + Vector2(0, -6) * k, c + Vector2(3.5, -10) * k, dark, 1.2 * k)

func _draw_erase(c: Vector2, k: float) -> void:
	var col := Color(0.93, 0.48, 0.45)
	draw_line(c + Vector2(-8, -8) * k, c + Vector2(8, 8) * k, col, 3.5 * k)
	draw_line(c + Vector2(8, -8) * k, c + Vector2(-8, 8) * k, col, 3.5 * k)

func _draw_clear(c: Vector2, k: float) -> void:
	var metal := Color(0.72, 0.74, 0.76)
	var body := PackedVector2Array([c + Vector2(-6, -3) * k, c + Vector2(6, -3) * k, c + Vector2(4, 10) * k, c + Vector2(-4, 10) * k])
	draw_colored_polygon(body, metal)
	draw_line(c + Vector2(-9, -4) * k, c + Vector2(9, -4) * k, metal.lightened(0.15), 3.0 * k)  # lid
	draw_line(c + Vector2(-3, -7) * k, c + Vector2(3, -7) * k, metal.lightened(0.15), 2.5 * k)  # handle
	for dx in [-2.0, 2.0]:
		draw_line(c + Vector2(dx, 0) * k, c + Vector2(dx, 7) * k, Color(0.48, 0.50, 0.52), 1.3 * k)
