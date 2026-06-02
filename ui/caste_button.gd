## A round caste/tool button styled after the original's circular ant icons:
## an earthy disc with a coloured accent ring, a drawn glyph (an ant in the caste
## colour, or an erase / clear symbol), and a label beneath. Clear selected glow.
class_name CasteButton
extends Control

signal pressed

enum Kind { CASTE, ERASE, CLEAR }

const W := 104.0
const HT := 128.0
const RAD := 44.0

var kind: int = Kind.CASTE
var caste_type: int = 0
var label_text := ""
var accent := Color.WHITE
var selected := false

func _ready() -> void:
	custom_minimum_size = Vector2(W, HT)

func _gui_input(event: InputEvent) -> void:
	# Handle ONLY the mouse event. The project emulates mouse-from-touch, so a
	# phone tap already arrives as a mouse button — handling ScreenTouch too would
	# fire twice per tap, which silently cancelled the Erase toggle on mobile.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := Vector2(size.x * 0.5, RAD + 6.0)
	# selected glow
	if selected:
		draw_circle(c, RAD + 8.0, Color(accent, 0.30))
	# disc + soft inner shade
	draw_circle(c, RAD, Color(0.16, 0.13, 0.09, 0.98))
	draw_circle(c - Vector2(0, RAD * 0.28), RAD * 0.7, Color(0.22, 0.18, 0.12, 0.6))
	# accent ring
	var ring := accent if selected else accent.darkened(0.25)
	draw_arc(c, RAD - 1.0, 0.0, TAU, 40, ring, 5.0 if selected else 3.5, true)

	var k := 1.4
	match kind:
		Kind.CASTE:
			_draw_ant(c, k)
		Kind.ERASE:
			_draw_erase(c, k)
		Kind.CLEAR:
			_draw_clear(c, k)

	var f := ThemeDB.fallback_font
	if f != null:
		var sz := 19
		var tw := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var col := accent.lerp(Color.WHITE, 0.45) if selected else Color(0.88, 0.86, 0.80)
		draw_string(f, Vector2((size.x - tw) * 0.5 + 1, HT - 7), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2((size.x - tw) * 0.5, HT - 8), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _draw_ant(c: Vector2, k: float) -> void:
	var dark := Color(0.10, 0.07, 0.05)
	for s in [-1.0, 1.0]:
		draw_line(c, c + Vector2(8 * s, -4) * k, dark, 1.6 * k)
		draw_line(c, c + Vector2(9 * s, 1) * k, dark, 1.6 * k)
		draw_line(c, c + Vector2(8 * s, 6) * k, dark, 1.6 * k)
	draw_circle(c + Vector2(0, 6) * k, 4.8 * k, dark)    # abdomen
	draw_circle(c, 3.5 * k, dark)                        # thorax
	draw_circle(c + Vector2(0, -6) * k, 3.3 * k, dark)   # head
	draw_circle(c + Vector2(0, 6) * k, 2.6 * k, accent)  # caste marker
	draw_line(c + Vector2(0, -6) * k, c + Vector2(-3.5, -10) * k, dark, 1.3 * k)
	draw_line(c + Vector2(0, -6) * k, c + Vector2(3.5, -10) * k, dark, 1.3 * k)

func _draw_erase(c: Vector2, k: float) -> void:
	var col := Color(0.95, 0.55, 0.5)
	draw_line(c + Vector2(-8, -8) * k, c + Vector2(8, 8) * k, col, 4.0 * k)
	draw_line(c + Vector2(8, -8) * k, c + Vector2(-8, 8) * k, col, 4.0 * k)

func _draw_clear(c: Vector2, k: float) -> void:
	var metal := Color(0.74, 0.76, 0.78)
	var body := PackedVector2Array([c + Vector2(-6, -3) * k, c + Vector2(6, -3) * k, c + Vector2(4, 10) * k, c + Vector2(-4, 10) * k])
	draw_colored_polygon(body, metal)
	draw_line(c + Vector2(-9, -4) * k, c + Vector2(9, -4) * k, metal.lightened(0.15), 3.2 * k)
	draw_line(c + Vector2(-3, -7) * k, c + Vector2(3, -7) * k, metal.lightened(0.15), 2.6 * k)
	for dx in [-2.0, 2.0]:
		draw_line(c + Vector2(dx, 0) * k, c + Vector2(dx, 7) * k, Color(0.48, 0.50, 0.52), 1.4 * k)
