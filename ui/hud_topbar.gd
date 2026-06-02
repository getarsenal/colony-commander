## The Anthill-style top status bar: hill health, food, and wave progress.
##
## Pure custom-draw (no nested Controls) for a tight, themeable bar that reads at
## a glance on a phone. The Call-Wave / speed / pause buttons live on the HUD
## above this; this node just paints state and ignores input so trail-drags that
## start up here still pass through.
extends Control

const H := 54.0

var colony = null
var director = null

func _process(_delta: float) -> void:
	queue_redraw()

func _font() -> Font:
	return ThemeDB.fallback_font

func _text(f: Font, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(f, pos + Vector2(1, 1), s, align, -1, size, Color(0, 0, 0, 0.55))
	draw_string(f, pos, s, align, -1, size, col)

func _draw() -> void:
	if colony == null or director == null:
		return
	var w := size.x
	var f := _font()

	# bar background + base line
	draw_rect(Rect2(0, 0, w, H), Color(0.11, 0.09, 0.08, 0.85))
	draw_line(Vector2(0, H), Vector2(w, H), Color(0.0, 0.0, 0.0, 0.5), 2.0)

	# --- hill health (left) ---
	var hp_frac := clampf(colony.hill_hp / Colony.HILL_HP_MAX, 0.0, 1.0)
	var bar := Rect2(54, 18, 150, 16)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.45))
	if hp_frac > 0.0:
		var hp_col := Color(0.85, 0.27, 0.22).lerp(Color(0.45, 0.85, 0.4), hp_frac)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp_frac, bar.size.y)), hp_col)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.5), false, 1.5)
	# little hill glyph + label
	draw_circle(Vector2(20, 27), 11, Color(0.40, 0.30, 0.19))
	draw_circle(Vector2(20, 27), 4, Color(0.08, 0.06, 0.05))
	_text(f, Vector2(38, 16), "HILL", 11, Color(0.8, 0.8, 0.75))

	# --- food (left-centre) ---
	var fx := bar.position.x + bar.size.x + 26
	draw_circle(Vector2(fx, 27), 7, Color(0.92, 0.82, 0.34))
	draw_circle(Vector2(fx - 2, 25), 2.5, Color(1, 1, 1, 0.6))
	_text(f, Vector2(fx + 14, 19), "%d" % colony.food, 20, Color(0.96, 0.88, 0.45))

	# --- wave progress (centre) ---
	var cx := w * 0.5
	if director.is_victory():
		_text(f, Vector2(cx, 16), "LEVEL CLEARED", 20, Color(0.6, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	elif director.is_defeat():
		_text(f, Vector2(cx, 16), "HILL OVERRUN", 20, Color(0.95, 0.45, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var shown = min(director.wave_index + 1, director.total_waves())
		_text(f, Vector2(cx, 8), "WAVE %d / %d" % [shown, director.total_waves()], 18, Color(0.95, 0.92, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		var sub := ""
		if director.is_prep():
			sub = "Next: %d bugs in %ds" % [director.incoming_preview(), int(ceil(director.prep_timer))]
		else:
			sub = "%d bugs left" % director.enemies_remaining()
		_text(f, Vector2(cx, 30), sub, 12, Color(0.78, 0.75, 0.66), HORIZONTAL_ALIGNMENT_CENTER)

	# --- colony size (right, left of the buttons) ---
	var ant_txt := "Ants %d/%d" % [colony.active_count, colony.population_cap]
	_text(f, Vector2(w - 120, 8), ant_txt, 12, Color(0.78, 0.82, 0.78), HORIZONTAL_ALIGNMENT_LEFT)
	_text(f, Vector2(w - 120, 26), "Slain %d" % director.enemies_killed, 12, Color(0.72, 0.72, 0.66), HORIZONTAL_ALIGNMENT_LEFT)
