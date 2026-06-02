## A single ant: a lightweight follower that walks along its Trail's Curve2D.
##
## Ants are NOT individually pathfound (handoff §4). Each one tracks a single
## `dist` (how far along the trail's baked curve it is, in pixels) and a state.
## The Colony owns a POOL of these nodes and reuses them — we never instantiate
## or free an ant per spawn (perf target: 300+ at 60fps).
##
## Coordinate note: every sim node (this ant, the AntLayer it lives under, every
## Trail) sits at the world origin with no Camera2D, so world == screen pixels
## and a trail's baked curve points are usable directly as ant positions.
class_name Ant
extends Node2D

enum State {
	IDLE,         # pooled / inactive
	OUTBOUND,     # walking from hill to trail end
	WORKING,      # paused at the trail end doing its job
	RETURNING,    # walking back down the trail to the hill
	FREE_RETURN,  # trail was erased mid-trip — walk straight home, gracefully
	SEEK_FOOD,    # worker peeled off the trail to grab a nearby carcass
}

# --- Feel tuning (handoff §4 "the magic is here") -----------------------------
const MIN_GAP := 9.0          # min pixels between an ant and the one ahead -> queueing/bunching
const WIGGLE_AMP := 2.6       # lateral sway amplitude (px) -> "living column", not a conga line
const WIGGLE_FREQ := 0.09     # how tight the sway is along the trail
const WORK_TIME := 0.35       # seconds paused at the destination (shorter = less tip clog)
const DETOUR_RANGE := 78.0    # how far a worker will peel off-trail to grab food
const ARRIVE_EPS := 5.0       # px tolerance for "home"

# --- Step 2: combat + harvest (handoff §5) ------------------------------------
const HP_BY := {              # caste durability — soldiers tank, spitters are frail
	AntTypes.Type.WORKER:  8.0,
	AntTypes.Type.SOLDIER: 34.0,
	AntTypes.Type.SPITTER: 14.0,
	AntTypes.Type.BOMBER:  12.0,
}
const MELEE_RANGE := 16.0     # soldier bite reach
const MELEE_DAMAGE := 8.0
const MELEE_INTERVAL := 0.42
const SPIT_RANGE := 160.0     # spitter engagement range
const SPIT_INTERVAL := 0.6
const HARVEST_RANGE := 34.0   # how near a trail tip a carcass must be to grab it

var state: int = State.IDLE
var ant_type: int = AntTypes.Type.WORKER
var dist: float = 0.0         # distance along the trail's baked curve, in px
var speed: float = 100.0
var phase: float = 0.0        # per-ant sway phase so the column desyncs
var work_timer: float = 0.0

# combat / harvest state
var hp: float = 8.0
var attack_timer: float = 0.0
var carrying := false         # a worker hauling a carcass home
var carry_value := 0
var _target_carcass = null    # carcass a worker has reserved and is detouring to
var _engaged := false         # holding position in melee this frame (pauses advance)
var _hit_flash := 0.0         # white flash on taking a hit (juice)

var trail = null              # current Trail (null when FREE_RETURN / IDLE)
var ahead = null              # the Ant directly ahead on this trail (for spacing)
var colony = null             # back-reference, set once at pool creation

var _base_color := Color(0.13, 0.10, 0.08)

func _ready() -> void:
	visible = false
	z_index = 10  # ants draw above trails

## Called once when the Colony builds the pool.
func init_pooled(p_colony) -> void:
	colony = p_colony
	state = State.IDLE
	visible = false

## Activate this pooled ant onto a trail.
func launch(p_trail, p_ahead) -> void:
	trail = p_trail
	ahead = p_ahead
	ant_type = p_trail.ant_type
	state = State.OUTBOUND
	dist = 0.0
	work_timer = 0.0
	hp = HP_BY.get(ant_type, 10.0)
	attack_timer = 0.0
	carrying = false
	carry_value = 0
	_target_carcass = null
	_engaged = false
	_hit_flash = 0.0
	speed = AntTypes.speed_of(ant_type) * randf_range(0.88, 1.12)
	phase = randf() * TAU
	scale = Vector2.ONE * AntTypes.body_scale_of(ant_type)
	position = trail.sample(0.0)
	visible = true
	queue_redraw()  # refresh the caste-coloured marker for this spawn

