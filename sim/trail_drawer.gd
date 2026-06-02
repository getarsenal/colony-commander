## Turns player input into Trails: draw, colour-code by selected caste, and erase.
##
## Controls (also shown in the HUD):
##   1 / 2 / 3   select Worker / Soldier / Spitter
##   Left-drag   draw a trail (always anchored at the anthill)
##   E           toggle erase mode; in erase mode, click a trail to remove it
##   C           clear all trails
##
## Erasing/redrawing reroutes any ants on the affected trail home gracefully
## (never freeze or teleport) — see Ant.on_trail_removed().
class_name TrailDrawer
extends Node2D

const ERASE_HIT_DIST := 30.0   # generous so a finger-tap reliably grabs a trail

var colony: Colony
var trail_container: Node2D
var hill_pos := Vector2.ZERO

var current_type: int = AntTypes.Type.WORKER
var erase_mode := false

var _active_trail: Trail = null   # the trail being dragged right now
var _erasing := false             # finger held down in erase mode (swipe-to-erase)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if erase_mode:
					_erasing = true
				_on_press(get_global_mouse_position())
			else:
				_erasing = false
				_on_release()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# right-click is a convenient erase regardless of mode (desktop)
			_erase_at(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		if _active_trail != null:
			_active_trail.try_add_point(get_global_mouse_position())
		elif _erasing:
			# swipe across trails to wipe them out
			_erase_at(get_global_mouse_position())

func _handle_key(keycode: int) -> void:
	match keycode:
		KEY_1:
			set_caste(AntTypes.Type.WORKER)
		KEY_2:
			set_caste(AntTypes.Type.SOLDIER)
		KEY_3:
			set_caste(AntTypes.Type.SPITTER)
		KEY_E:
			toggle_erase()
		KEY_C:
			clear_all()

# --- public command surface (shared by keyboard + on-screen touch controls) ---

func set_caste(type: int) -> void:
	current_type = type
	# Picking a caste is a drawing action; leave erase mode so the next drag draws.
	erase_mode = false

func toggle_erase() -> void:
	erase_mode = not erase_mode

func set_erase(on: bool) -> void:
	erase_mode = on

func clear_all() -> void:
	_clear_all()

func _on_press(world_pos: Vector2) -> void:
	if erase_mode:
		_erase_at(world_pos)
		return
	# begin a new trail, always anchored at the hill
	var trail_script: Script = load("res://sim/trail.gd")
	_active_trail = trail_script.new()
	trail_container.add_child(_active_trail)
	_active_trail.setup(current_type, hill_pos)
	_active_trail.try_add_point(world_pos)

func _on_release() -> void:
	if _active_trail == null:
		return
	if not _active_trail.finalize_drawing():
		_active_trail.queue_free()  # too short — discard
	_active_trail = null

func _erase_at(world_pos: Vector2) -> void:
	var best: Trail = null
	var best_d := ERASE_HIT_DIST
	for child in trail_container.get_children():
		if child is Trail and child != _active_trail:
			var d: float = child.distance_to_point(world_pos)
			if d < best_d:
				best_d = d
				best = child
	if best != null:
		if colony != null and colony.fx != null:
			colony.fx.puff(world_pos, Color(0.93, 0.48, 0.45), 12.0)
		best.dissolve()
		best.queue_free()

func _clear_all() -> void:
	for child in trail_container.get_children():
		if child is Trail:
			child.dissolve()
			child.queue_free()
	_active_trail = null
