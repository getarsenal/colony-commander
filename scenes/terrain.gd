## The jungle floor + anthill, drawn once into a static layer (handoff §5 art;
## modelled on the original Anthill's lush, leaf-littered ground).
##
## Heavy decor (hundreds of leaves + plants) is generated with a fixed seed and
## painted a single time — the camera is fixed, so this never needs to redraw,
## keeping the per-frame cost on the dynamic layers only.
class_name Terrain
extends Node2D

var hill_pos := Vector2.ZERO
var area := Vector2(820, 540)   # half-extent of decor (sized to the zoomed view)

# leaf-litter palette: mostly jungle greens with some leaf-brown
const LEAF_COLS := [
	Color(0.17, 0.33, 0.14), Color(0.22, 0.40, 0.17), Color(0.28, 0.47, 0.20),
	Color(0.14, 0.26, 0.12), Color(0.33, 0.42, 0.18), Color(0.31, 0.25, 0.13),
	Color(0.39, 0.31, 0.16), Color(0.20, 0.30, 0.13),
]

var _leaves: Array = []     # {p, len, rot, col}
var _tufts: Array = []      # {p, n, spread, col, h}
var _flowers: Array = []    # {p, col, n, r}
var _pebbles: Array = []    # {p, r, col}
var _grains: Array = []     # mound texture {off, r, col}

func _ready() -> void:
	z_index = -20  # under trails, ants, everything
	_build()
	queue_redraw()

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 70413

	for i in 1500:
		var p := hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y))
		_leaves.append({
			"p": p,
			"len": rng.randf_range(10.0, 22.0),
			"rot": rng.randf() * TAU,
			"col": LEAF_COLS[rng.randi() % LEAF_COLS.size()],
		})
	for i in 42:
		var p := hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y))
		if p.distance_to(hill_pos) < 95.0:
			continue
		_tufts.append({
			"p": p,
			"n": rng.randi_range(6, 10),
			"spread": rng.randf_range(0.7, 1.2),
			"col": Color(0.22, 0.46, 0.18).lerp(Color(0.42, 0.62, 0.24), rng.randf()),
			"h": rng.randf_range(20.0, 38.0),
		})
	for i in 12:
		var p := hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y))
		if p.distance_to(hill_pos) < 110.0:
			continue
		var pal := [Color(0.92, 0.36, 0.62), Color(0.86, 0.28, 0.30), Color(0.72, 0.42, 0.86), Color(0.95, 0.55, 0.25)]
		_flowers.append({"p": p, "col": pal[rng.randi() % pal.size()], "n": rng.randi_range(5, 6), "r": rng.randf_range(10.0, 16.0)})
	for i in 30:
		var p := hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y))
		var g := rng.randf_range(0.32, 0.5)
		_pebbles.append({"p": p, "r": rng.randf_range(4.0, 9.0), "col": Color(g, g * 0.95, g * 0.88)})
	for i in 60:
		var a := rng.randf() * TAU
		var rad := sqrt(rng.randf()) * 52.0
		var g := rng.randf_range(0.30, 0.54)
		_grains.append({"off": Vector2(cos(a), sin(a) * 0.92) * rad - Vector2(0, 4), "r": rng.randf_range(0.9, 2.2),
			"col": Color(g, g * 0.74, g * 0.46, 0.85)})

func _draw() -> void:
	# base soil + two soft mossy washes
	var g := Rect2(hill_pos - area - Vector2(80, 80), area * 2 + Vector2(160, 160))
	draw_rect(g, Color(0.15, 0.18, 0.10))
	draw_circle(hill_pos + Vector2(-300, -170), 460, Color(0.13, 0.22, 0.10, 0.5))
	draw_circle(hill_pos + Vector2(360, 210), 520, Color(0.17, 0.25, 0.11, 0.4))
	draw_circle(hill_pos + Vector2(120, -340), 380, Color(0.20, 0.16, 0.10, 0.4))

	# dense leaf litter
	for lf in _leaves:
		_draw_leaf(lf["p"], lf["len"], lf["rot"], lf["col"])
	# pebbles
	for p in _pebbles:
		draw_circle(p["p"] + Vector2(0, 2), p["r"], Color(0, 0, 0, 0.22))
		draw_circle(p["p"], p["r"], p["col"])
		draw_circle(p["p"] - Vector2(p["r"] * 0.3, p["r"] * 0.3), p["r"] * 0.5, p["col"].lightened(0.2))
	# grass / fern tufts
	for t in _tufts:
		_draw_tuft(t)
	# flowers
	for fl in _flowers:
		_draw_flower(fl)

	_draw_anthill()

