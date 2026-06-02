## Scene assembler (handoff §4/§5/§7). Builds the whole game from code so the
## .tscn stays trivial: wires the Colony + ant pool, the trail drawer, the threat
## WaveDirector (enemies/carcasses/projectiles), the juice layer, the touch caste
## panel and the HUD (top bar + wave controls + win/lose overlay); draws the
## ground + anthill + hill-HP ring; and routes the HUD's speed/pause/restart.
extends Node2D

const ZOOM := 2.6   # camera zoom — frames the colony close, like the original

var hill_pos := Vector2(640, 360)

var colony: Colony
var trail_container: Node2D
var trail_drawer: TrailDrawer
var touch_controls: TouchControls
var director: WaveDirector
var fx: FxLayer
var hud: HUD
var camera: Camera2D

var _hint: Label
# precomputed terrain decor (stable across frames, in world space around the hill)
var _specks: Array = []
var _pebbles: Array = []
var _tufts: Array = []
var _leaves: Array = []
var _skulls: Array = []
var _grains: Array = []   # texture flecks ON the anthill mound (relative to hill)

func _ready() -> void:
	hill_pos = get_viewport_rect().size * 0.5

	# --- world layers (z-order: trails < hill(this _draw) < ants) ---
	trail_container = Node2D.new()
	trail_container.name = "TrailContainer"
	add_child(trail_container)

	var ant_layer := Node2D.new()
	ant_layer.name = "AntLayer"
	add_child(ant_layer)

	# --- colony / pool ---
	colony = Colony.new()
	colony.name = "Colony"
	colony.hill_pos = hill_pos
	colony.ant_layer = ant_layer
	colony.trail_container = trail_container
	add_child(colony)
	colony.build_pool()

	# --- juice + threat (step 2: combat / carcass / harvest) ---
	fx = FxLayer.new()
	fx.name = "Fx"
	add_child(fx)

	var carcass_layer := Node2D.new()
	carcass_layer.name = "CarcassLayer"
	add_child(carcass_layer)

	var enemy_layer := Node2D.new()
	enemy_layer.name = "EnemyLayer"
	add_child(enemy_layer)

	var projectile_layer := Node2D.new()
	projectile_layer.name = "ProjectileLayer"
	add_child(projectile_layer)

	director = WaveDirector.new()
	director.name = "WaveDirector"
	director.colony = colony
	director.enemy_layer = enemy_layer
	director.carcass_layer = carcass_layer
	director.projectile_layer = projectile_layer
	director.fx = fx
	add_child(director)
	director.build_pools()

	colony.director = director
	colony.fx = fx

	# --- camera: frame the colony close (handoff feedback: original is zoomed in) ---
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = hill_pos
	camera.zoom = Vector2(ZOOM, ZOOM)
	add_child(camera)
	camera.make_current()
	director.camera = camera

	_build_decor()

	# --- input / drawing ---
	trail_drawer = TrailDrawer.new()
	trail_drawer.name = "TrailDrawer"
	trail_drawer.colony = colony
	trail_drawer.trail_container = trail_container
	trail_drawer.hill_pos = hill_pos
	add_child(trail_drawer)

	# --- on-screen controls for touch (mobile/web is the target platform) ---
	touch_controls = TouchControls.new()
	touch_controls.name = "TouchControls"
	touch_controls.drawer = trail_drawer
	add_child(touch_controls)

	# --- HUD: top status bar, wave controls, win/lose overlay ---
	hud = HUD.new()
	hud.name = "HUD"
	hud.colony = colony
	hud.director = director
	hud.main = self
	add_child(hud)

	_build_hint()
	queue_redraw()

func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_hint = Label.new()
	_hint.position = Vector2(22, 196)
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(0.86, 0.85, 0.78, 0.8))
	_hint.text = "Pick a caste below, then DRAG from the hill: lead Soldiers/Spitters\ninto the bugs, then send Workers onto the kills to harvest food."
	layer.add_child(_hint)

