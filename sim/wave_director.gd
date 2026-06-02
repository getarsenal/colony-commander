## The threat brain + level flow (handoff §7 wave director, first campaign slice).
##
## A level is a fixed sequence of waves. Between waves there's a PREP countdown
## the player can short-circuit with "Call Wave" (Anthill's summon-early beat —
## braver play, faster level). Surviving the last wave = VICTORY; the hill
## falling = DEFEAT. Owns the enemy / carcass / projectile pools with the same
## 60fps pooling discipline as the Colony.
class_name WaveDirector
extends Node2D

enum State { PREP, SPAWNING, CLEARING, VICTORY, DEFEAT }

const ENEMY_POOL := 64
const CARCASS_POOL := 96
const PROJECTILE_POOL := 96
const MAX_ALIVE := 24                  # concurrent enemy cap (perf + readability at this zoom)

# An escalating level — counts only for this slice; types/biomes come later.
const WAVE_COUNTS := [6, 9, 13, 18, 24, 30]
const FIRST_PREP := 10.0               # breathing room before wave 1
const PREP_TIME := 13.0                # seconds of prep between waves
const SPAWN_SPACING := 0.55            # seconds between bugs within a wave

var colony = null
var enemy_layer: Node2D
var carcass_layer: Node2D
var projectile_layer: Node2D
var fx = null
var camera: Camera2D = null   # so bugs enter from the edges of the *visible* world

var state: int = State.PREP
var wave_index := 0                    # 0-based index of the NEXT/current wave
var prep_timer := FIRST_PREP
var enemies_killed := 0

var _to_spawn := 0
var _spawn_timer := 0.0
var _bosses_pending := 0
var _announced := false   # one-shot win/lose sting guard

var _enemy_pool: Array = []
var _enemy_free: Array = []
var _carcass_pool: Array = []
var _carcass_free: Array = []
var _proj_pool: Array = []
var _proj_free: Array = []

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

# --- level flow ---------------------------------------------------------------

func _process(delta: float) -> void:
	match state:
		State.PREP:
			prep_timer -= delta
			if prep_timer <= 0.0:
				_start_wave()
		State.SPAWNING:
			_spawn_timer -= delta
			if _to_spawn > 0 and _spawn_timer <= 0.0 \
					and alive_enemy_count() < MAX_ALIVE and not _enemy_free.is_empty():
				_spawn_one()
				_to_spawn -= 1
				_spawn_timer = SPAWN_SPACING
			if _to_spawn <= 0:
				state = State.CLEARING
		State.CLEARING:
			if alive_enemy_count() == 0:
				wave_index += 1
				if wave_index >= WAVE_COUNTS.size():
					state = State.VICTORY
				else:
					state = State.PREP
					prep_timer = PREP_TIME
		State.VICTORY, State.DEFEAT:
			if not _announced:
				_announced = true
				Audio.sfx("victory" if state == State.VICTORY else "defeat", 0.0)

func _start_wave() -> void:
	_to_spawn = WAVE_COUNTS[wave_index]
	_spawn_timer = 0.0
	# a boss from wave 4 on; the final wave brings two
	_bosses_pending = (1 if wave_index >= 3 else 0) + (1 if wave_index == WAVE_COUNTS.size() - 1 else 0)
	state = State.SPAWNING

func _spawn_one() -> void:
	var e = _enemy_pool[_enemy_free.pop_back()]
	e.spawn(_edge_spawn_point(), _pick_kind())

## Wave-scaled bug composition (boss saved for the tail of qualifying waves).
func _pick_kind() -> int:
	if _bosses_pending > 0 and _to_spawn <= _bosses_pending:
		_bosses_pending -= 1
		return Enemy.Kind.BOSS
	var w := wave_index
	var roll := randf()
	if w <= 1:
		return Enemy.Kind.LADYBUG if roll < 0.30 else Enemy.Kind.BEETLE
	elif w <= 3:
		if roll < 0.20: return Enemy.Kind.PILLBUG
		elif roll < 0.45: return Enemy.Kind.FLY
		elif roll < 0.70: return Enemy.Kind.LADYBUG
		return Enemy.Kind.BEETLE
	else:
		if roll < 0.34: return Enemy.Kind.PILLBUG
		elif roll < 0.58: return Enemy.Kind.FLY
		elif roll < 0.80: return Enemy.Kind.LADYBUG
		return Enemy.Kind.BEETLE