func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
	# Soldiers/Spitters fight nearby enemies every frame regardless of trail state.
	_update_combat(delta)
	match state:
		State.OUTBOUND:
			_advance_outbound(delta)
		State.WORKING:
			work_timer -= delta
			if ant_type == AntTypes.Type.WORKER and not carrying:
				_try_harvest()
				if carrying:
					return  # claimed a carcass and started home this frame
			# little bob in place while "working"
			scale.y = AntTypes.body_scale_of(ant_type) * (1.0 + sin(Time.get_ticks_msec() * 0.012 + phase) * 0.08)
			if work_timer <= 0.0:
				_begin_return()
		State.RETURNING:
			_advance_return(delta)
		State.FREE_RETURN:
			_advance_free_return(delta)
		State.SEEK_FOOD:
			_advance_seek(delta)

func _advance_outbound(delta: float) -> void:
	if not is_instance_valid(trail) or not trail.is_usable():
		_detach_and_free_return()
		return
	# Workers peel off the trail to grab a nearby carcass (playtester ask).
	if ant_type == AntTypes.Type.WORKER and not carrying and colony != null:
		var c = colony.nearest_available_carcass(position, DETOUR_RANGE)
		if c != null and c.reserve():
			_target_carcass = c
			trail.ants.erase(self)
			trail.outbound.erase(self)
			trail = null
			ahead = null
			state = State.SEEK_FOOD
			return
	var step := speed * delta
	var target := dist + step
	# Congestion: never overtake the ant ahead — clamp behind it, which makes
	# columns bunch at bottlenecks and pile up at the destination.
	if _ahead_blocks():
		target = min(target, ahead.dist - MIN_GAP)
	if _engaged:
		target = dist  # holding the line in melee — don't push forward this frame
	dist = max(dist, target)  # max() so we wait rather than reverse when blocked
	var length: float = trail.length()
	if dist >= length:
		dist = length
		state = State.WORKING
		work_timer = WORK_TIME
	_place_on_trail()

func _begin_return() -> void:
	# Leaving the outbound queue: drop out of spacing chain so followers stop
	# clamping behind us and can advance into the spot we vacated.
	if is_instance_valid(trail):
		trail.outbound.erase(self)
	ahead = null
	state = State.RETURNING

func _advance_return(delta: float) -> void:
	if not is_instance_valid(trail) or not trail.is_usable():
		_detach_and_free_return()
		return
	if _engaged:
		_place_on_trail()  # stand and fight on the way home
		return
	dist -= speed * delta
	if dist <= 0.0:
		_arrive_home()
		return
	_place_on_trail()

func _advance_free_return(delta: float) -> void:
	var home: Vector2 = colony.hill_pos if colony != null else Vector2.ZERO
	position = position.move_toward(home, speed * delta)
	rotation = (home - position).angle()
	if position.distance_to(home) <= ARRIVE_EPS:
		_arrive_home()

## Worker walking off-trail to a reserved carcass, then heading straight home.
func _advance_seek(delta: float) -> void:
	if not is_instance_valid(_target_carcass) or not _target_carcass.is_reserved_alive():
		_target_carcass = null
		_detach_and_free_return()  # food vanished — head home empty
		return
	var tp: Vector2 = _target_carcass.position
	position = position.move_toward(tp, speed * delta)
	rotation = (tp - position).angle()
	if position.distance_to(tp) <= 6.0:
		carry_value = _target_carcass.collect()
		_target_carcass = null
		carrying = carry_value > 0
		if carrying:
			Audio.sfx("harvest", -8.0)
			if colony != null and colony.fx != null:
				colony.fx.puff(position, Color(0.95, 0.85, 0.35), 8.0)
		_detach_and_free_return()  # carry it straight home

# --- combat + harvest (step 2) ------------------------------------------------

## Soldiers bite, Spitters fire. Runs every frame; sets `_engaged` so melee
## fighters hold position (see _advance_*). Workers don't fight.
func _update_combat(delta: float) -> void:
	_engaged = false
	if attack_timer > 0.0:
		attack_timer = max(0.0, attack_timer - delta)
	if colony == null:
		return
	match ant_type:
		AntTypes.Type.SOLDIER:
			var e = colony.nearest_enemy(position, MELEE_RANGE)
			if e != null:
				_engaged = true
				rotation = (e.position - position).angle()
				if attack_timer <= 0.0:
					attack_timer = MELEE_INTERVAL
					e.take_damage(MELEE_DAMAGE)
					if colony.fx != null:
						colony.fx.puff(e.position, Color(0.95, 0.9, 0.6), 7.0)
		AntTypes.Type.SPITTER:
			var e = colony.nearest_enemy(position, SPIT_RANGE)
			if e != null:
				if position.distance_to(e.position) <= MELEE_RANGE:
					_engaged = true  # brace only if it's right on top of us
				if attack_timer <= 0.0:
					attack_timer = SPIT_INTERVAL
					rotation = (e.position - position).angle()
					colony.fire_projectile(position, e)
					Audio.sfx("spit", -14.0)