func _process(_delta: float) -> void:
	# world screen-shake (juice) via the camera, + keep the terrain/HP ring fresh
	if fx != null and camera != null:
		camera.offset = fx.shake_offset
	queue_redraw()

# --- HUD control hooks --------------------------------------------------------

func set_game_speed(fast: bool) -> void:
	Engine.time_scale = 2.0 if fast else 1.0

func toggle_pause() -> bool:
	var p := not get_tree().paused
	get_tree().paused = p
	return p

func restart_level() -> void:
	trail_drawer.clear_all()
	colony.recall_all()
	director.reset_level()
	colony.reset_defense()
	Engine.time_scale = 1.0
	get_tree().paused = false

# --- terrain generation (once) ------------------------------------------------

## Scatter stable decor in world space around the hill: a lush, layered jungle
## floor (moss, soil flecks, pebbles, grass tufts, leaves, a couple of skulls)
## — the original's "vibrant, layered environment" read, not a flat brown field.
func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9241
	var area := Vector2(1100, 700)   # half-extent around the hill (covers the zoomed view)

	for i in 220:
		var p := hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y))
		var dark := rng.randf() < 0.5
		_specks.append({
			"p": p,
			"r": rng.randf_range(1.5, 4.5),
			"c": Color(0.13, 0.10, 0.07, 0.55) if dark else Color(0.27, 0.21, 0.13, 0.45),
		})
	for i in 46:
		var p := hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y))
		var g := rng.randf_range(0.34, 0.52)
		_pebbles.append({"p": p, "r": rng.randf_range(3.0, 7.0), "c": Color(g, g * 0.96, g * 0.9)})
	for i in 60:
		var p := hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y))
		if p.distance_to(hill_pos) < 70.0:
			continue  # keep the hill's apron clear
		var green := Color(0.20, 0.40, 0.16).lerp(Color(0.34, 0.55, 0.22), rng.randf())
		_tufts.append({"p": p, "ang": rng.randf_range(-0.5, 0.5), "c": green, "h": rng.randf_range(7.0, 13.0)})
	for i in 30:
		var p := hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y))
		var green := Color(0.22, 0.46, 0.18).lerp(Color(0.40, 0.62, 0.26), rng.randf())
		_leaves.append({"p": p, "rot": rng.randf() * TAU, "c": green, "s": rng.randf_range(7.0, 13.0)})
	for i in 3:
		_skulls.append(hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y)))
	# texture flecks on the mound itself
	for i in 46:
		var a := rng.randf() * TAU
		var rad := sqrt(rng.randf()) * 44.0
		var g := rng.randf_range(0.30, 0.52)
		_grains.append({"off": Vector2(cos(a), sin(a) * 0.92) * rad - Vector2(0, 3), "r": rng.randf_range(0.8, 2.0),
			"c": Color(g, g * 0.78, g * 0.5, 0.8)})

# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	var view := get_viewport_rect().size / ZOOM
	var ground := Rect2(hill_pos - view * 0.5 - Vector2(60, 60), view + Vector2(120, 120))
	# base soil + two soft mossy washes for tonal variation
	draw_rect(ground, Color(0.17, 0.14, 0.10))
	draw_circle(hill_pos + Vector2(-260, -150), 360, Color(0.16, 0.22, 0.12, 0.22))
	draw_circle(hill_pos + Vector2(320, 180), 420, Color(0.18, 0.24, 0.13, 0.18))

	for s in _specks:
		draw_circle(s["p"], s["r"], s["c"])
	for sk in _skulls:
		_draw_skull(sk)
	for p in _pebbles:
		draw_circle(p["p"] + Vector2(0, 1.5), p["r"], Color(0, 0, 0, 0.18))  # shadow
		draw_circle(p["p"], p["r"], p["c"])
		draw_circle(p["p"] - Vector2(p["r"] * 0.3, p["r"] * 0.3), p["r"] * 0.45, p["c"].lightened(0.18))
	for t in _tufts:
		_draw_tuft(t)
	for lf in _leaves:
		_draw_leaf(lf)

	_draw_anthill()