func _draw_leaf(p: Vector2, length: float, rot: float, col: Color) -> void:
	var dir := Vector2(cos(rot), sin(rot))
	var perp := Vector2(-dir.y, dir.x)
	var w := length * 0.42
	var poly := PackedVector2Array([
		p - dir * length * 0.5,
		p + perp * w * 0.5 + dir * length * 0.05,
		p + dir * length * 0.5,
		p - perp * w * 0.5 + dir * length * 0.05,
	])
	draw_colored_polygon(poly, col)
	draw_line(p - dir * length * 0.5, p + dir * length * 0.5, col.darkened(0.3), 1.0)  # midrib

func _draw_tuft(t: Dictionary) -> void:
	var p: Vector2 = t["p"]
	var col: Color = t["col"]
	var hgt: float = t["h"]
	var n: int = t["n"]
	var spread: float = t["spread"]
	draw_circle(p + Vector2(0, 2), 5.0, Color(0, 0, 0, 0.18))  # base shadow
	for i in n:
		var a: float = (float(i) / max(1, n - 1) - 0.5) * spread
		var mid := p + Vector2(sin(a), -0.6) * hgt * 0.5
		var tip := p + Vector2(sin(a) * 1.4, -1.0) * hgt
		draw_line(p, mid, col.darkened(0.1), 2.4)
		draw_line(mid, tip, col, 1.6)

func _draw_flower(fl: Dictionary) -> void:
	var p: Vector2 = fl["p"]
	var col: Color = fl["col"]
	var n: int = fl["n"]
	var r: float = fl["r"]
	# a couple of leaves under it
	_draw_leaf(p + Vector2(-r, r * 0.6), r * 2.2, 0.6, Color(0.26, 0.46, 0.20))
	_draw_leaf(p + Vector2(r, r * 0.5), r * 2.0, -0.7, Color(0.24, 0.44, 0.18))
	for i in n:
		var a := TAU * i / n
		var pc := p + Vector2(cos(a), sin(a)) * r * 0.7
		draw_circle(pc, r * 0.55, col)
	draw_circle(p, r * 0.5, col.lightened(0.15))
	draw_circle(p, r * 0.28, Color(0.97, 0.85, 0.35))  # pollen centre

func _draw_anthill() -> void:
	var h := hill_pos
	# irregular reddish dirt mound (several overlapping dirt blobs)
	draw_circle(h + Vector2(0, 9), 60.0, Color(0, 0, 0, 0.22))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 12:
		var a := TAU * i / 12.0
		var off := Vector2(cos(a), sin(a) * 0.9) * rng.randf_range(34.0, 50.0)
		draw_circle(h + off, rng.randf_range(16.0, 24.0), Color(0.34, 0.21, 0.12))
	draw_circle(h, 52.0, Color(0.37, 0.24, 0.14))
	draw_circle(h + Vector2(0, -3), 40.0, Color(0.45, 0.30, 0.17))
	draw_circle(h + Vector2(0, -5), 28.0, Color(0.52, 0.36, 0.21))
	for gr in _grains:
		draw_circle(h + gr["off"], gr["r"], gr["col"])
	# entrance: dark rim with a bright lit throat
	draw_circle(h + Vector2(0, -4), 15.0, Color(0.10, 0.07, 0.05))
	draw_circle(h + Vector2(0, -4), 11.0, Color(0.30, 0.21, 0.13))
	draw_circle(h + Vector2(0, -5), 7.0, Color(0.78, 0.70, 0.52))
	draw_arc(h + Vector2(0, -4), 15.0, PI * 0.9, PI * 1.5, 14, Color(0.60, 0.46, 0.28, 0.6), 2.0)
