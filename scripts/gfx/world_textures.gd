class_name WorldTextures
extends RefCounted
## WorldTextures — procedural 32x32 pixel-art material tiles in one Texture2DArray.
##
## Purpose: every surface of the low-poly world gets a real material (asphalt, brick, rusty
##   metal, planks...) without external assets. Tiles are *detail maps*: mid-grey (0.5) means
##   "keep the vertex colour", so one tile works for a red brick wall and a yellow one.
##   Layer index = material id, stored per vertex in UV2.y (MeshBuilder) and projected in
##   world space by lowpoly_snow.gdshader at TEXELS_PER_METRE.
## Public API: id(name), texture(), NAMES, TEXELS_PER_METRE

const SIZE := 32
const TEXELS_PER_METRE := 16.0
const NAMES: Array[String] = [
	"plain", "asphalt", "sidewalk", "snow", "slush", "concrete", "brick", "plaster",
	"metal", "rust", "planks", "glass", "dirt", "ice", "roof", "door",
	"container", "paint", "floor_tiles", "wallpaper", "fabric", "parquet", "cardboard", "plastic",
	"wall_tiles", "cobble",
]

static var _texture: Texture2DArray


static func id(material_name: String) -> int:
	var i := NAMES.find(material_name)
	return maxi(i, 0)


static func texture() -> Texture2DArray:
	if _texture == null:
		var images: Array[Image] = []
		for n in NAMES:
			var img := _generate(n)
			img.generate_mipmaps()
			images.append(img)
		_texture = Texture2DArray.new()
		_texture.create_from_images(images)
	return _texture


static func clear() -> void:
	_texture = null


# --- Generation helpers ---------------------------------------------------------------------------

## Tileable value noise (period SIZE) with cells of `cell` pixels.
static func _vnoise(x: float, y: float, cell: int, seed: int) -> float:
	var n := SIZE / cell
	var fx := x / cell
	var fy := y / cell
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _h(posmod(ix, n), posmod(iy, n), seed)
	var b := _h(posmod(ix + 1, n), posmod(iy, n), seed)
	var c := _h(posmod(ix, n), posmod(iy + 1, n), seed)
	var d := _h(posmod(ix + 1, n), posmod(iy + 1, n), seed)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func _h(x: int, y: int, seed: int) -> float:
	var v := (x * 374761393 + y * 668265263 + seed * 2147483647) & 0x7fffffff
	v = (v ^ (v >> 13)) * 1274126177
	v = v & 0x7fffffff
	return float(v % 10007) / 10007.0


static func _fbm(x: float, y: float, seed: int) -> float:
	return _vnoise(x, y, 16, seed) * 0.5 + _vnoise(x, y, 8, seed + 1) * 0.3 + _vnoise(x, y, 4, seed + 2) * 0.2


static func _grey(v: float) -> Color:
	v = clampf(v, 0.0, 1.0)
	return Color(v, v, v)


static func _tint(v: float, r: float, g: float, b: float) -> Color:
	return Color(clampf(v * r, 0.0, 1.0), clampf(v * g, 0.0, 1.0), clampf(v * b, 0.0, 1.0))


static func _generate(kind: String) -> Image:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var seed := int(hash(kind) & 0xffff)
	for y in SIZE:
		for x in SIZE:
			img.set_pixel(x, y, _pixel(kind, x, y, seed, rng))
	_post(kind, img, rng)
	return img


