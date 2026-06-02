## An attacking bug. Several distinct kinds (handoff §5/§7), faithful to the
## original's varied roster: a basic Beetle, a quick Ladybug, an armoured Pillbug
## tank, a fast Fly, and a hulking Boss. Each has its own stats, food reward and
## drawn look. Pooled by the WaveDirector like before.
class_name Enemy
extends Node2D

enum State { IDLE, ADVANCING, FIGHTING }
enum Kind { BEETLE, LADYBUG, PILLBUG, FLY, BOSS }

# per-kind: hp, walk speed, bite (vs ants), hill bite, body radius, food reward
const STATS := {
	Kind.BEETLE:  {"hp": 30.0, "spd": 34.0, "bite": 6.0,  "hill": 10.0, "body": 7.0,  "food": 5},
	Kind.LADYBUG: {"hp": 22.0, "spd": 42.0, "bite": 5.0,  "hill": 8.0,  "body": 7.0,  "food": 4},
	Kind.PILLBUG: {"hp": 64.0, "spd": 22.0, "bite": 9.0,  "hill": 14.0, "body": 9.0,  "food": 8},
	Kind.FLY:     {"hp": 14.0, "spd": 66.0, "bite": 4.0,  "hill": 6.0,  "body": 5.5, "food": 3},
	Kind.BOSS:    {"hp": 260.0,"spd": 18.0, "bite": 22.0, "hill": 26.0, "body": 16.0, "food": 40},
}

const TOUCH_RANGE := 15.0
const ATTACK_INTERVAL := 0.7

const TEX := {
	Kind.BEETLE:  preload("res://assets/sprites/bug_beetle.png"),
	Kind.LADYBUG: preload("res://assets/sprites/bug_ladybug.png"),
	Kind.PILLBUG: preload("res://assets/sprites/bug_pillbug.png"),
	Kind.FLY:     preload("res://assets/sprites/bug_fly.png"),
	Kind.BOSS:    preload("res://assets/sprites/bug_boss.png"),
}
const DRAW_W := {
	Kind.BEETLE: 24.0, Kind.LADYBUG: 22.0, Kind.PILLBUG: 26.0, Kind.FLY: 24.0, Kind.BOSS: 56.0,
}

var state: int = State.IDLE
var kind: int = Kind.BEETLE
var hp := 30.0
var max_hp := 30.0
var speed := 34.0
var bite := 6.0
var hill_bite := 10.0
var body := 7.0
var food_value := 5

var colony = null
var director = null

var _target_ant = null
var _attack_timer := 0.0
var _hit_flash := 0.0
var _wiggle := 0.0

func _ready() -> void:
	visible = false
	z_index = 5

func init_pooled(p_colony, p_director) -> void:
	colony = p_colony
	director = p_director
	state = State.IDLE
	visible = false

func spawn(pos: Vector2, p_kind: int) -> void:
	kind = p_kind
	var s: Dictionary = STATS[kind]
	max_hp = s["hp"]
	hp = max_hp
	speed = s["spd"] * randf_range(0.9, 1.1)
	bite = s["bite"]
	hill_bite = s["hill"]
	body = s["body"]
	food_value = s["food"]
	position = pos
	state = State.ADVANCING
	_target_ant = null
	_attack_timer = 0.0
	_hit_flash = 0.0
	_wiggle = randf() * TAU
	scale = Vector2.ONE
	visible = true
	queue_redraw()

func is_alive() -> bool:
	return state != State.IDLE

func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	_wiggle += delta * (14.0 if kind == Kind.FLY else 9.0)
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)

	if not is_instance_valid(_target_ant) or not _target_ant.is_combatant_for_enemy():
		_target_ant = colony.nearest_ant(position, TOUCH_RANGE + body) if colony != null else null

	if is_instance_valid(_target_ant):
		state = State.FIGHTING
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_timer = ATTACK_INTERVAL
			_target_ant.take_damage(bite)
	else:
		state = State.ADVANCING
		_advance(delta)
	queue_redraw()

func _advance(delta: float) -> void:
	var hill: Vector2 = colony.hill_pos if colony != null else Vector2.ZERO
	var to_hill := hill - position
	var d := to_hill.length()
	if d <= 28.0 + body:
		if colony != null:
			colony.damage_hill(hill_bite)
		_despawn()
		return
	position += to_hill / d * speed * delta
	rotation = to_hill.angle()

func take_damage(amount: float) -> void:
	if state == State.IDLE:
		return
	hp -= amount
	_hit_flash = 0.12
	if hp <= 0.0:
		_die()

func _die() -> void:
	if director != null:
		director.on_enemy_killed(position, food_value, kind == Kind.BOSS)
	_despawn()

func _despawn() -> void:
	state = State.IDLE
	_target_ant = null
	visible = false
	if director != null:
		director.release(self)

func force_despawn() -> void:
	if state != State.IDLE:
		_despawn()

# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	var tex: Texture2D = TEX[kind]
	var w: float = DRAW_W[kind]
	var h := w * tex.get_height() / tex.get_width()
	var mod := Color(1, 1, 1)
	if _hit_flash > 0.0:
		mod = mod.lerp(Color(1.7, 1.7, 1.7), _hit_flash / 0.12)
	# subtle walking bob via vertical squash
	var bob := 1.0 + sin(_wiggle) * 0.05
	draw_texture_rect(tex, Rect2(-w * 0.5, -h * 0.5 * bob, w, h * bob), false, mod)
	if hp < max_hp:
		var f := clampf(hp / max_hp, 0.0, 1.0)
		var bw := w * 0.8
		var y := -h * 0.5 - 6.0
		draw_rect(Rect2(-bw * 0.5, y, bw, 2.8), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-bw * 0.5, y, bw * f, 2.8), Color(0.4, 0.85, 0.3))
