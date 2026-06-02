## The jungle floor + anthill, drawn once into a static layer from baked sprite
## art (assets/sprites). The camera is fixed, so this paints a single time.
class_name Terrain
extends Node2D

const GROUND := preload("res://assets/sprites/ground.png")
const HILL := preload("res://assets/sprites/hill.png")
const FERN := preload("res://assets/sprites/fern.png")
const FLOWER := preload("res://assets/sprites/flower.png")
const MUSHROOM := preload("res://assets/sprites/mushroom.png")
const ROCK := preload("res://assets/sprites/rock.png")
const BIGLEAF := preload("res://assets/sprites/bigleaf.png")

const HILL_SIZE := 184.0

var hill_pos := Vector2.ZERO
var area := Vector2(900, 580)   # half-extent of decor around the hill

var _plants: Array = []   # {tex, pos, scale, flip, anchor}

func _ready() -> void:
	z_index = -20
	_build()
	queue_redraw()

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 70413
	# (texture, count, min_scale, max_scale, clearance, anchor)
	var specs := [
		[ROCK, 12, 0.5, 1.0, 95.0, "center"],
		[BIGLEAF, 11, 0.55, 1.05, 120.0, "bottom"],
		[FERN, 30, 0.55, 1.05, 110.0, "bottom"],
		[MUSHROOM, 12, 0.5, 0.95, 110.0, "bottom"],
		[FLOWER, 12, 0.6, 1.0, 120.0, "bottom"],
	]
	for spec in specs:
		for i in int(spec[1]):
			var p := hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y))
			if p.distance_to(hill_pos) < float(spec[4]):
				continue
			_plants.append({"tex": spec[0], "pos": p, "scale": rng.randf_range(spec[2], spec[3]),
				"flip": rng.randf() < 0.5, "anchor": spec[5]})
	# paint back-to-front so nearer plants overlap farther ones
	_plants.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)

func _draw() -> void:
	# tiled ground covering the decor area
	var rect := Rect2(hill_pos - area - Vector2(64, 64), area * 2 + Vector2(128, 128))
	var tw := GROUND.get_width()
	var th := GROUND.get_height()
	var sx := int(floor(rect.position.x / tw))
	var sy := int(floor(rect.position.y / th))
	var ex := int(ceil((rect.position.x + rect.size.x) / tw))
	var ey := int(ceil((rect.position.y + rect.size.y) / th))
	for gy in range(sy, ey):
		for gx in range(sx, ex):
			draw_texture(GROUND, Vector2(gx * tw, gy * th))

	# props/plants — bottom-anchored ones look rooted; rocks sit centred
	for pl in _plants:
		var t: Texture2D = pl["tex"]
		var s: float = pl["scale"]
		var w := t.get_width() * s
		var h := t.get_height() * s
		var pos: Vector2 = pl["pos"]
		var oy := h * 0.5 if pl["anchor"] == "center" else h
		var r := Rect2(pos.x - w * 0.5, pos.y - oy, w, h)
		draw_texture_rect(t, r, false, Color.WHITE, pl["flip"])

	# anthill mound
	draw_texture_rect(HILL, Rect2(hill_pos - Vector2(HILL_SIZE, HILL_SIZE) * 0.5, Vector2(HILL_SIZE, HILL_SIZE)), false)
