## The anthill brain: owns the pooled ants, enforces the population cap, and
## meters spawning onto every active trail.
##
## Pooling is mandatory (handoff §4 perf target: 300+ ants @ 60fps). We
## pre-instantiate POOL_SIZE Ant nodes once and reuse them forever — acquire =
## pop a free index, release = push it back. No instantiate/free per spawn.
class_name Colony
extends Node2D

const POOL_SIZE := 420
const DEFAULT_POP_CAP := 220

var hill_pos := Vector2.ZERO
var population_cap := DEFAULT_POP_CAP
var ant_layer: Node2D            # parent for all ant nodes (set by Main)
var trail_container: Node2D      # parent for all Trail nodes (set by Main)

var _pool: Array = []            # all Ant nodes
var _free: Array = []            # indices of inactive ants
var active_count := 0

# Food economy (step 2): Workers convert harvested carcasses into food, which
# raises the population cap so a well-fed colony fields more ants.
var food := 0

# --- Step 2: defense + threat hookups -----------------------------------------
const HILL_HP_MAX := 100.0
const FOOD_PER_CAP := 4           # every N food banked raises the population cap by 1

var director = null               # WaveDirector: enemy / carcass / projectile queries
var fx = null                     # FxLayer: juice (puffs, popups, screen shake)
var hill_hp: float = HILL_HP_MAX  # the base you defend; 0 -> a breach
var breaches := 0

func build_pool() -> void:
	var ant_script: Script = load("res://sim/ant.gd")
	for i in POOL_SIZE:
		var a = ant_script.new()
		a.init_pooled(self)
		ant_layer.add_child(a)
		_pool.append(a)
		_free.append(i)

func can_spawn() -> bool:
	return active_count < population_cap and not _free.is_empty()

func _acquire_ant():
	if _free.is_empty():
		return null
	var idx: int = _free.pop_back()
	active_count += 1
	return _pool[idx]

func release_ant(a) -> void:
	a.unregister_from_trail()
	a.recycle()
	active_count -= 1
	# find its pool index (small pool; linear find is fine and avoids storing back-refs)
	var idx := _pool.find(a)
	if idx != -1:
		_free.append(idx)

func _process(delta: float) -> void:
	for child in trail_container.get_children():
		if child is Trail and child.is_usable():
			_meter_trail(child, delta)

func _meter_trail(trail: Trail, delta: float) -> void:
	trail.spawn_accum += delta
	while trail.spawn_accum >= trail.spawn_interval and can_spawn():
		trail.spawn_accum -= trail.spawn_interval
		_spawn_on(trail)

func _spawn_on(trail: Trail) -> void:
	var a = _acquire_ant()
	if a == null:
		return
	var ahead = trail.outbound.back() if not trail.outbound.is_empty() else null
	a.launch(trail, ahead)
	trail.ants.append(a)
	trail.outbound.append(a)

# --- Step 2: spatial queries (used by ants + enemies) -------------------------

## Nearest active ant to a point — enemies use this to pick whom to bite.
func nearest_ant(pos: Vector2, max_dist: float):
	var best = null
	var best_d2 := max_dist * max_dist
	for a in _pool:
		if a.is_combatant_for_enemy():
			var d2: float = pos.distance_squared_to(a.position)
			if d2 < best_d2:
				best_d2 = d2
				best = a
	return best

func nearest_enemy(pos: Vector2, max_dist: float):
	return director.nearest_enemy(pos, max_dist) if director != null else null

func nearest_available_carcass(pos: Vector2, max_dist: float):
	return director.nearest_available_carcass(pos, max_dist) if director != null else null

func fire_projectile(from: Vector2, target) -> void:
	if director != null:
		director.fire_projectile(from, target)

# --- Step 2: economy + base HP ------------------------------------------------

func add_food(n: int) -> void:
	food += n
	# More food in the larder -> a bigger standing colony.
	population_cap = min(POOL_SIZE, DEFAULT_POP_CAP + int(food / FOOD_PER_CAP))

func damage_hill(n: float) -> void:
	hill_hp -= n
	if fx != null:
		fx.add_shake(0.35)
		fx.puff(hill_pos, Color(0.9, 0.3, 0.2), 16.0)
	if hill_hp <= 0.0:
		_breach()

## Base overrun: a big juicy beat, then we wipe the field and reset HP so a
## playtest keeps rolling (full game-over flow lands with the campaign step).
func _breach() -> void:
	breaches += 1
	hill_hp = HILL_HP_MAX
	if director != null:
		director.clear_all_enemies()
	if fx != null:
		fx.add_shake(1.0)
		fx.popup(hill_pos + Vector2(0, -52), "BREACH!", Color(1.0, 0.4, 0.3))
