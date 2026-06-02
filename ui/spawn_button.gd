## A round spawn button (bottom-right cluster, like the original): the caste's
## current population on top, an ant glyph in a coloured ring, and the food cost
## below. Dims when you can't afford it. Tapping spends food to grow the caste.
class_name SpawnButton
extends Control

signal buy

const W := 96.0
const HT := 130.0
const RAD := 38.0

var caste_type: int = 0
var accent := Color.WHITE
var count := 0
var cost := 0
var affordable := true

func _ready() -> void:
	custom_minimum_size = Vector2(W, HT)

func _gui_input(event: InputEvent) -> void:
	# mouse only (touch arrives as mouse via emulate-mouse-from-touch)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		buy.emit()
		accept_event()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var f := ThemeDB.fallback_font
	var dim := 1.0 if affordable else 0.45
	var c := Vector2(size.x * 0.5, 50.0)

	# count (top)
	if f != null:
		var cs := str(count)
		var cw := f.get_string_size(cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2((size.x - cw) * 0.5 + 1, 21), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2((size.x - cw) * 0.5, 20), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.95, 0.9, dim))

	# disc + ring
	draw_circle(c, RAD, Color(0.15, 0.12, 0.08, 0.97 * (0.7 + 0.3 * dim)))
	draw_circle(c - Vector2(0, RAD * 0.3), RAD * 0.68, Color(0.21, 0.17, 0.11, 0.6 * dim))
	draw_arc(c, RAD - 1.0, 0.0, TAU, 36, Color(accent, dim), 3.5, true)
	_draw_ant(c, 1.3, dim)

	# cost (bottom) with a little food pip
	if f != null:
		var cost_col := Color(0.97, 0.85, 0.4, dim)
		var cstr := "+%d" % cost
		var cw2 := f.get_string_size(cstr, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_circle(Vector2((size.x - cw2) * 0.5 - 8, HT - 14), 5.5, Color(0.92, 0.82, 0.34, dim))
		draw_string(f, Vector2((size.x - cw2) * 0.5 + 1, HT - 7), cstr, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2((size.x - cw2) * 0.5, HT - 8), cstr, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, cost_col)

func _draw_ant(c: Vector2, k: float, dim: float) -> void:
	var dark := Color(0.10, 0.07, 0.05, dim)
	for s in [-1.0, 1.0]:
		draw_line(c, c + Vector2(8 * s, -4) * k, dark, 1.5 * k)
		draw_line(c, c + Vector2(9 * s, 1) * k, dark, 1.5 * k)
		draw_line(c, c + Vector2(8 * s, 6) * k, dark, 1.5 * k)
	draw_circle(c + Vector2(0, 6) * k, 4.6 * k, dark)
	draw_circle(c, 3.4 * k, dark)
	draw_circle(c + Vector2(0, -6) * k, 3.2 * k, dark)
	draw_circle(c + Vector2(0, 6) * k, 2.4 * k, Color(accent, dim))
	draw_line(c + Vector2(0, -6) * k, c + Vector2(-3.5, -10) * k, dark, 1.2 * k)
	draw_line(c + Vector2(0, -6) * k, c + Vector2(3.5, -10) * k, dark, 1.2 * k)
