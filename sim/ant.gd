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
	WORKING,      # paused at the trail end doing its job (stub in step 1)
	RETURNING,    # walking back down the trail to the hill
	FREE_RETURN,  # trail was erased mid-trip — walk straight home, gracefully
}

# --- Feel tuning (handoff §4 "the magic is here") -----------------------------
const MIN_GAP := 9.0          # min pixels between an ant and the one ahead -> queueing/bunching
const WIGGLE_AMP := 2.6       # lateral sway amplitude (px) -> "living column", not a conga line
const WIGGLE_FREQ := 0.09     # how tight the sway is along the trail
const WORK_TIME := 0.55       # seconds paused at the destination
const ARRIVE_EPS := 5.0       # px tolerance for "home"

var state: int = State.IDLE
var ant_type: int = AntTypes.Type.WORKER
var dist: float = 0.0         # distance along the trail's baked curve, in px
var speed: float = 100.0
var phase: float = 0.0        # per-ant sway phase so the column desyncs
var work_timer: float = 0.0

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
	speed = AntTypes.speed_of(ant_type) * randf_range(0.88, 1.12)
	phase = randf() * TAU
	scale = Vector2.ONE * AntTypes.body_scale_of(ant_type)
	position = trail.sample(0.0)
	visible = true
	queue_redraw()  # refresh the caste-coloured marker for this spawn

func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	match state:
		State.OUTBOUND:
			_advance_outbound(delta)
		State.WORKING:
			work_timer -= delta
			# little bob in place while "working"
			scale.y = AntTypes.body_scale_of(ant_type) * (1.0 + sin(Time.get_ticks_msec() * 0.012 + phase) * 0.08)
			if work_timer <= 0.0:
				_begin_return()
		State.RETURNING:
			_advance_return(delta)
		State.FREE_RETURN:
			_advance_free_return(delta)

func _advance_outbound(delta: float) -> void:
	if not is_instance_valid(trail) or not trail.is_usable():
		_detach_and_free_return()
		return
	var step := speed * delta
	var target := dist + step
	# Congestion: never overtake the ant ahead — clamp behind it, which makes
	# columns bunch at bottlenecks and pile up at the destination.
	if _ahead_blocks():
		target = min(target, ahead.dist - MIN_GAP)
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
	if colony != null:
		colony.release_ant(self)

## Remove ourselves from the trail's bookkeeping (called by Colony on release).
func unregister_from_trail() -> void:
	if is_instance_valid(trail):
		trail.ants.erase(self)
		trail.outbound.erase(self)

func recycle() -> void:
	state = State.IDLE
	trail = null
	ahead = null
	visible = false

func _draw() -> void:
	var type_color := AntTypes.color_of(ant_type)
	# body: abdomen / thorax / head along +X (head forward)
	draw_circle(Vector2(-4.0, 0.0), 3.2, _base_color)   # abdomen
	draw_circle(Vector2(0.0, 0.0), 2.4, _base_color)    # thorax
	draw_circle(Vector2(3.6, 0.0), 2.0, _base_color)    # head
	# caste marker on the abdomen
	draw_circle(Vector2(-4.0, 0.0), 1.6, type_color)
	# antennae
	draw_line(Vector2(4.6, -0.5), Vector2(7.2, -2.6), _base_color, 0.8)
	draw_line(Vector2(4.6, 0.5), Vector2(7.2, 2.6), _base_color, 0.8)
	# three pairs of legs
	for lx in [-2.0, 0.0, 2.0]:
		draw_line(Vector2(lx, 0.0), Vector2(lx - 1.0, -4.0), _base_color, 0.8)
		draw_line(Vector2(lx, 0.0), Vector2(lx - 1.0, 4.0), _base_color, 0.8)