## A working Worker grabs the nearest carcass in reach and heads home with it.
func _try_harvest() -> void:
	if colony == null:
		return
	var c = colony.nearest_available_carcass(position, HARVEST_RANGE)
	if c == null:
		return
	var v: int = c.claim_and_take()
	if v > 0:
		carry_value = v
		carrying = true
		Audio.sfx("harvest", -8.0)
		if colony.fx != null:
			colony.fx.puff(position, Color(0.95, 0.85, 0.35), 8.0)
		_begin_return()

func take_damage(amount: float) -> void:
	if state == State.IDLE:
		return
	hp -= amount
	_hit_flash = 0.12
	if hp <= 0.0:
		_die_in_combat()

func _die_in_combat() -> void:
	if state == State.IDLE:
		return
	if colony != null:
		if colony.fx != null:
			colony.fx.puff(position, AntTypes.color_of(ant_type), 10.0)
		colony.release_ant(self)  # unregisters from trail + recycles + frees the pool slot

## Enemies only target ants that are actually out on the field.
func is_combatant_for_enemy() -> bool:
	return state != State.IDLE and visible

func is_active() -> bool:
	return state != State.IDLE

# --- helpers ------------------------------------------------------------------

func _ahead_blocks() -> bool:
	return is_instance_valid(ahead) \
		and ahead.state != State.IDLE \
		and ahead.trail == trail \
		and (ahead.state == State.OUTBOUND or ahead.state == State.WORKING)

func _place_on_trail() -> void:
	var p: Vector2 = trail.sample(dist)
	var tan: Vector2 = trail.tangent(dist)
	var normal := Vector2(-tan.y, tan.x)
	# lateral sway + a tiny constant offset so ants don't sit dead-centre
	var sway := sin(dist * WIGGLE_FREQ + phase) * WIGGLE_AMP
	position = p + normal * sway
	rotation = tan.angle() if state != State.RETURNING else (-tan).angle()
	scale.y = AntTypes.body_scale_of(ant_type) * (1.0 + sin(dist * 0.5 + phase) * 0.06)

## Trail was erased while we were on it: reroute home gracefully, never freeze.
func on_trail_removed() -> void:
	if state == State.IDLE:
		return
	_detach_and_free_return()

func _detach_and_free_return() -> void:
	trail = null
	ahead = null
	state = State.FREE_RETURN

func _arrive_home() -> void:
	if carrying and colony != null:
		colony.add_food(carry_value)
		# (no per-delivery toast — the Food counter shows income; avoids toast spam)
		carrying = false
		carry_value = 0
	if colony != null:
		colony.release_ant(self)

## Remove ourselves from the trail's bookkeeping (called by Colony on release).
func unregister_from_trail() -> void:
	if is_instance_valid(trail):
		trail.ants.erase(self)
		trail.outbound.erase(self)

func recycle() -> void:
	if _target_carcass != null and is_instance_valid(_target_carcass):
		_target_carcass.release_claim()  # free the body if we died mid-detour
	_target_carcass = null
	state = State.IDLE
	trail = null
	ahead = null
	visible = false

const ANT_TEX := preload("res://assets/sprites/ant.png")
const ANT_W := 15.0

func _draw() -> void:
	var h := ANT_W * ANT_TEX.get_height() / ANT_TEX.get_width()
	var mod := Color(1, 1, 1)
	if _hit_flash > 0.0:
		mod = mod.lerp(Color(1.7, 1.7, 1.7), _hit_flash / 0.12)  # white pop on a hit
	draw_texture_rect(ANT_TEX, Rect2(-ANT_W * 0.5, -h * 0.5, ANT_W, h), false, mod)
	# caste marker on the abdomen (head points +X)
	draw_circle(Vector2(-ANT_W * 0.24, 0.0), 2.0, AntTypes.color_of(ant_type))
	# a hauled carcass rides on the worker's back
	if carrying:
		draw_circle(Vector2(-ANT_W * 0.42, 0.0), 3.0, Color(0.85, 0.75, 0.35))
		draw_circle(Vector2(-ANT_W * 0.42, 0.0), 1.4, Color(0.6, 0.55, 0.3))
