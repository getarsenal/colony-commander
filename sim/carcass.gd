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
var _bscale := 1.0

func _ready() -> void:
	visible = false
	z_index = 1  # just above trails, below ants

func init_pooled(p_director) -> void:
	director = p_director
	_alive = false
	visible = false

func drop_at(pos: Vector2, value: int = FOOD_VALUE) -> void:
	position = pos
	rotation = randf() * TAU
	food_value = value
	_bscale = clampf(0.85 + value * 0.035, 0.85, 2.2)  # bigger bodies = bigger husks
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

const TEX := preload("res://assets/sprites/carcass.png")

func _draw() -> void:
	# a pale husk with a soft food-glow so it reads as "grab me"
	var sz := 18.0 * _bscale
	var glow := 0.5 + sin(_bob) * 0.12
	draw_circle(Vector2.ZERO, sz * 0.62, Color(0.95, 0.85, 0.35, 0.16 * glow))
	draw_texture_rect(TEX, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false)
