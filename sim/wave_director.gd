## The threat brain: spawns enemy waves and owns the enemy / carcass / projectile
## pools (handoff §7 wave director, scoped to a continuous-trickle first slice).
##
## Mirrors the Colony's pooling discipline. Difficulty escalates slowly over time
## so playtesting the combat/harvest FEEL stays pleasant rather than punishing —
## the real wave-table / campaign pacing lands with the campaign step.
class_name WaveDirector
extends Node2D

const ENEMY_POOL := 64
const CARCASS_POOL := 96
const PROJECTILE_POOL := 96
const MAX_ALIVE := 26                 # concurrent enemy cap (perf + readability)
const BASE_INTERVAL := 2.6            # seconds between spawns at wave 1
const MIN_INTERVAL := 0.6
const RAMP_PER_SEC := 0.012           # how fast spawn cadence tightens

var colony = null
var enemy_layer: Node2D
var carcass_layer: Node2D
var projectile_layer: Node2D
var fx = null

var elapsed := 0.0
var wave := 1
var enemies_killed := 0

var _enemy_pool: Array = []
var _enemy_free: Array = []
var _carcass_pool: Array = []
var _carcass_free: Array = []
var _proj_pool: Array = []
var _proj_free: Array = []

var _spawn_accum := 0.0

func build_pools() -> void:
	var enemy_script: Script = load("res://sim/enemy.gd")
	for i in ENEMY_POOL:
		var e = enemy_script.new()
		e.init_pooled(colony, self)
		enemy_layer.add_child(e)
		_enemy_pool.append(e)
		_enemy_free.append(i)
	var carcass_script: Script = load("res://sim/carcass.gd")
	for i in CARCASS_POOL:
		var c = carcass_script.new()
		c.init_pooled(self)
		carcass_layer.add_child(c)
		_carcass_pool.append(c)
		_carcass_free.append(i)
	var proj_script: Script = load("res://sim/projectile.gd")
	for i in PROJECTILE_POOL:
		var p = proj_script.new()
		p.init_pooled(self)
		projectile_layer.add_child(p)
		_proj_pool.append(p)
		_proj_free.append(i)

func alive_enemy_count() -> int:
	return ENEMY_POOL - _enemy_free.size()

func _process(delta: float) -> void:
	elapsed += delta
	wave = 1 + int(elapsed / 30.0)   # a new "wave" tier every 30s
	var interval: float = max(MIN_INTERVAL, BASE_INTERVAL - elapsed * RAMP_PER_SEC)
	_spawn_accum += delta
	while _spawn_accum >= interval:
		_spawn_accum -= interval
		_try_spawn()

func _try_spawn() -> void:
	if _enemy_free.is_empty() or alive_enemy_count() >= MAX_ALIVE:
		return
	var e = _enemy_pool[_enemy_free.pop_back()]
	e.spawn(_edge_spawn_point())

## Pick a point just outside a random screen edge so bugs crawl inward.
func _edge_spawn_point() -> Vector2:
	var vp := get_viewport_rect().size
	var m := 24.0
	match randi() % 4:
		0: return Vector2(randf() * vp.x, -m)            # top
		1: return Vector2(vp.x + m, randf() * vp.y)      # right
		2: return Vector2(randf() * vp.x, vp.y + m)      # bottom
		_: return Vector2(-m, randf() * vp.y)            # left

# --- callbacks from entities --------------------------------------------------

func on_enemy_killed(pos: Vector2) -> void:
	enemies_killed += 1
	_drop_carcass(pos)
	if fx != null:
		fx.puff(pos, Color(0.7, 0.15, 0.12), 18.0)

func splash(pos: Vector2) -> void:
	if fx != null:
		fx.puff(pos, Color(0.55, 0.85, 0.25), 9.0)

func _drop_carcass(pos: Vector2) -> void:
	if _carcass_free.is_empty():
		return
	var c = _carcass_pool[_carcass_free.pop_back()]
	c.drop_at(pos)

func fire_projectile(from: Vector2, target) -> void:
	if _proj_free.is_empty():
		return
	var p = _proj_pool[_proj_free.pop_back()]
	p.fire(from, target)

# --- pool release (entities call these on despawn) ----------------------------

func release(enemy) -> void:
	var idx := _enemy_pool.find(enemy)
	if idx != -1:
		_enemy_free.append(idx)

## Wipe every living enemy (used on a base breach). No carcasses dropped.
func clear_all_enemies() -> void:
	for e in _enemy_pool:
		if e.is_alive():
			e.force_despawn()

func release_carcass(carcass) -> void:
	var idx := _carcass_pool.find(carcass)
	if idx != -1:
		_carcass_free.append(idx)

func release_projectile(proj) -> void:
	var idx := _proj_pool.find(proj)
	if idx != -1:
		_proj_free.append(idx)

# --- spatial queries used by ants (harvest) -----------------------------------

func nearest_enemy(pos: Vector2, max_dist: float):
	var best = null
	var best_d := max_dist
	for e in _enemy_pool:
		if e.is_alive():
			var d: float = pos.distance_to(e.position)
			if d < best_d:
				best_d = d
				best = e
	return best

func nearest_available_carcass(pos: Vector2, max_dist: float):
	var best = null
	var best_d := max_dist
	for c in _carcass_pool:
		if c.is_available():
			var d: float = pos.distance_to(c.position)
			if d < best_d:
				best_d = d
				best = c
	return best