## Player summons the pending wave immediately (only meaningful during PREP).
func call_wave() -> void:
	if state == State.PREP:
		prep_timer = 0.0

func on_hill_destroyed() -> void:
	state = State.DEFEAT

# --- HUD queries --------------------------------------------------------------

func total_waves() -> int:
	return WAVE_COUNTS.size()

func is_prep() -> bool:
	return state == State.PREP

func is_victory() -> bool:
	return state == State.VICTORY

func is_defeat() -> bool:
	return state == State.DEFEAT

## Bugs still owed this level-phase: the unspawned remainder plus those alive.
func enemies_remaining() -> int:
	return _to_spawn + alive_enemy_count()

## Size of the wave that PREP is counting down to (for the "incoming" preview).
func incoming_preview() -> int:
	return WAVE_COUNTS[wave_index] if wave_index < WAVE_COUNTS.size() else 0

# --- spawning helpers ---------------------------------------------------------

## Pick a point just outside a random edge of the visible world so bugs crawl in.
func _edge_spawn_point() -> Vector2:
	var center: Vector2 = colony.hill_pos
	var vsize := get_viewport_rect().size
	if camera != null:
		vsize = vsize / camera.zoom
	var half := vsize * 0.5
	var m := 36.0
	match randi() % 4:
		0: return center + Vector2(randf_range(-half.x, half.x), -half.y - m)  # top
		1: return center + Vector2(half.x + m, randf_range(-half.y, half.y))   # right
		2: return center + Vector2(randf_range(-half.x, half.x), half.y + m)   # bottom
		_: return center + Vector2(-half.x - m, randf_range(-half.y, half.y))  # left

# --- callbacks from entities --------------------------------------------------

func on_enemy_killed(pos: Vector2, food_value: int, is_boss: bool) -> void:
	enemies_killed += 1
	_drop_carcass(pos, food_value)
	if fx != null:
		fx.puff(pos, Color(0.7, 0.15, 0.12), 30.0 if is_boss else 18.0)
		if is_boss:
			fx.add_shake(0.5)
			fx.popup(pos + Vector2(0, -24), "BOSS DOWN", Color(0.95, 0.6, 0.2))

func splash(pos: Vector2) -> void:
	if fx != null:
		fx.puff(pos, Color(0.55, 0.85, 0.25), 9.0)

func _drop_carcass(pos: Vector2, value: int) -> void:
	if _carcass_free.is_empty():
		return
	var c = _carcass_pool[_carcass_free.pop_back()]
	c.drop_at(pos, value)

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

func release_carcass(carcass) -> void:
	var idx := _carcass_pool.find(carcass)
	if idx != -1:
		_carcass_free.append(idx)

func release_projectile(proj) -> void:
	var idx := _proj_pool.find(proj)
	if idx != -1:
		_proj_free.append(idx)

# --- field wipe + level reset -------------------------------------------------

func clear_all_enemies() -> void:
	for e in _enemy_pool:
		if e.is_alive():
			e.force_despawn()

func clear_all_carcasses() -> void:
	for c in _carcass_pool:
		if c.is_available():
			c.force_despawn()

func clear_all_projectiles() -> void:
	for p in _proj_pool:
		p.force_despawn()

## Full restart back to wave 1 prep with an empty field.
func reset_level() -> void:
	clear_all_enemies()
	clear_all_carcasses()
	clear_all_projectiles()
	state = State.PREP
	wave_index = 0
	prep_timer = FIRST_PREP
	enemies_killed = 0
	_to_spawn = 0
	_spawn_timer = 0.0
	_announced = false

# --- spatial queries used by ants ---------------------------------------------

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
