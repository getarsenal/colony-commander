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
	match kind:
		Kind.LADYBUG: _draw_ladybug()
		Kind.PILLBUG: _draw_pillbug()
		Kind.FLY: _draw_fly()
		Kind.BOSS: _draw_boss()
		_: _draw_beetle()
	if hp < max_hp:
		_draw_hp()

func _flash(c: Color) -> Color:
	return c.lerp(Color.WHITE, _hit_flash / 0.12) if _hit_flash > 0.0 else c

func _legs(col: Color, b: float, w: float) -> void:
	for i in 3:
		var lx := -b * 0.5 + i * b * 0.5
		var sw := sin(_wiggle + i) * b * 0.3
		draw_line(Vector2(lx, -b * 0.6), Vector2(lx - b * 0.5, -b - 3.0 + sw), col, w)
		draw_line(Vector2(lx, b * 0.6), Vector2(lx - b * 0.5, b + 3.0 - sw), col, w)

func _draw_beetle() -> void:
	var c := _flash(Color(0.18, 0.06, 0.06))
	_legs(c, body, 1.2)
	draw_circle(Vector2(-2, 0), body, c)
	draw_circle(Vector2(body * 0.5, 0), body * 0.7, c)
	draw_circle(Vector2(-2, 0), body * 0.42, Color(0.7, 0.12, 0.12))
	draw_line(Vector2(body, -2), Vector2(body + 4, -4), c, 1.4)
	draw_line(Vector2(body, 2), Vector2(body + 4, 4), c, 1.4)

func _draw_ladybug() -> void:
	var red := _flash(Color(0.82, 0.16, 0.14))
	var blk := _flash(Color(0.10, 0.08, 0.07))
	_legs(blk, body, 1.1)
	draw_circle(Vector2(body * 0.6, 0), body * 0.55, blk)         # head
	draw_circle(Vector2(-1, 0), body, red)                        # shell
	draw_line(Vector2(-body, 0), Vector2(body * 0.4, 0), blk, 1.2)  # wing split
	for sp in [Vector2(-3, -3), Vector2(-3, 3), Vector2(1, -4), Vector2(1, 4), Vector2(-5, 0)]:
		draw_circle(sp, 1.5, blk)

func _draw_pillbug() -> void:
	var g := _flash(Color(0.42, 0.42, 0.46))
	var gd := _flash(Color(0.28, 0.28, 0.32))
	_legs(gd, body, 1.1)
	draw_circle(Vector2(0, 0), body, g)
	# armoured segments
	for i in range(-2, 3):
		var x := i * body * 0.38
		draw_arc(Vector2(x - body * 0.2, 0), body * 0.9, -PI * 0.5, PI * 0.5, 8, gd, 1.6)
	draw_circle(Vector2(body * 0.7, 0), body * 0.5, gd)  # head

func _draw_fly() -> void:
	var c := _flash(Color(0.16, 0.18, 0.22))
	# beating wings
	var wf := 0.5 + 0.5 * sin(_wiggle * 3.0)
	var wing := Color(0.75, 0.82, 0.95, 0.35)
	draw_circle(Vector2(-2, -body - 1), body * (0.7 + 0.3 * wf), wing)
	draw_circle(Vector2(-2, body + 1), body * (0.7 + 0.3 * wf), wing)
	draw_circle(Vector2(-2, 0), body, c)
	draw_circle(Vector2(body * 0.6, 0), body * 0.6, c)
	draw_circle(Vector2(body * 0.8, 0), body * 0.3, Color(0.7, 0.2, 0.2))  # red eyes

func _draw_boss() -> void:
	var o := _flash(Color(0.85, 0.42, 0.12))
	var od := _flash(Color(0.55, 0.22, 0.06))
	_legs(od, body, 2.2)
	# spiky carapace
	for i in 10:
		var a := TAU * i / 10.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(dir * body * 0.8, dir * (body + 6.0), od, 2.4)
	draw_circle(Vector2(-2, 0), body, o)
	draw_circle(Vector2(-2, 0), body * 0.6, od)
	draw_circle(Vector2(body * 0.7, 0), body * 0.6, o)
	# mandibles
	draw_line(Vector2(body, -3), Vector2(body + 8, -7), od, 3.0)
	draw_line(Vector2(body, 3), Vector2(body + 8, 7), od, 3.0)

func _draw_hp() -> void:
	var f := clampf(hp / max_hp, 0.0, 1.0)
	var w := body * 2.4
	var y := -body - 8.0
	draw_rect(Rect2(-w * 0.5, y, w, 2.6), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-w * 0.5, y, w * f, 2.6), Color(0.4, 0.85, 0.3))
