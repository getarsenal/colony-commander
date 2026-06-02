## The jungle floor + anthill, drawn once into a static layer from baked sprite
## art (assets/sprites). The camera is fixed, so this paints a single time.
class_name Terrain
extends Node2D

const GROUND := preload("res://assets/sprites/ground.png")
const HILL := preload("res://assets/sprites/hill.png")
const FERN := preload("res://assets/sprites/fern.png")
const FLOWER := preload("res://assets/sprites/flower.png")

const HILL_SIZE := 184.0

var hill_pos := Vector2.ZERO
var area := Vector2(900, 580)   # half-extent of decor around the hill

var _plants: Array = []   # {tex, pos, scale, flip}

func _ready() -> void:
	z_index = -20
	_build()
	queue_redraw()

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 70413
	# ferns
	for i in 34:
		var p := hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y))
		if p.distance_to(hill_pos) < 105.0:
			continue
		_plants.append({"tex": FERN, "pos": p, "scale": rng.randf_range(0.55, 1.05), "flip": rng.randf() < 0.5})
	# flowers
	for i in 12:
		var p := hill_pos + Vector2(rng.randf_range(-area.x, area.x), rng.randf_range(-area.y, area.y))
		if p.distance_to(hill_pos) < 120.0:
			continue
		_plants.append({"tex": FLOWER, "pos": p, "scale": rng.randf_range(0.6, 1.0), "flip": rng.randf() < 0.5})
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

	# plants (ferns/flowers), bottom-anchored so they look rooted
	for pl in _plants:
		var t: Texture2D = pl["tex"]
		var s: float = pl["scale"]
		var w := t.get_width() * s
		var h := t.get_height() * s
		var pos: Vector2 = pl["pos"]
		var r := Rect2(pos.x - w * 0.5, pos.y - h, w, h)
		draw_texture_rect(t, r, false, Color.WHITE, pl["flip"])

	# anthill mound
	draw_texture_rect(HILL, Rect2(hill_pos - Vector2(HILL_SIZE, HILL_SIZE) * 0.5, Vector2(HILL_SIZE, HILL_SIZE)), false)
