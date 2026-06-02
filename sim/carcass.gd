## A slain enemy's body: the food source Workers harvest (handoff §5).
##
## Drops where an enemy died. A Worker that reaches a trail tip near a carcass
## claims it, carries it home, and converts it to colony food. Claiming is
## exclusive so two workers never fight over the same body. Pooled by the
## WaveDirector alongside enemies.
class_name Carcass
extends Node2D

const FOOD_VALUE := 5
const BODY := 6.0

var food_value: int = FOOD_VALUE
var claimed := false
var _alive := false
var director = null
var _bob := 0.0

func _ready() -> void:
	visible = false
	z_index = 1  # just above trails, below ants

func init_pooled(p_director) -> void:
	director = p_director
	_alive = false
	visible = false

func drop_at(pos: Vector2) -> void:
	position = pos
	rotation = randf() * TAU
	food_value = FOOD_VALUE
	claimed = false
	_alive = true
	_bob = randf() * TAU
	visible = true
	queue_redraw()

func is_available() -> bool:
	return _alive and not claimed

## A worker takes the body: returns the food value and removes us from the field.
func claim_and_take() -> int:
	if not is_available():
		return 0
	claimed = true
	var v := food_value
	_despawn()
	return v

func _despawn() -> void:
	_alive = false
	visible = false
	if director != null:
		director.release_carcass(self)

## Remove without feeding anyone (used on a level reset).
func force_despawn() -> void:
	if _alive:
		_despawn()

func _process(delta: float) -> void:
	if not _alive:
		return
	_bob += delta * 3.0

func _draw() -> void:
	# a curled, pale husk with a soft food-glow so it reads as "grab me"
	var glow := 0.5 + sin(_bob) * 0.12
	draw_circle(Vector2.ZERO, BODY + 3.0, Color(0.95, 0.85, 0.35, 0.12 * glow))
	draw_circle(Vector2.ZERO, BODY, Color(0.55, 0.50, 0.30))
	draw_circle(Vector2(-2.0, -1.0), BODY * 0.55, Color(0.68, 0.62, 0.40))
	draw_arc(Vector2.ZERO, BODY + 1.5, 0.0, TAU, 10, Color(0.30, 0.26, 0.16), 1.2)
