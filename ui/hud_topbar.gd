## Minimal corner HUD (modelled on the original's clean layout): wave info
## top-left, score top-right, food bottom-centre. The hill's health shows as a
## small red bar by the mound (drawn in the world), so the top stays clear.
extends Control

var colony = null
var director = null

func _process(_delta: float) -> void:
	queue_redraw()

func _font() -> Font:
	return ThemeDB.fallback_font

## Draws text treating `pos` as the TOP-LEFT (draw_string's y is the baseline).
func _text(f: Font, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var p := Vector2(pos.x, pos.y + f.get_ascent(size))
	draw_string(f, p + Vector2(1.5, 1.5), s, align, -1, size, Color(0, 0, 0, 0.7))
	draw_string(f, p, s, align, -1, size, col)

func _draw() -> void:
	if colony == null or director == null:
		return
	var w := size.x
	var h := size.y
	var f := _font()

	# --- wave (top-left) ---
	if director.is_victory():
		_text(f, Vector2(24, 18), "LEVEL CLEARED", 30, Color(0.6, 0.95, 0.6))
	elif director.is_defeat():
		_text(f, Vector2(24, 18), "HILL OVERRUN", 30, Color(0.95, 0.45, 0.4))
	else:
		var shown = min(director.wave_index + 1, director.total_waves())
		_text(f, Vector2(24, 16), "WAVE %d / %d" % [shown, director.total_waves()], 30, Color(0.97, 0.93, 0.82))
		var sub := ""
		if director.is_prep():
			sub = "Next: %d bugs in %ds" % [director.incoming_preview(), int(ceil(director.prep_timer))]
		else:
			sub = "%d bugs left" % director.enemies_remaining()
		_text(f, Vector2(26, 52), sub, 18, Color(0.82, 0.78, 0.68))

	# --- score (top-right, below the buttons) ---
	var score: int = director.enemies_killed * 10
	var score_str := "Score: %d" % score
	var sw := f.get_string_size(score_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	_text(f, Vector2(w - 20 - sw, 66), score_str, 22, Color(0.92, 0.90, 0.80))

	# --- food (bottom-centre) ---
	var fy := h - 62
	draw_circle(Vector2(w * 0.5 - 64, fy + 20), 15, Color(0.92, 0.82, 0.34))
	draw_circle(Vector2(w * 0.5 - 68, fy + 15), 4.5, Color(1, 1, 1, 0.6))
	_text(f, Vector2(w * 0.5 - 44, fy), "Food: %d" % colony.food, 30, Color(0.97, 0.90, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