static func _pixel(kind: String, x: int, y: int, seed: int, rng: RandomNumberGenerator) -> Color:
	var n := _fbm(x, y, seed)
	var fine := _h(x, y, seed + 7)
	match kind:
		"plain":
			return _grey(0.5)
		"asphalt":
			var v := 0.47 + (n - 0.5) * 0.12 + (fine - 0.5) * 0.08
			if fine > 0.94:
				v += 0.1
			elif fine < 0.05:
				v -= 0.08
			return _grey(v)
		"sidewalk":
			# 1 m slabs (16 px) with grout, each slab slightly different.
			var gx := x % 16
			var gy := y % 16
			if gx == 0 or gy == 0:
				return _grey(0.36)
			var slab := _h(x / 16, y / 16, seed) - 0.5
			return _grey(0.52 + slab * 0.08 + (n - 0.5) * 0.06 + (fine - 0.5) * 0.04)
		"snow":
			var v := 0.5 + (n - 0.5) * 0.07
			if fine > 0.965:
				v = 0.6
			return _tint(v, 0.98, 1.0, 1.02)
		"slush":
			var dirt := smoothstep(0.45, 0.7, n)
			var v := 0.5 - dirt * 0.14 + (fine - 0.5) * 0.05
			return _tint(v, 1.0 + dirt * 0.04, 1.0, 1.0 - dirt * 0.08)
		"concrete":
			var v := 0.5 + (n - 0.5) * 0.1 + (fine - 0.5) * 0.05
			if fine < 0.04:
				v -= 0.1
			if y == 31:
				v -= 0.08
			return _grey(v)
		"brick":
			# 8x4 px bricks (0.5 x 0.25 m), staggered, 1 px mortar.
			var row := y / 4
			var bx := (x + (4 if row % 2 == 1 else 0)) % 8
			if y % 4 == 3 or bx == 7:
				return _grey(0.64 + (fine - 0.5) * 0.06)
			var brick := _h((x + (4 if row % 2 == 1 else 0)) / 8, row, seed) - 0.5
			var v := 0.5 + brick * 0.14 + (fine - 0.5) * 0.06 + (n - 0.5) * 0.05
			return _tint(v, 1.0 + brick * 0.12, 1.0, 1.0 - brick * 0.1)
		"plaster":
			var blotch := smoothstep(0.62, 0.7, _vnoise(x, y, 8, seed + 3))
			var v := 0.52 + (n - 0.5) * 0.05 + (fine - 0.5) * 0.03 - blotch * 0.12
			return _grey(v)
		"metal":
			# Corrugated sheet: vertical ribs every 4 px.
			var rib: float = [0.44, 0.52, 0.58, 0.5][x % 4]
			return _grey(rib + (n - 0.5) * 0.06 + (fine - 0.5) * 0.03)
		"rust":
			var r := smoothstep(0.4, 0.7, n)
			var v := 0.48 + (fine - 0.5) * 0.08
			return _tint(v, 1.0 + r * 0.35, 1.0 - r * 0.05, 1.0 - r * 0.35)
		"planks":
			# Horizontal boards 6 px high with dark gaps, grain and knots.
			var board := y / 6
			if y % 6 == 5:
				return _grey(0.3)
			var shift := int(_h(board, 0, seed) * 32.0)
			var grain := sin((x + shift) * 0.9 + _vnoise(x + shift, y, 4, seed) * 6.0) * 0.04
			var b := _h(board, 3, seed) - 0.5
			var v := 0.5 + b * 0.1 + grain + (fine - 0.5) * 0.04
			if (x + shift) % 16 == 0:
				v -= 0.12
			return _tint(v, 1.02, 1.0, 0.97)
		"glass":
			var streak := 1.0 if (x + y) % 32 in [3, 4, 5, 12] else 0.0
			return _tint(0.42 + float(31 - y) / 31.0 * 0.12 + streak * 0.14, 0.95, 1.0, 1.08)
		"dirt":
			var v := 0.48 + (n - 0.5) * 0.16 + (fine - 0.5) * 0.08
			if fine > 0.95:
				v += 0.14
			return _tint(v, 1.05, 1.0, 0.92)
		"ice":
			var v := 0.54 + (n - 0.5) * 0.06
			return _tint(v, 0.96, 1.0, 1.06)
		"roof":
			# Tar paper strips 8 px with a lighter overlap line.
			var v := 0.46 + (n - 0.5) * 0.08 + (fine - 0.5) * 0.06
			if y % 8 == 0:
				v += 0.1
			elif y % 8 == 1:
				v -= 0.06
			return _grey(v)
		"door":
			# Vertical boards 4 px wide.
			var col := x / 4
			if x % 4 == 3:
				return _grey(0.34)
			var b := _h(col, 5, seed) - 0.5
			return _tint(0.5 + b * 0.08 + sin(y * 0.7 + col) * 0.03 + (fine - 0.5) * 0.04, 1.02, 1.0, 0.96)
		"container":
			# Horizontal ribs every 4 px (shipping container / garage door).
			var rib: float = [0.43, 0.5, 0.57, 0.52][y % 4]
			var rust := smoothstep(0.66, 0.8, n)
			return _tint(rib + (fine - 0.5) * 0.03, 1.0 + rust * 0.25, 1.0, 1.0 - rust * 0.25)
		"paint":
			return _grey(0.5 + (n - 0.5) * 0.04 + (fine - 0.5) * 0.02)
		"floor_tiles":
			if x % 8 == 0 or y % 8 == 0:
				return _grey(0.38)
			var t := _h(x / 8, y / 8, seed) - 0.5
			return _grey(0.52 + t * 0.06 + (fine - 0.5) * 0.03)
		"wall_tiles":
			if x % 8 == 0 or y % 8 == 0:
				return _grey(0.4)
			return _grey(0.55 + (fine - 0.5) * 0.02 + float(7 - y % 8) * 0.004)
		"wallpaper":
			# Faded vertical stripes with small diamonds.
			var stripe := 0.04 if x % 8 < 4 else -0.02
			var diamond := 0.05 if (absi(x % 8 - 4) + absi(y % 8 - 4)) == 2 else 0.0
			return _grey(0.5 + stripe + diamond + (n - 0.5) * 0.06)
		"fabric":
			return _grey(0.5 + (fine - 0.5) * 0.1 + ((x + y) % 2) * 0.02)
		"parquet":
			# 2 x 8 px boards in alternating direction per 8x8 cell.
			var cell := (x / 8 + y / 8) % 2
			var along := y if cell == 0 else x
			var across := x if cell == 0 else y
			if across % 2 == 1 and along % 8 == 7:
				return _grey(0.36)
			var b := _h(x / (2 if cell == 0 else 8), y / (8 if cell == 0 else 2), seed) - 0.5
			return _tint(0.5 + b * 0.1 + (fine - 0.5) * 0.03, 1.03, 1.0, 0.95)
		"cardboard":
			var v := 0.5 + (-0.03 if x % 3 == 0 else 0.0) + (fine - 0.5) * 0.04
			if y >= 13 and y <= 16:
				v = 0.6
			return _tint(v, 1.04, 1.0, 0.92)
		"plastic":
			return _grey(0.5 + (fine - 0.5) * 0.02)
		"cobble":
			var cx := (x + (4 if (y / 8) % 2 == 1 else 0)) % 8
			if cx == 0 or y % 8 == 0:
				return _grey(0.34)
			var stone := _h((x + (4 if (y / 8) % 2 == 1 else 0)) / 8, y / 8, seed) - 0.5
			return _grey(0.5 + stone * 0.12 + (fine - 0.5) * 0.05)
	return _grey(0.5)


