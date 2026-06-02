## Offline sprite baker — generates ORIGINAL, shaded PNG art for the game.
##
## Run headless:  godot --headless --script res://tools/bake_sprites.gd
##
## Everything here is computed from scratch (lit "spheres", soft shadows, value
## noise, highlights) so the look is hand-crafted in our own art direction — a
## warm, top-down jungle in the spirit of the genre, not anyone's ripped assets.
extends SceneTree

const DIR := "res://assets/sprites/"
const L := Vector3(-0.45, -0.62, 0.64)   # light dir (x right, y down, z toward viewer)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_bake_ground()
	_bake_hill()
	_bake_ant()
	_bake_carcass()
	_bake_fern()
	_bake_flower()
	_bake_mushroom()
	_bake_rock()
	_bake_bigleaf()
	_bake_vignette()
	_bake_beetle()
	_bake_ladybug()
	_bake_pillbug()
	_bake_fly()
	_bake_boss()
	print("baked sprites -> ", DIR)
	quit()

# --- image helpers ------------------------------------------------------------

func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)

func _save(img: Image, name: String) -> void:
	img.save_png(DIR + name)

func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height() or c.a <= 0.0:
		return
	var d := img.get_pixel(x, y)
	var a := c.a
	var na := a + d.a * (1.0 - a)
	if na <= 0.0:
		return
	img.set_pixel(x, y, Color(
		(c.r * a + d.r * d.a * (1.0 - a)) / na,
		(c.g * a + d.g * d.a * (1.0 - a)) / na,
		(c.b * a + d.b * d.a * (1.0 - a)) / na,
		na))

## A lit sphere ("ball") — the core of every soft, rounded body part.
func _ball(img: Image, cx: float, cy: float, r: float, base: Color, amb := 0.42, spec := 0.55, squash := 1.0) -> void:
	var ln := L.normalized()
	var x0 := int(floor(cx - r - 1)); var x1 := int(ceil(cx + r + 1))
	var y0 := int(floor(cy - r * squash - 1)); var y1 := int(ceil(cy + r * squash + 1))
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dx := (x + 0.5 - cx) / r
			var dy := (y + 0.5 - cy) / (r * squash)
			var d2 := dx * dx + dy * dy
			if d2 > 1.0:
				continue
			var nz := sqrt(1.0 - d2)
			var diff: float = maxf(0.0, Vector3(dx, dy, nz).dot(ln))
			var sh := amb + (1.0 - amb) * diff
			var s: float = pow(diff, 16.0) * spec
			var col := Color(minf(1.0, base.r * sh + s), minf(1.0, base.g * sh + s), minf(1.0, base.b * sh + s), 1.0)
			col.a = clampf((1.0 - sqrt(d2)) * r * 0.9, 0.0, 1.0)  # ~1px feathered rim
			_blend(img, x, y, col)

## Soft elliptical drop shadow.
func _shadow(img: Image, cx: float, cy: float, rx: float, ry: float, strength := 0.33) -> void:
	var x0 := int(floor(cx - rx - 1)); var x1 := int(ceil(cx + rx + 1))
	var y0 := int(floor(cy - ry - 1)); var y1 := int(ceil(cy + ry + 1))
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d := dx * dx + dy * dy
			if d > 1.0:
				continue
			_blend(img, x, y, Color(0, 0, 0, strength * (1.0 - d) * (1.0 - d)))

