## Minimal corner HUD (modelled on the original's clean layout): wave info
## top-left, food top-centre, score top-right (under the buttons). The hill's
## health shows as a small red bar by the mound (drawn in the world).
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
	var f := _font()
	var us: float = Settings.ui_scale   # top text follows the icon-size slider too

	# --- wave (top-left) ---
	if director.is_victory():
		_text(f, Vector2(24, 16), "LEVEL CLEARED", int(34 * us), Color(0.6, 0.95, 0.6))
	elif director.is_defeat():
		_text(f, Vector2(24, 16), "HILL OVERRUN", int(34 * us), Color(0.95, 0.45, 0.4))
	else:
		var shown = min(director.wave_index + 1, director.total_waves())
		_text(f, Vector2(24, 14), "WAVE %d / %d" % [shown, director.total_waves()], int(34 * us), Color(0.97, 0.93, 0.82))
		var sub := ""
		if director.is_prep():
			sub = "Next: %d bugs in %ds" % [director.incoming_preview(), int(ceil(director.prep_timer))]
		else:
			sub = "%d bugs left" % director.enemies_remaining()
		_text(f, Vector2(26, 16 + 32 * us), sub, int(20 * us), Color(0.82, 0.78, 0.68))

	# --- food (top-centre, with a pellet) ---
	var fsz := int(32 * us)
	var fs := "Food: %d" % colony.food
	var fw := f.get_string_size(fs, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var fcx := w * 0.5
	draw_circle(Vector2(fcx - fw * 0.5 - 16 * us, 16 + 16 * us), 12 * us, Color(0.92, 0.82, 0.34))
	draw_circle(Vector2(fcx - fw * 0.5 - 19 * us, 13 + 16 * us), 3.5 * us, Color(1, 1, 1, 0.6))
	_text(f, Vector2(fcx - fw * 0.5, 14), fs, fsz, Color(0.97, 0.90, 0.55))

	# --- score (top-right, under the control buttons which scale by us) ---
	var ssz := int(24 * us)
	var ss := "Score: %d" % (director.enemies_killed * 10)
	var sw := f.get_string_size(ss, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz).x
	_text(f, Vector2(w - 22 - sw, 20 + 78 * us), ss, ssz, Color(0.90, 0.88, 0.78))
