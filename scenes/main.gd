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
var spawn_panel: SpawnPanel
var director: WaveDirector
var fx: FxLayer
var hud: HUD
var camera: Camera2D

var _hint: Label
var terrain: Terrain

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

	terrain = Terrain.new()
	terrain.name = "Terrain"
	terrain.hill_pos = hill_pos
	add_child(terrain)

	# full-screen warm grade + vignette (above world, below UI)
	add_child(Grade.new())

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

	# --- spawn economy cluster (bottom-right): spend food to grow each caste ---
	spawn_panel = SpawnPanel.new()
	spawn_panel.name = "SpawnPanel"
	spawn_panel.colony = colony
	add_child(spawn_panel)

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
	_hint.position = Vector2(24, 92)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.86, 0.85, 0.78, 0.7))
	_hint.text = "DRAG from the hill to lead ants. Workers harvest kills for food;\nspend it on the spawn buttons (bottom-right) to grow each caste."
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

# --- drawing (dynamic only; static terrain/anthill live in Terrain) -----------

func _draw() -> void:
	# a small red hill-health bar above the mound — appears once the hill is hurt,
	# like the original (kept off the HUD so the top stays clean).
	if colony == null:
		return
	var f := clampf(colony.hill_hp / Colony.HILL_HP_MAX, 0.0, 1.0)
	if f >= 0.999:
		return
	var w := 70.0
	var top := hill_pos + Vector2(-w * 0.5, -66.0)
	draw_rect(Rect2(top - Vector2(2, 2), Vector2(w + 4, 11)), Color(0, 0, 0, 0.55))
	if f > 0.0:
		var col := Color(0.86, 0.22, 0.18).lerp(Color(0.5, 0.85, 0.4), f)
		draw_rect(Rect2(top, Vector2(w * f, 7)), col)
