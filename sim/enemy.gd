## An attacking bug: the thing your colony defends against (handoff §5 / §7).
##
## Faithful to Anthill: enemies enter from the map edge and advance on the
## anthill. Ants whose trail reaches them fight them; if an enemy reaches the
## hill it bites the base (hill HP) and then dies. A slain enemy drops a Carcass
## for Workers to harvest — that carcass IS the food economy's source.
##
## Pooled by WaveDirector exactly like ants are pooled by the Colony, so heavy
## waves never instantiate/free per spawn (same 60fps discipline as step 1).
class_name Enemy
extends Node2D

enum State { IDLE, ADVANCING, FIGHTING }

# --- tuning -------------------------------------------------------------------
const SPEED := 34.0              # px/sec crawl toward the hill
const MAX_HP := 30.0
const TOUCH_RANGE := 15.0        # how close an ant must be for us to bite it
const ATTACK_INTERVAL := 0.7
const ATTACK_DAMAGE := 6.0
const HILL_BITE := 10.0          # damage dealt to the base if we reach it
const BODY := 7.0                # draw radius

var state: int = State.IDLE
var hp: float = MAX_HP
var speed: float = SPEED

var colony = null                # spatial queries + hill pos/HP (set at pool build)
var director = null              # back-ref for carcass drop + pool release

var _target_ant = null
var _attack_timer := 0.0
var _hit_flash := 0.0            # white flash timer for juice
var _wiggle := 0.0               # per-enemy gait phase

func _ready() -> void:
	visible = false
	z_index = 5  # above trails, roughly with ants

func init_pooled(p_colony, p_director) -> void:
	colony = p_colony
	director = p_director
	state = State.IDLE
	visible = false

func spawn(pos: Vector2) -> void:
	position = pos
	hp = MAX_HP
	speed = SPEED * randf_range(0.85, 1.15)
	state = State.ADVANCING
	_target_ant = null
	_attack_timer = 0.0
	_hit_flash = 0.0
	_wiggle = randf() * TAU
	visible = true
	queue_redraw()

func is_alive() -> bool:
	return state != State.IDLE

func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	_wiggle += delta * 9.0
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)

	# Engage the nearest ant in reach; otherwise keep marching on the hill.
	if not is_instance_valid(_target_ant) or not _target_ant.is_combatant_for_enemy():
		_target_ant = colony.nearest_ant(position, TOUCH_RANGE) if colony != null else null

	if is_instance_valid(_target_ant):
		state = State.FIGHTING
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_timer = ATTACK_INTERVAL
			_target_ant.take_damage(ATTACK_DAMAGE)
	else:
		state = State.ADVANCING
		_advance(delta)
	queue_redraw()

func _advance(delta: float) -> void:
	var hill: Vector2 = colony.hill_pos if colony != null else Vector2.ZERO
	var to_hill := hill - position
	var d := to_hill.length()
	if d <= 30.0:
		# reached the base: bite it, then we're spent (no carcass — self-destruct)
		if colony != null:
			colony.damage_hill(HILL_BITE)
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
		director.on_enemy_killed(position)   # carcass drop + kill FX
	_despawn()

func _despawn() -> void:
	state = State.IDLE
	_target_ant = null
	visible = false
	if director != null:
		director.release(self)

## Remove from the field without dropping a carcass (used on a base breach).
func force_despawn() -> void:
	if state == State.IDLE:
		return
	_despawn()

func _draw() -> void:
	# squat beetle: dark carapace + a warning-red core, legs splayed by gait
	var carapace := Color(0.18, 0.05, 0.06)
	if _hit_flash > 0.0:
		carapace = carapace.lerp(Color.WHITE, _hit_flash / 0.12)
	for i in 3:
		var lx := -3.0 + i * 3.0
		var sw := sin(_wiggle + i) * 2.2
		draw_line(Vector2(lx, -BODY * 0.6), Vector2(lx - 3.0, -BODY - 2.0 + sw), carapace, 1.2)
		draw_line(Vector2(lx, BODY * 0.6), Vector2(lx - 3.0, BODY + 2.0 - sw), carapace, 1.2)
	draw_circle(Vector2(-2.0, 0.0), BODY, carapace)            # abdomen
	draw_circle(Vector2(BODY * 0.5, 0.0), BODY * 0.7, carapace) # head
	draw_circle(Vector2(-2.0, 0.0), BODY * 0.42, Color(0.7, 0.12, 0.12))  # red core
	# pincers
	draw_line(Vector2(BODY, -2.0), Vector2(BODY + 4.0, -4.0), carapace, 1.4)
	draw_line(Vector2(BODY, 2.0), Vector2(BODY + 4.0, 4.0), carapace, 1.4)
	# HP pip when hurt
	if hp < MAX_HP:
		var f := clampf(hp / MAX_HP, 0.0, 1.0)
		draw_rect(Rect2(-8.0, -BODY - 7.0, 16.0, 2.5), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-8.0, -BODY - 7.0, 16.0 * f, 2.5), Color(0.4, 0.85, 0.3))
