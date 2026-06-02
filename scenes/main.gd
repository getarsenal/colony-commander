## Scene assembler (handoff §4/§5/§7). Builds the whole game from code so the
## .tscn stays trivial: wires the Colony + ant pool, the trail drawer, the threat
## WaveDirector (enemies/carcasses/projectiles), the juice layer, the touch caste
## panel and the HUD (top bar + wave controls + win/lose overlay); draws the
## ground + anthill + hill-HP ring; and routes the HUD's speed/pause/restart.
extends Node2D

var hill_pos := Vector2(640, 380)

var colony: Colony
var trail_container: Node2D
var trail_drawer: TrailDrawer
var touch_controls: TouchControls
var director: WaveDirector
var fx: FxLayer
var hud: HUD

var _hint: Label

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
	_hint.position = Vector2(14, 62)
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.78, 0.85))
	_hint.text = "Pick a caste below, then DRAG from the hill: lead Soldiers/Spitters into\nthe bugs, then send Workers onto the kills to harvest food."
	layer.add_child(_hint)

func _process(_delta: float) -> void:
	# world screen-shake (juice) + keep the dynamic hill-HP ring fresh
	if fx != null:
		position = fx.shake_offset
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
