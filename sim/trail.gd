## A pheromone trail: a player-drawn Curve2D originating at the anthill, with an
## assigned ant caste + colour. Ants flow along it as a metered stream.
##
## The node lives at the world origin; its Curve2D points are stored in world
## (== screen) coordinates, so ants read `sample(dist)` directly as positions.
class_name Trail
extends Node2D

const MIN_POINT_DIST := 12.0   # don't record drag points closer than this (smooths input)
const MIN_TRAIL_LEN := 40.0    # discard accidental taps

var curve := Curve2D.new()
var ant_type: int = AntTypes.Type.WORKER
var color := Color.WHITE

# spawn metering
var spawn_interval := 0.34     # seconds between ants on this trail
var spawn_accum := 0.0

# bookkeeping
var ants: Array = []           # every active ant currently assigned to this trail
var outbound: Array = []       # ordered subset (oldest first) used for spacing
var _drawing := true           # true while the player is still dragging it out

func _ready() -> void:
	z_index = 0  # trails draw beneath ants

func setup(p_type: int, origin: Vector2) -> void:
	ant_type = p_type
	color = AntTypes.color_of(p_type)
	curve.clear_points()
	curve.add_point(origin)   # every trail starts at the anthill
	queue_redraw()

## Add a drag point if it's far enough from the last one. Returns true if added.
func try_add_point(p: Vector2) -> bool:
	if curve.point_count == 0:
		curve.add_point(p)
		queue_redraw()
		return true
	var last := curve.get_point_position(curve.point_count - 1)
	if last.distance_to(p) >= MIN_POINT_DIST:
		curve.add_point(p)
		queue_redraw()
		return true
	return false

## Finalise after the player releases. Returns false if too short to keep.
func finalize_drawing() -> bool:
	_drawing = false
	if curve.point_count < 2 or length() < MIN_TRAIL_LEN:
		return false
	queue_redraw()
	return true

func is_usable() -> bool:
	return not _drawing and curve.point_count >= 2 and length() > 0.0

func length() -> float:
	return curve.get_baked_length()

func sample(d: float) -> Vector2:
	return curve.sample_baked(clampf(d, 0.0, length()))

func tangent(d: float) -> Vector2:
	var l := length()
	var a := clampf(d - 2.0, 0.0, l)
	var b := clampf(d + 2.0, 0.0, l)
	var v := curve.sample_baked(b) - curve.sample_baked(a)
	return v.normalized() if v.length() > 0.001 else Vector2.RIGHT

## Distance from an arbitrary point to this trail (for erase hit-testing).
func distance_to_point(p: Vector2) -> float:
	if curve.point_count < 2:
		if curve.point_count == 1:
			return p.distance_to(curve.get_point_position(0))
		return INF
	var pts := curve.get_baked_points()
	var best := INF
	for pt in pts:
		best = min(best, p.distance_to(pt))
	return best

## Called when the player erases this trail: release every ant gracefully, then
## the caller frees the node.
func dissolve() -> void:
	for a in ants.duplicate():
		a.on_trail_removed()
	ants.clear()
	outbound.clear()

const DOT_SPACING := 13.0   # gap between pheromone dots

func _draw() -> void:
	if curve.point_count < 2:
		# while starting a drag, show the origin dot
		if curve.point_count == 1:
			_dot(curve.get_point_position(0))
		return
	# dotted pheromone trail (worker blue / soldier yellow / spitter pink)
	var total := curve.get_baked_length()
	var d := 0.0
	while d <= total:
		_dot(curve.sample_baked(d))
		d += DOT_SPACING
	# a brighter node at the destination
	var endp := curve.sample_baked(total)
	draw_circle(endp, 6.0, Color(color, 0.22))
	draw_circle(endp, 3.4, Color(color, 1.0))

func _dot(p: Vector2) -> void:
	draw_circle(p, 5.0, Color(color, 0.16))   # soft glow
	draw_circle(p, 2.7, Color(color, 0.95))   # bright core
