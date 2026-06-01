## Step 1 vertical slice: the trail-flow prototype (handoff §4 + §9 step 1).
##
## Builds the whole scene from code so the .tscn stays trivial (one root node) —
## easier to keep correct without opening the editor, and easier for a Godot
## newcomer to read. Wires the Colony, Trail container, TrailDrawer and a HUD,
## draws the ground + anthill, and pre-builds the ant pool.
##
## This prototype intentionally has NO combat, carcasses or enemies yet. Its one
## job is to prove the streaming FEELS alive before anything downstream is built.
extends Node2D

var hill_pos := Vector2(640, 380)

var colony: Colony
var trail_container: Node2D
var trail_drawer: TrailDrawer
var touch_controls: TouchControls
var director: WaveDirector
var fx: FxLayer

var _info_label: Label
var _stats_label: Label

func _ready() -> void:
	hill_pos = get_viewport_rect().size * Vector2(0.5, 0.55)

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

	_build_hud()
	queue_redraw()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_info_label = Label.new()
	_info_label.position = Vector2(16, 12)
	_info_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	layer.add_child(_info_label)

	_stats_label = Label.new()
	_stats_label.position = Vector2(16, 150)
	_stats_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65))
	layer.add_child(_stats_label)

func _process(_delta: float) -> void:
	if _info_label == null:
		return
	_info_label.text = "COLONY COMMANDER — defend the hill (step 2)\n" \
		+ "[1] Worker — harvest carcasses   [2] Soldier — melee   [3] Spitter — ranged\n" \
		+ "DRAG to draw a trail into the bugs to fight, then onto the kills to harvest.\n" \
		+ "Tap Erase then a trail to remove it.   Desktop: [1/2/3] [E] erase [C] clear"

	var mode := "ERASE" if trail_drawer.erase_mode else "DRAW"
	_stats_label.text = "Selected: %s    Mode: %s\nAnts: %d / %d    Trails: %d    FPS: %d\nHill: %d/%d    Food: %d    Wave: %d    Slain: %d    Breaches: %d" % [
		AntTypes.name_of(trail_drawer.current_type),
		mode,
		colony.active_count,
		colony.population_cap,
		_trail_count(),
		Engine.get_frames_per_second(),
		int(colony.hill_hp),
		int(Colony.HILL_HP_MAX),
		colony.food,
		director.wave,
		director.enemies_killed,
		colony.breaches,
	]

	# screen shake (juice) + keep the dynamic hill-HP ring fresh
	if fx != null:
		position = fx.shake_offset
	queue_redraw()

func _trail_count() -> int:
	var n := 0
	for c in trail_container.get_children():
		if c is Trail:
			n += 1
	return n

func _draw() -> void:
	var size := get_viewport_rect().size
	# ground
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.13, 0.10))
	# subtle soil mottling
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 90:
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		draw_circle(p, rng.randf_range(1.0, 3.0), Color(0.20, 0.16, 0.12, 0.5))
	# anthill mound
	draw_circle(hill_pos, 34.0, Color(0.30, 0.22, 0.14))
	draw_circle(hill_pos, 26.0, Color(0.38, 0.28, 0.18))
	draw_circle(hill_pos, 16.0, Color(0.45, 0.34, 0.22))
	# entrance hole
	draw_circle(hill_pos, 7.0, Color(0.08, 0.06, 0.05))
	# hill-HP ring: green arc shrinks as the base takes damage
	if colony != null:
		var f := clampf(colony.hill_hp / Colony.HILL_HP_MAX, 0.0, 1.0)
		var start := -PI / 2.0
		draw_arc(hill_pos, 40.0, start, start + TAU, 40, Color(0.10, 0.08, 0.07, 0.6), 3.0)
		if f > 0.0:
			var hp_col := Color(0.85, 0.3, 0.25).lerp(Color(0.4, 0.85, 0.4), f)
			draw_arc(hill_pos, 40.0, start, start + TAU * f, 40, hp_col, 3.0)
