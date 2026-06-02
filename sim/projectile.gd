## A Spitter's acid glob: a short-lived homing-ish projectile (handoff §5).
##
## Spawned by a Spitter ant at an enemy; flies to where the enemy was, damages
## it on contact, then expires. Pooled by the WaveDirector so sustained
## spitting never thrashes the heap.
class_name Projectile
extends Node2D

const SPEED := 320.0
const HIT_RADIUS := 10.0
const DAMAGE := 7.0
const MAX_LIFE := 1.2

var _alive := false
var _vel := Vector2.ZERO
var _life := 0.0
var _target = null
var director = null

func _ready() -> void:
	visible = false
	z_index = 12  # above ants

func init_pooled(p_director) -> void:
	director = p_director
	_alive = false
	visible = false

func fire(from: Vector2, target) -> void:
	position = from
	_target = target
	_alive = true
	_life = MAX_LIFE
	var dir: Vector2 = (target.position - from).normalized() if is_instance_valid(target) else Vector2.RIGHT
	_vel = dir * SPEED
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if not _alive:
		return
	# gentle re-aim toward a still-living target so glob tracks a moving bug
	if is_instance_valid(_target) and _target.is_alive():
		var desired: Vector2 = (_target.position - position).normalized() * SPEED
		_vel = _vel.lerp(desired, 0.15)
	position += _vel * delta
	rotation = _vel.angle()
	_life -= delta
	if _life <= 0.0:
		_despawn()
		return
	if is_instance_valid(_target) and _target.is_alive() \
			and position.distance_to(_target.position) <= HIT_RADIUS:
		_target.take_damage(DAMAGE)
		if director != null:
			director.splash(position)
		_despawn()

func _despawn() -> void:
	_alive = false
	visible = false
	_target = null
	if director != null:
		director.release_projectile(self)

## Remove in flight (used on a level reset).
func force_despawn() -> void:
	if _alive:
		_despawn()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.4, Color(0.55, 0.85, 0.25, 0.9))
	draw_circle(Vector2(-3.0, 0.0), 2.0, Color(0.45, 0.75, 0.20, 0.5))  # tail