func _line(img: Image, a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var steps := int(maxf(2.0, a.distance_to(b)))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var r := width * 0.5
		for yy in range(int(floor(p.y - r)), int(ceil(p.y + r + 1))):
			for xx in range(int(floor(p.x - r)), int(ceil(p.x + r + 1))):
				var dd := Vector2(xx + 0.5, yy + 0.5).distance_to(p)
				if dd <= r:
					var c := col
					c.a = col.a * clampf((r - dd) * 1.3, 0.0, 1.0)
					_blend(img, xx, yy, c)

# --- entities -----------------------------------------------------------------

func _bake_ant() -> void:
	# points +X (head to the right) to match in-game rotation
	var img := _img(44, 36)
	var cx := 22.0; var cy := 18.0
	# warm reddish-brown so ants pop against dark dotted trails
	var dark := Color(0.46, 0.27, 0.13)
	_shadow(img, cx - 1, cy + 4, 14, 7, 0.30)
	for s in [-1.0, 1.0]:
		_line(img, Vector2(cx, cy), Vector2(cx - 10, cy + s * 9), Color(0.16, 0.10, 0.06), 1.8)
		_line(img, Vector2(cx, cy), Vector2(cx - 1, cy + s * 11), Color(0.16, 0.10, 0.06), 1.8)
		_line(img, Vector2(cx, cy), Vector2(cx + 7, cy + s * 9), Color(0.16, 0.10, 0.06), 1.8)
	_ball(img, cx - 9, cy, 8.0, dark, 0.5, 0.8)            # abdomen
	_ball(img, cx, cy, 5.5, dark.lightened(0.08), 0.5, 0.8)# thorax
	_ball(img, cx + 8, cy, 5.0, dark.lightened(0.12), 0.5, 0.8)  # head
	_line(img, Vector2(cx + 11, cy - 2), Vector2(cx + 17, cy - 6), Color(0.16, 0.10, 0.06), 1.4)
	_line(img, Vector2(cx + 11, cy + 2), Vector2(cx + 17, cy + 6), Color(0.16, 0.10, 0.06), 1.4)
	_save(img, "ant.png")

func _bake_carcass() -> void:
	var img := _img(34, 34)
	_shadow(img, 17, 20, 12, 7, 0.3)
	_ball(img, 17, 16, 12, Color(0.55, 0.50, 0.33), 0.5, 0.3)
	_ball(img, 14, 13, 6, Color(0.70, 0.64, 0.42), 0.55, 0.4)
	_save(img, "carcass.png")

func _bake_beetle() -> void:
	var img := _img(40, 32)
	var cx := 20.0; var cy := 16.0
	var c := Color(0.22, 0.07, 0.07)
	_shadow(img, cx - 1, cy + 4, 14, 8, 0.3)
	for s in [-1.0, 1.0]:
		_line(img, Vector2(cx - 2, cy), Vector2(cx - 9, cy + s * 10), c.darkened(0.2), 1.7)
		_line(img, Vector2(cx, cy), Vector2(cx - 2, cy + s * 11), c.darkened(0.2), 1.7)
		_line(img, Vector2(cx + 2, cy), Vector2(cx + 6, cy + s * 10), c.darkened(0.2), 1.7)
	_ball(img, cx - 3, cy, 11, c, 0.36, 0.6)
	_ball(img, cx + 8, cy, 6, c.lightened(0.05), 0.36, 0.6)
	_ball(img, cx - 3, cy, 4.5, Color(0.72, 0.13, 0.12), 0.5, 0.7)  # warning core
	_line(img, Vector2(cx + 12, cy - 3), Vector2(cx + 18, cy - 6), c, 1.6)
	_line(img, Vector2(cx + 12, cy + 3), Vector2(cx + 18, cy + 6), c, 1.6)
	_save(img, "bug_beetle.png")

func _bake_ladybug() -> void:
	var img := _img(38, 30)
	var cx := 19.0; var cy := 15.0
	var blk := Color(0.10, 0.08, 0.07)
	_shadow(img, cx - 1, cy + 4, 13, 7, 0.3)
	for s in [-1.0, 1.0]:
		_line(img, Vector2(cx - 2, cy), Vector2(cx - 8, cy + s * 9), blk, 1.6)
		_line(img, Vector2(cx, cy), Vector2(cx + 6, cy + s * 9), blk, 1.6)
	_ball(img, cx + 9, cy, 5, blk, 0.4, 0.5)            # head
	_ball(img, cx - 2, cy, 11, Color(0.82, 0.15, 0.13), 0.45, 0.75)  # shell
	_line(img, Vector2(cx - 12, cy), Vector2(cx + 5, cy), blk.darkened(0.0), 1.1)
	for sp in [Vector2(-6, -4), Vector2(-6, 4), Vector2(-1, -5), Vector2(-1, 5), Vector2(-9, 0)]:
		_ball(img, cx + sp.x, cy + sp.y, 2.2, blk, 0.6, 0.2)
	_save(img, "bug_ladybug.png")

func _bake_pillbug() -> void:
	var img := _img(40, 30)
	var cx := 20.0; var cy := 15.0
	var g := Color(0.44, 0.44, 0.49)
	_shadow(img, cx, cy + 4, 14, 7, 0.3)
	for s in [-1.0, 1.0]:
		_line(img, Vector2(cx - 4, cy), Vector2(cx - 10, cy + s * 9), g.darkened(0.35), 1.6)
		_line(img, Vector2(cx + 2, cy), Vector2(cx + 4, cy + s * 9), g.darkened(0.35), 1.6)
	_ball(img, cx, cy, 12, g, 0.4, 0.45)
	for i in range(-2, 3):
		var x: float = cx + i * 4.4
		_line(img, Vector2(x, cy - 9), Vector2(x, cy + 9), g.darkened(0.4), 1.3)
	_ball(img, cx + 9, cy, 5, g.darkened(0.12), 0.4, 0.4)  # head
	_save(img, "bug_pillbug.png")

func _bake_fly() -> void:
	var img := _img(34, 34)
	var cx := 17.0; var cy := 17.0
	var c := Color(0.16, 0.18, 0.23)
	# wings (translucent)
	_ball(img, cx - 3, cy - 8, 8, Color(0.78, 0.85, 0.98, 0.32), 0.8, 0.1, 0.6)
	_ball(img, cx - 3, cy + 8, 8, Color(0.78, 0.85, 0.98, 0.32), 0.8, 0.1, 0.6)
	_shadow(img, cx, cy + 3, 9, 5, 0.25)
	_ball(img, cx - 2, cy, 8, c, 0.4, 0.6)
	_ball(img, cx + 6, cy, 5, c.lightened(0.05), 0.4, 0.6)
	_ball(img, cx + 8, cy - 1.5, 1.8, Color(0.75, 0.2, 0.2), 0.6, 0.6)
	_ball(img, cx + 8, cy + 1.5, 1.8, Color(0.75, 0.2, 0.2), 0.6, 0.6)
	_save(img, "bug_fly.png")

func _bake_boss() -> void:
	var img := _img(72, 72)
	var cx := 36.0; var cy := 36.0
	var o := Color(0.84, 0.40, 0.12)
	var od := Color(0.5, 0.2, 0.06)
	_shadow(img, cx, cy + 6, 28, 16, 0.35)
	for s in [-1.0, 1.0]:
		_line(img, Vector2(cx - 6, cy), Vector2(cx - 20, cy + s * 18), od, 3.2)
		_line(img, Vector2(cx + 2, cy), Vector2(cx + 10, cy + s * 18), od, 3.2)
	for i in 11:
		var a := TAU * i / 11.0
		var d := Vector2(cos(a), sin(a))
		_line(img, Vector2(cx, cy) + d * 14, Vector2(cx, cy) + d * 22, od, 3.0)
	_ball(img, cx - 3, cy, 17, o, 0.38, 0.6)
	_ball(img, cx - 3, cy, 9, od, 0.45, 0.5)
	_ball(img, cx + 13, cy, 9, o.lightened(0.05), 0.38, 0.6)
	_line(img, Vector2(cx + 20, cy - 5), Vector2(cx + 30, cy - 11), od, 4.0)
	_line(img, Vector2(cx + 20, cy + 5), Vector2(cx + 30, cy + 11), od, 4.0)
	_save(img, "bug_boss.png")

func _bake_fern() -> void:
	var img := _img(96, 96)
	var cx := 48.0; var base := 88.0
	_shadow(img, cx, base - 2, 22, 8, 0.22)
	for i in 9:
		var t := float(i) / 8.0 - 0.5
		var ang := t * 1.5
		var tip := Vector2(cx + sin(ang) * 46, base - cos(ang * 0.4) * 80)
		var mid := Vector2(cx + sin(ang) * 22, base - 38)
		var green := Color(0.20, 0.42, 0.16).lerp(Color(0.36, 0.58, 0.22), (i % 3) / 2.0)
		_line(img, Vector2(cx, base), mid, green.darkened(0.15), 4.5)
		_line(img, mid, tip, green, 2.6)
	_save(img, "fern.png")

func _bake_flower() -> void:
	var img := _img(64, 64)
	var cx := 32.0; var cy := 32.0
	_shadow(img, cx, cy + 4, 20, 10, 0.2)
	# two leaves
	_ball(img, cx - 16, cy + 8, 9, Color(0.24, 0.46, 0.20), 0.45, 0.3, 0.5)
	_ball(img, cx + 16, cy + 6, 9, Color(0.22, 0.44, 0.18), 0.45, 0.3, 0.5)
	var petal := Color(0.93, 0.36, 0.62)
	for i in 6:
		var a := TAU * i / 6.0
		_ball(img, cx + cos(a) * 11, cy + sin(a) * 11, 7, petal, 0.5, 0.5)
	_ball(img, cx, cy, 8, petal.lightened(0.1), 0.5, 0.5)
	_ball(img, cx, cy, 5, Color(0.97, 0.84, 0.34), 0.55, 0.6)
	_save(img, "flower.png")

func _bake_mushroom() -> void:
	var img := _img(48, 58)
	var cx := 24.0
	_shadow(img, cx, 52, 15, 6, 0.28)
	# stem
	_ball(img, cx, 42, 7, Color(0.86, 0.82, 0.70), 0.5, 0.3, 1.5)
	# cap
	_ball(img, cx, 24, 18, Color(0.82, 0.22, 0.18), 0.45, 0.6, 0.62)
	for sp in [Vector2(-9, -2), Vector2(7, -3), Vector2(0, 4), Vector2(-3, -8), Vector2(11, 4)]:
		_ball(img, cx + sp.x, 24 + sp.y, 2.6, Color(0.96, 0.93, 0.86), 0.7, 0.2)
	_save(img, "mushroom.png")

func _bake_rock() -> void:
	var img := _img(54, 40)
	_shadow(img, 27, 28, 22, 9, 0.32)
	_ball(img, 27, 22, 20, Color(0.46, 0.45, 0.47), 0.4, 0.35, 0.62)
	_ball(img, 20, 16, 8, Color(0.54, 0.53, 0.55), 0.45, 0.4, 0.7)  # facet
	_save(img, "rock.png")

func _bake_bigleaf() -> void:
	var img := _img(132, 132)
	var cx := 66.0; var cy := 70.0
	_shadow(img, cx, cy + 8, 52, 26, 0.24)
	# big rounded leaf body (squashed lit ball), green
	_ball(img, cx, cy, 56, Color(0.21, 0.40, 0.16), 0.45, 0.35, 0.62)
	_ball(img, cx - 14, cy - 12, 26, Color(0.27, 0.47, 0.20), 0.5, 0.4, 0.62)  # sheen
	# midrib + side veins
	_line(img, Vector2(cx, cy + 34), Vector2(cx, cy - 34), Color(0.14, 0.28, 0.11), 2.4)
	for i in range(-3, 4):
		var y: float = cy + i * 9.0
		_line(img, Vector2(cx, y), Vector2(cx - 36, y - 12), Color(0.15, 0.30, 0.12), 1.4)
		_line(img, Vector2(cx, y), Vector2(cx + 36, y - 12), Color(0.15, 0.30, 0.12), 1.4)
	_save(img, "bigleaf.png")

func _bake_vignette() -> void:
	var sz := 256
	var img := _img(sz, sz)
	var c := sz * 0.5
	for y in range(sz):
		for x in range(sz):
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / (c * 1.414)
			var a := clampf((d - 0.52) / 0.48, 0.0, 1.0)
			a = a * a * 0.55
			img.set_pixel(x, y, Color(0.04, 0.03, 0.02, a))
	_save(img, "vignette.png")

func _bake_hill() -> void:
	var sz := 240
	var img := _img(sz, sz)
	var c := sz * 0.5
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.06
	n.seed = 7
	_shadow(img, c, c + 10, 104, 92, 0.34)
	# dirt dome
	var R := 100.0
	var ln := L.normalized()
	for y in range(sz):
		for x in range(sz):
			var dx := (x + 0.5 - c) / R
			var dy := (y + 0.5 - c) / R
			var d2 := dx * dx + dy * dy
			if d2 > 1.0:
				continue
			var nz := sqrt(1.0 - d2)
			var diff: float = maxf(0.0, Vector3(dx, dy, nz).dot(ln) * 0.7 + 0.3)
			var grain := 1.0 + n.get_noise_2d(x, y) * 0.16
			var base := Color(0.40, 0.27, 0.15)
			var sh := (0.5 + 0.6 * diff) * grain
			var col := Color(base.r * sh, base.g * sh, base.b * sh, clampf((1.0 - sqrt(d2)) * R, 0.0, 1.0))
			_blend(img, x, y, col)
	# entrance hole: dark recessed throat with a lit far wall
	for y in range(sz):
		for x in range(sz):
			var dx := (x + 0.5 - c) / 30.0
			var dy := (y + 0.5 - (c - 4)) / 30.0
			var d2 := dx * dx + dy * dy
			if d2 > 1.0:
				continue
			var dark := Color(0.05, 0.035, 0.025)
			var lit := Color(0.30, 0.21, 0.12)
			var t := clampf(dy * 0.5 + 0.5, 0.0, 1.0)  # lower wall catches light
			var col := dark.lerp(lit, (1.0 - d2) * t * 0.9)
			col.a = clampf((1.0 - sqrt(d2)) * 30.0, 0.0, 1.0)
			_blend(img, x, y, col)
	_save(img, "hill.png")

func _bake_ground() -> void:
	var sz := 384
	var img := _img(sz, sz)
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.012
	n.seed = 41
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n2.frequency = 0.08
	n2.seed = 7
	for y in range(sz):
		for x in range(sz):
			var v := (n.get_noise_2d(x, y) + 1.0) * 0.5
			var soil := Color(0.20, 0.16, 0.10)
			var moss := Color(0.18, 0.30, 0.13)
			var base := soil.lerp(moss, clampf(v * 1.3, 0.0, 1.0))
			var d := 1.0 + n2.get_noise_2d(x, y) * 0.18
			img.set_pixel(x, y, Color(base.r * d, base.g * d, base.b * d, 1.0))
	# leaf litter, wrapped so the tile repeats seamlessly
	var rng := RandomNumberGenerator.new()
	rng.seed = 2025
	var leafcols := [Color(0.20, 0.36, 0.15), Color(0.27, 0.45, 0.18), Color(0.15, 0.27, 0.12),
		Color(0.33, 0.40, 0.17), Color(0.31, 0.24, 0.13)]
	for i in 150:
		var px := rng.randf() * sz
		var py := rng.randf() * sz
		var ln_ := rng.randf_range(10.0, 22.0)
		var rot := rng.randf() * TAU
		var col: Color = leafcols[rng.randi() % leafcols.size()]
		for ox in [-sz, 0, sz]:
			for oy in [-sz, 0, sz]:
				_leaf(img, px + ox, py + oy, ln_, rot, col)
	_save(img, "ground.png")

func _leaf(img: Image, cx: float, cy: float, length: float, rot: float, col: Color) -> void:
	if cx < -length or cy < -length or cx > img.get_width() + length or cy > img.get_height() + length:
		return
	var dir := Vector2(cos(rot), sin(rot))
	var perp := Vector2(-dir.y, dir.x)
	var w := length * 0.42
	var ln := L.normalized()
	var x0 := int(floor(cx - length)); var x1 := int(ceil(cx + length))
	var y0 := int(floor(cy - length)); var y1 := int(ceil(cy + length))
	for y in range(y0, y1):
		for x in range(x0, x1):
			var rel := Vector2(x + 0.5 - cx, y + 0.5 - cy)
			var u := rel.dot(dir) / (length * 0.5)      # -1..1 along
			var vv := rel.dot(perp) / (w * 0.5)          # -1..1 across
			if u * u + vv * vv > 1.0:
				continue
			var bump := sqrt(maxf(0.0, 1.0 - vv * vv))   # rounded across the blade
			var diff: float = clampf(0.55 + 0.5 * (perp.dot(Vector2(ln.x, ln.y))) * vv, 0.2, 1.1)
			var sh := 0.7 * diff + 0.45 * bump
			var c := Color(col.r * sh, col.g * sh, col.b * sh, clampf((1.0 - sqrt(u * u + vv * vv)) * length, 0.0, 1.0))
			_blend(img, x, y, c)
	_line(img, Vector2(cx - dir.x * length * 0.5, cy - dir.y * length * 0.5),
		Vector2(cx + dir.x * length * 0.5, cy + dir.y * length * 0.5), col.darkened(0.3), 1.0)
