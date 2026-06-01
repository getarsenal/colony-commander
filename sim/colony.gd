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

# Food economy is a stub in step 1 (the harvest loop arrives in step 2), but the
# counter exists so the HUD and tuning hooks are already wired.
var food := 0

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
