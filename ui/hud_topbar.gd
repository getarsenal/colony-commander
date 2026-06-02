## The Anthill-style top status bar: hill health, food, and wave progress.
##
## Pure custom-draw for a tight, themeable bar that reads at a glance on a phone.
## The Call-Wave / speed / pause buttons live on the HUD above this; this node
## just paints state and ignores input so trail-drags up here still pass through.
extends Control

const H := 108.0
const LX := 24.0   # left content inset

var colony = null
var director = null

func _process(_delta: float) -> void:
	queue_redraw()

func _font() -> Font:
	return ThemeDB.fallback_font

## Draws text treating `pos` as the TOP-LEFT (draw_string's y is the baseline,
## so we add the ascent — this is what kept the bar text clipping off the top).
func _text(f: Font, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var p := Vector2(pos.x, pos.y + f.get_ascent(size))
	draw_string(f, p + Vector2(1, 1), s, align, -1, size, Color(0, 0, 0, 0.6))
	draw_string(f, p, s, align, -1, size, col)

func _draw() -> void:
	if colony == null or director == null:
		return
	var w := size.x
	var f := _font()

	# warm earthy bar + base line
	draw_rect(Rect2(0, 0, w, H), Color(0.12, 0.10, 0.075, 0.9))
	draw_rect(Rect2(0, H - 3, w, 3), Color(0.35, 0.26, 0.15, 0.7))

	# --- hill health (left) ---
	draw_circle(Vector2(LX + 20, 66), 20, Color(0.42, 0.31, 0.19))
	draw_circle(Vector2(LX + 20, 66), 7, Color(0.07, 0.05, 0.04))
	_text(f, Vector2(LX + 50, 16), "HILL", 19, Color(0.82, 0.80, 0.72))
	var hp_frac := clampf(colony.hill_hp / Colony.HILL_HP_MAX, 0.0, 1.0)
	var bar := Rect2(LX + 50, 52, 252, 26)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.5))
	if hp_frac > 0.0:
		var hp_col := Color(0.85, 0.27, 0.22).lerp(Color(0.45, 0.85, 0.4), hp_frac)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp_frac, bar.size.y)), hp_col)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.55), false, 2.0)

	# --- food (left-centre) ---
	var fx := bar.position.x + bar.size.x + 48
	draw_circle(Vector2(fx, 66), 15, Color(0.92, 0.82, 0.34))
	draw_circle(Vector2(fx - 4, 61), 4.5, Color(1, 1, 1, 0.6))
	_text(f, Vector2(fx + 24, 44), "%d" % colony.food, 38, Color(0.97, 0.89, 0.46))

	# --- wave progress (centre) ---
	var cx := w * 0.5
	if director.is_victory():
		_text(f, Vector2(cx, 36), "LEVEL CLEARED", 38, Color(0.6, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	elif director.is_defeat():
		_text(f, Vector2(cx, 36), "HILL OVERRUN", 38, Color(0.95, 0.45, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var shown = min(director.wave_index + 1, director.total_waves())
		_text(f, Vector2(cx, 14), "WAVE %d / %d" % [shown, director.total_waves()], 32, Color(0.96, 0.92, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		var sub := ""
		if director.is_prep():
			sub = "Next: %d bugs in %ds" % [director.incoming_preview(), int(ceil(director.prep_timer))]
		else:
			sub = "%d bugs left" % director.enemies_remaining()
		_text(f, Vector2(cx, 56), sub, 20, Color(0.80, 0.77, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
		# colony size, tucked under the centre (clear of the right-side buttons)
		_text(f, Vector2(cx, 84), "Ants %d/%d   •   Slain %d" % [colony.active_count, colony.population_cap, director.enemies_killed], 15, Color(0.72, 0.74, 0.70), HORIZONTAL_ALIGNMENT_CENTER)