func _draw_anthill() -> void:
	var h := hill_pos
	# cast shadow + layered earthen dome (offset up each ring for a 3D read)
	draw_circle(h + Vector2(0, 8), 54.0, Color(0, 0, 0, 0.22))
	draw_circle(h + Vector2(0, 3), 50.0, Color(0.24, 0.17, 0.10))
	draw_circle(h + Vector2(0, 0), 41.0, Color(0.32, 0.24, 0.14))
	draw_circle(h + Vector2(0, -3), 31.0, Color(0.41, 0.31, 0.18))
	draw_circle(h + Vector2(0, -6), 21.0, Color(0.50, 0.38, 0.23))
	# grainy texture
	for g in _grains:
		draw_circle(h + g["off"], g["r"], g["c"])
	# rim light along the upper-left
	draw_arc(h + Vector2(0, -1), 48.0, PI * 0.85, PI * 1.45, 18, Color(0.62, 0.50, 0.32, 0.5), 2.0)
	# entrance tunnel
	draw_circle(h + Vector2(0, -4), 11.0, Color(0.05, 0.04, 0.03))
	draw_arc(h + Vector2(0, -4), 11.0, 0.1, PI - 0.1, 14, Color(0.55, 0.42, 0.26, 0.6), 1.5)
	# a few grains tumbling at the entrance
	draw_circle(h + Vector2(5, 4), 1.6, Color(0.50, 0.38, 0.23))
	draw_circle(h + Vector2(-4, 6), 1.4, Color(0.46, 0.34, 0.20))

	# hill-HP ring hugging the mound
	if colony != null:
		var f := clampf(colony.hill_hp / Colony.HILL_HP_MAX, 0.0, 1.0)
		var start := -PI / 2.0
		draw_arc(h, 58.0, start, start + TAU, 44, Color(0.08, 0.06, 0.05, 0.55), 3.5)
		if f > 0.0:
			var hp_col := Color(0.85, 0.30, 0.25).lerp(Color(0.45, 0.85, 0.40), f)
			draw_arc(h, 58.0, start, start + TAU * f, 44, hp_col, 3.5)

func _draw_tuft(t: Dictionary) -> void:
	var p: Vector2 = t["p"]
	var c: Color = t["c"]
	var hgt: float = t["h"]
	for k in range(-2, 3):
		var a: float = t["ang"] + k * 0.28
		var tip := p + Vector2(sin(a), -cos(a)) * hgt
		draw_line(p, tip, c, 1.6)

func _draw_leaf(lf: Dictionary) -> void:
	var p: Vector2 = lf["p"]
	var s: float = lf["s"]
	var r: float = lf["rot"]
	var dir := Vector2(cos(r), sin(r))
	var perp := Vector2(-dir.y, dir.x)
	var poly := PackedVector2Array([
		p - dir * s,
		p + perp * s * 0.5,
		p + dir * s,
		p - perp * s * 0.5,
	])
	draw_colored_polygon(poly, lf["c"])
	draw_line(p - dir * s, p + dir * s, lf["c"].darkened(0.25), 1.0)  # midrib

func _draw_skull(p: Vector2) -> void:
	var bone := Color(0.86, 0.84, 0.76)
	draw_circle(p, 6.0, bone)
	draw_circle(p + Vector2(0, 5.0), 3.5, bone)         # jaw
	draw_circle(p + Vector2(-2.2, -0.5), 1.6, Color(0.1, 0.08, 0.07))  # eye
	draw_circle(p + Vector2(2.2, -0.5), 1.6, Color(0.1, 0.08, 0.07))   # eye
	draw_line(p + Vector2(0, 1.0), p + Vector2(0, 3.0), Color(0.1, 0.08, 0.07), 1.0)  # nose