## Extra features that are easier as strokes than per-pixel rules.
static func _post(kind: String, img: Image, rng: RandomNumberGenerator) -> void:
	match kind:
		"asphalt":
			_crack(img, rng, 0.36, 2)
		"concrete":
			_crack(img, rng, 0.4, 1)
		"plaster":
			_crack(img, rng, 0.42, 1)
		"ice":
			_crack(img, rng, 0.66, 3)
		"metal":
			for i in 3:
				var p := Vector2i(rng.randi_range(0, 31), rng.randi_range(0, 31))
				img.set_pixel(p.x, p.y, _grey(0.66))
		"slush":
			# Tyre ruts: two darker parallel bands.
			for y in SIZE:
				for x in [9, 10, 22, 23]:
					var c := img.get_pixel(x, y)
					img.set_pixel(x, y, c.darkened(0.12))


static func _crack(img: Image, rng: RandomNumberGenerator, shade: float, count: int) -> void:
	for c in count:
		var p := Vector2(rng.randf_range(0, SIZE), rng.randf_range(0, SIZE))
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for step in rng.randi_range(10, 22):
			dir = dir.rotated(rng.randf_range(-0.7, 0.7))
			p += dir
			var ix := posmod(int(p.x), SIZE)
			var iy := posmod(int(p.y), SIZE)
			img.set_pixel(ix, iy, _grey(shade))
