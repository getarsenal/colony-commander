## One throwaway visual flourish: an expanding puff ring or a floating label
## (handoff §5 juice pass). Drawn directly (no Control nodes) so it lives happily
## under a Node2D world layer and shakes with it. Frees itself when spent.
class_name FxBit
extends Node2D

enum Kind { PUFF, TEXT }

var kind: int = Kind.PUFF
var color := Color.WHITE
var radius := 12.0
var text := ""
var _age := 0.0
var _life := 0.45
var _vel := Vector2.ZERO

static func _font() -> Font:
	return ThemeDB.fallback_font

func setup_puff(pos: Vector2, p_color: Color, p_radius: float) -> void:
	kind = Kind.PUFF
	position = pos
	color = p_color
	radius = p_radius
	_life = 0.4
	_age = 0.0

func setup_text(pos: Vector2, p_text: String, p_color: Color) -> void:
	kind = Kind.TEXT
	position = pos
	text = p_text
	color = p_color
	_life = 0.85
	_age = 0.0
	_vel = Vector2(0, -42)
	z_index = 30

func _process(delta: float) -> void:
	_age += delta
	if kind == Kind.TEXT:
		position += _vel * delta
		_vel.y += 24.0 * delta  # slight ease-out drift
	if _age >= _life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_age / _life, 0.0, 1.0)
	if kind == Kind.PUFF:
		var r := radius * (0.4 + t * 0.9)
		var a := (1.0 - t) * 0.8
		draw_circle(Vector2.ZERO, r, Color(color, a * 0.35))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, Color(color, a), 2.0)
	else:
		var a := 1.0 - t * t
		var f := _font()
		if f != null:
			var sz := 18
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			# soft shadow then face, centred on our origin
			draw_string(f, Vector2(-w * 0.5 + 1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, a * 0.6))
			draw_string(f, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(color, a))
