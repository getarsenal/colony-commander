## The anthill brain: owns the pooled ants, enforces the population cap, and
## meters spawning onto every active trail.
##
## Pooling is mandatory (handoff §4 perf target: 300+ ants @ 60fps). We
## pre-instantiate POOL_SIZE Ant nodes once and reuse them forever — acquire =
## pop a free index, release = push it back. No instantiate/free per spawn.
class_name Colony
extends Node2D

const POOL_SIZE := 420

# Per-caste spawn economy (handoff §8, faithful to the original's spawn buttons):
# you OWN a population of each caste (its max concurrent ants on the field), and
# you grow that population by spending harvested food. Ants cycle out on trails
# and return home, so a trail of caste X streams up to pop[X] ants of that caste.
const START_POP := {AntTypes.Type.WORKER: 10, AntTypes.Type.SOLDIER: 8, AntTypes.Type.SPITTER: 5}
const SPAWN_COST := {AntTypes.Type.WORKER: 5, AntTypes.Type.SOLDIER: 10, AntTypes.Type.SPITTER: 15}
const SPAWN_BATCH := 3            # ants added to a caste's population per purchase
const START_FOOD := 12

var hill_pos := Vector2.ZERO
var ant_layer: Node2D            # parent for all ant nodes (set by Main)
var trail_container: Node2D      # parent for all Trail nodes (set by Main)

var _pool: Array = []            # all Ant nodes
var _free: Array = []            # indices of inactive ants
var active_count := 0            # total ants currently on the field (all castes)

var pop := {}                    # caste -> owned population (concurrent cap)
var active := {}                 # caste -> ants of that caste currently out

# Food economy: Workers convert harvested carcasses into food, spent on spawning.
var food := 0

# --- defense + threat hookups -------------------------------------------------
const HILL_HP_MAX := 100.0

var director = null               # WaveDirector: enemy / carcass / projectile queries
var fx = null                     # FxLayer: juice (puffs, popups, screen shake)
var hill_hp: float = HILL_HP_MAX  # the base you defend; 0 -> DEFEAT

func build_pool() -> void:
	_init_economy()
	var ant_script: Script = load("res://sim/ant.gd")
	for i in POOL_SIZE:
		var a = ant_script.new()
		a.init_pooled(self)
		ant_layer.add_child(a)
		_pool.append(a)
		_free.append(i)

func _init_economy() -> void:
	pop = START_POP.duplicate()
	active = {AntTypes.Type.WORKER: 0, AntTypes.Type.SOLDIER: 0, AntTypes.Type.SPITTER: 0}
	food = START_FOOD

## Can a trail of this caste stream another ant right now?
func can_spawn_caste(t: int) -> bool:
	return active.get(t, 0) < pop.get(t, 0) and not _free.is_empty()

## Spend food to grow a caste's population. Returns true on success.
func buy_caste(t: int) -> bool:
	var cost: int = SPAWN_COST.get(t, 99999)
	if food < cost or _total_pop() + SPAWN_BATCH > POOL_SIZE:
		return false
	food -= cost
	pop[t] = pop.get(t, 0) + SPAWN_BATCH
	if fx != null:
		fx.popup(hill_pos + Vector2(0, -84), "+%d %s" % [SPAWN_BATCH, AntTypes.name_of(t)], AntTypes.color_of(t))
	return true

func _total_pop() -> int:
	var n := 0
	for t in pop:
		n += pop[t]
	return n

func _acquire_ant():
	if _free.is_empty():
		return null
	var idx: int = _free.pop_back()
	active_count += 1
	return _pool[idx]

func release_ant(a) -> void:
	a.unregister_from_trail()
	var t: int = a.ant_type
	active[t] = max(0, active.get(t, 0) - 1)
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
	while trail.spawn_accum >= trail.spawn_interval and can_spawn_caste(trail.ant_type):
		trail.spawn_accum -= trail.spawn_interval
		_spawn_on(trail)

func _spawn_on(trail: Trail) -> void:
	var a = _acquire_ant()
	if a == null:
		return
	active[trail.ant_type] = active.get(trail.ant_type, 0) + 1
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
	food += n  # spent via buy_caste() on the spawn buttons

func damage_hill(n: float) -> void:
	if hill_hp <= 0.0:
		return  # already overrun; the director is in DEFEAT
	hill_hp = max(0.0, hill_hp - n)
	if fx != null:
		fx.add_shake(0.35)
		fx.puff(hill_pos, Color(0.9, 0.3, 0.2), 16.0)
	if hill_hp <= 0.0:
		if fx != null:
			fx.add_shake(1.0)
		if director != null:
			director.on_hill_destroyed()  # -> DEFEAT (HUD shows the overlay)

## Restore the base + larder for a fresh attempt (paired with director.reset_level).
func reset_defense() -> void:
	hill_hp = HILL_HP_MAX
	_init_economy()

## Send every ant on the field home/IDLE (used on a level restart).
func recall_all() -> void:
	for a in _pool:
		if a.is_active():
			release_ant(a)
