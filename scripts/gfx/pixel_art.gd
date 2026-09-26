class_name PixelArt
extends RefCounted
## PixelArt — procedural placeholder pixel art (characters, the Snow Stalker, item icons).
##
## Purpose: every character differs by palette, silhouette and accessory without any
##   external asset. Real art replaces it by filling CharacterData.sprite_sheet / ItemData.icon
##   with a sheet of the same layout.
## Character sheet layout (FRAME_W x FRAME_H per frame, 4 columns x 5 rows):
##   rows: 0 down (facing camera), 1 up, 2 right, 3 left, 4 special
##   cols: 0 idle, 1 walk A, 2 walk B, 3 aim;  special row: 0 sitting/injured, 1 lying, 2 crouch
## Public API: character_sheet(data), stalker_sheet(), item_icon(item) (-> IconArt), clear_cache()

const FRAME_W := 24
const FRAME_H := 28
const COLS := 4
const ROWS := 5
const STALKER_W := 32
const STALKER_H := 44

enum { T, OUTLINE, SKIN, HAIR, COAT, SHADE, PANTS, BOOTS, ACCENT, EYE, HIGHLIGHT, BLOOD, METAL }

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()
	IconArt.clear_cache()


# --- Characters ----------------------------------------------------------------------------

static func character_sheet(data: CharacterData) -> Texture2D:
	if data == null:
		return null
	if data.sprite_sheet:
		return data.sprite_sheet
	var key := "char:%s:%s:%s:%s" % [data.id, data.silhouette, data.accessory, data.coat_color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var palette := _palette_for(data)
	var img := Image.create_empty(FRAME_W * COLS, FRAME_H * ROWS, false, Image.FORMAT_RGBA8)
	var body := _proportions(data.silhouette)
	for dir in 4:
		for col in COLS:
			var grid := _new_grid(FRAME_W, FRAME_H)
			_draw_person(grid, dir, col, body, data.accessory)
			_outline(grid, FRAME_W, FRAME_H)
			_blit(img, grid, FRAME_W, FRAME_H, col * FRAME_W, dir * FRAME_H, palette)
	# Special row.
	var sit := _new_grid(FRAME_W, FRAME_H)
	_draw_person(sit, 0, 0, body, data.accessory, "sit")
	_outline(sit, FRAME_W, FRAME_H)
	_blit(img, sit, FRAME_W, FRAME_H, 0, 4 * FRAME_H, palette)
	var lie := _lying(body, data.accessory)
	_outline(lie, FRAME_W, FRAME_H)
	_blit(img, lie, FRAME_W, FRAME_H, FRAME_W, 4 * FRAME_H, palette)
	var crouch := _new_grid(FRAME_W, FRAME_H)
	_draw_person(crouch, 0, 0, body, data.accessory, "crouch")
	_outline(crouch, FRAME_W, FRAME_H)
	_blit(img, crouch, FRAME_W, FRAME_H, 2 * FRAME_W, 4 * FRAME_H, palette)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _palette_for(d: CharacterData) -> Dictionary:
	return {
		OUTLINE: Color(0.06, 0.07, 0.09),
		SKIN: d.skin_color,
		HAIR: d.hair_color,
		COAT: d.coat_color,
		SHADE: d.coat_color.darkened(0.3),
		PANTS: d.pants_color,
		BOOTS: Color(0.13, 0.12, 0.12),
		ACCENT: d.accent_color,
		EYE: Color(0.08, 0.08, 0.1),
		HIGHLIGHT: Color(0.9, 0.94, 1.0),
		BLOOD: Color(0.55, 0.05, 0.06),
		METAL: Color(0.2, 0.21, 0.24),
	}


static func _proportions(silhouette: String) -> Dictionary:
	var b := {"torso_w": 8, "torso_h": 8, "leg_h": 6, "arm_w": 1}
	match silhouette:
		"tall":
			b.torso_h = 9
			b.leg_h = 8
		"broad":
			b.torso_w = 10
			b.arm_w = 2
		"short":
			b.torso_h = 7
			b.leg_h = 4
		"slim":
			b.torso_w = 6
			b.leg_h = 7
	return b


static func _new_grid(w: int, h: int) -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(w * h)
	g.fill(T)
	return g


static func _rect(g: PackedByteArray, w: int, h: int, x: int, y: int, rw: int, rh: int, c: int) -> void:
	for yy in range(maxi(0, y), mini(h, y + rh)):
		for xx in range(maxi(0, x), mini(w, x + rw)):
			g[yy * w + xx] = c


static func _px(g: PackedByteArray, w: int, h: int, x: int, y: int, c: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		g[y * w + x] = c


## dir: 0 down, 1 up, 2 right, 3 left. col: 0 idle, 1 walkA, 2 walkB, 3 aim.
static func _draw_person(g: PackedByteArray, dir: int, col: int, b: Dictionary, accessory: String, pose: String = "") -> void:
	var w := FRAME_W
	var h := FRAME_H
	var mirror := dir == 3
	if mirror:
		dir = 2
	var tw: int = b.torso_w
	var th: int = b.torso_h
	var lh: int = b.leg_h
	if pose == "sit":
		lh = 1
	elif pose == "crouch":
		lh = 2
		th -= 1
	var cx := 12
	var feet := h - 1
	var legs_top := feet - lh
	var torso_top := legs_top - th
	var head_top := torso_top - 6
	var side := dir == 2
	var sw := tw if not side else maxi(4, tw - 3)
	var tx := cx - sw / 2
	var step := 0
	if col == 1:
		step = 1
	elif col == 2:
		step = -1
	# Legs + boots
	if pose == "sit":
		_rect(g, w, h, cx - 5, feet - 1, 4, 2, PANTS)
		_rect(g, w, h, cx + 1, feet - 1, 4, 2, PANTS)
		_rect(g, w, h, cx - 6, feet, 2, 1, BOOTS)
		_rect(g, w, h, cx + 4, feet, 2, 1, BOOTS)
	elif side:
		var front_x := cx - 1 + step * 2
		var back_x := cx - 1 - step * 2
		_rect(g, w, h, back_x, legs_top, 2, lh, PANTS)
		_rect(g, w, h, back_x, feet, 3, 1, BOOTS)
		_rect(g, w, h, front_x, legs_top, 2, lh, PANTS)
		_rect(g, w, h, front_x, feet, 3, 1, BOOTS)
	else:
		var lx := cx - sw / 2 + 1
		var rx := cx + 1
		var left_lift := 1 if step == 1 else 0
		var right_lift := 1 if step == -1 else 0
		_rect(g, w, h, lx, legs_top, 2, lh - left_lift, PANTS)
		_rect(g, w, h, lx, feet - left_lift, 2, 1, BOOTS)
		_rect(g, w, h, rx, legs_top, 2, lh - right_lift, PANTS)
		_rect(g, w, h, rx, feet - right_lift, 2, 1, BOOTS)
	# Torso (coat hangs one row over the legs)
	_rect(g, w, h, tx, torso_top, sw, th + 1, COAT)
	_rect(g, w, h, tx + sw - 1, torso_top + 1, 1, th, SHADE)
	_rect(g, w, h, tx, torso_top + th, sw, 1, SHADE)
	if dir == 0:
		_rect(g, w, h, cx - 1, torso_top + 2, 1, th - 2, SHADE)
	# Snow on the shoulders
	_px(g, w, h, tx, torso_top, HIGHLIGHT)
	_px(g, w, h, tx + sw - 1, torso_top, HIGHLIGHT)
	# Arms
	var aw: int = b.arm_w
	var arm_len := th - 1
	if side:
		var ax := cx - 1 + step
		if col == 3:
			_rect(g, w, h, cx, torso_top + 2, 6, 2, COAT)
			_rect(g, w, h, cx + 6, torso_top + 2, 1, 2, SKIN)
			_rect(g, w, h, cx + 7, torso_top + 1, 2, 2, METAL)
		else:
			_rect(g, w, h, ax, torso_top + 1, 2, arm_len, SHADE)
			_rect(g, w, h, ax, torso_top + arm_len + 1, 2, 1, SKIN)
	elif pose != "sit":
		var la := 1 if step == 1 else 0
		var ra := 1 if step == -1 else 0
		if col == 3 and dir == 0:
			_rect(g, w, h, tx - aw, torso_top + 1, aw, 3, COAT)
			_rect(g, w, h, tx + sw, torso_top + 1, aw, 3, COAT)
			_rect(g, w, h, cx - 2, torso_top + 3, 4, 2, SKIN)
			_rect(g, w, h, cx - 1, torso_top + 2, 2, 2, METAL)
		else:
			_rect(g, w, h, tx - aw, torso_top + 1 + la, aw, arm_len - 1, COAT)
			_rect(g, w, h, tx - aw, torso_top + arm_len + la, aw, 1, SKIN)
			_rect(g, w, h, tx + sw, torso_top + 1 + ra, aw, arm_len - 1, SHADE)
			_rect(g, w, h, tx + sw, torso_top + arm_len + ra, aw, 1, SKIN)
	else:
		# Sitting: one hand pressed to a wound.
		_rect(g, w, h, tx - aw, torso_top + 1, aw, arm_len - 1, COAT)
		_rect(g, w, h, cx - 1, torso_top + 4, 3, 2, SKIN)
		_rect(g, w, h, cx + 1, torso_top + 5, 2, 2, BLOOD)
		_rect(g, w, h, tx + sw, torso_top + 1, aw, arm_len - 1, SHADE)
	# Head
	var hx := cx - 3
	var hw := 6
	if side:
		hx = cx - 2
		hw = 5
	_rect(g, w, h, hx, head_top, hw, 6, SKIN)
	if dir == 1:
		_rect(g, w, h, hx, head_top, hw, 5, HAIR)
	elif side:
		_rect(g, w, h, hx, head_top, hw, 2, HAIR)
		_rect(g, w, h, hx, head_top, 2, 4, HAIR)
		_px(g, w, h, hx + hw - 2, head_top + 3, EYE)
	else:
		_rect(g, w, h, hx, head_top, hw, 2, HAIR)
		_px(g, w, h, hx, head_top + 2, HAIR)
		_px(g, w, h, hx + hw - 1, head_top + 2, HAIR)
		_px(g, w, h, cx - 2, head_top + 3, EYE)
		_px(g, w, h, cx + 1, head_top + 3, EYE)
	_draw_accessory(g, accessory, dir, side, cx, hx, hw, head_top, torso_top, tx, sw, th, aw)
	if mirror:
		_mirror(g, w, h)


static func _draw_accessory(g: PackedByteArray, accessory: String, dir: int, side: bool, cx: int, hx: int, hw: int, head_top: int, torso_top: int, tx: int, sw: int, th: int, aw: int) -> void:
	var w := FRAME_W
	var h := FRAME_H
	match accessory:
		"glasses":
			if dir == 0:
				_rect(g, w, h, cx - 3, head_top + 3, 6, 1, ACCENT)
				_px(g, w, h, cx - 2, head_top + 3, EYE)
				_px(g, w, h, cx + 1, head_top + 3, EYE)
			elif side:
				_rect(g, w, h, hx + hw - 3, head_top + 3, 3, 1, ACCENT)
		"scarf":
			_rect(g, w, h, tx, torso_top, sw, 2, ACCENT)
			if dir == 0:
				_rect(g, w, h, cx + 1, torso_top + 2, 1, 3, ACCENT)
			elif dir == 1:
				_rect(g, w, h, cx - 2, torso_top + 2, 2, 2, ACCENT)
			else:
				_rect(g, w, h, tx - 1, torso_top + 1, 2, 3, ACCENT)
		"cap":
			_rect(g, w, h, hx, head_top - 1, hw, 3, ACCENT)
			if side:
				_rect(g, w, h, hx + hw, head_top + 1, 2, 1, ACCENT)
			elif dir == 0:
				_rect(g, w, h, hx - 1, head_top + 1, hw + 2, 1, ACCENT)
		"hood":
			_rect(g, w, h, hx - 1, head_top - 1, hw + 2, 2, COAT)
			if dir == 1:
				_rect(g, w, h, hx - 1, head_top, hw + 2, 6, COAT)
			elif side:
				_rect(g, w, h, hx - 1, head_top, 3, 6, COAT)
			else:
				_rect(g, w, h, hx - 1, head_top, 1, 6, COAT)
				_rect(g, w, h, hx + hw, head_top, 1, 6, COAT)
		"helmet":
			_rect(g, w, h, hx - 1, head_top - 1, hw + 2, 3, ACCENT)
			_rect(g, w, h, hx, head_top - 1, hw, 1, HIGHLIGHT)
		"bag":
			if dir == 0:
				for i in th:
					_px(g, w, h, tx + i * sw / th, torso_top + i, ACCENT)
				_rect(g, w, h, tx + sw, torso_top + th - 3, 2, 3, ACCENT)
			elif dir == 1:
				_rect(g, w, h, tx + 1, torso_top + 1, sw - 2, th - 3, ACCENT)
			else:
				_rect(g, w, h, tx - 2, torso_top + 2, 3, th - 3, ACCENT)
		"armband":
			if not side:
				_rect(g, w, h, tx - aw, torso_top + 3, aw, 2, ACCENT)
			else:
				_rect(g, w, h, cx - 1, torso_top + 3, 2, 1, ACCENT)


static func _lying(b: Dictionary, accessory: String) -> PackedByteArray:
	var tmp := _new_grid(FRAME_W, FRAME_H)
	_draw_person(tmp, 0, 0, b, accessory)
	var out := _new_grid(FRAME_W, FRAME_H)
	# Rotate 90° clockwise and place on the ground line.
	for y in FRAME_H:
		for x in FRAME_W:
			var c := tmp[y * FRAME_W + x]
			if c == T:
				continue
			var nx := FRAME_H - y
			var ny := x + 9
			_px(out, FRAME_W, FRAME_H, nx, ny, c)
	return out


static func _mirror(g: PackedByteArray, w: int, h: int) -> void:
	for y in h:
		for x in w / 2:
			var a := y * w + x
			var bb := y * w + (w - 1 - x)
			var t := g[a]
			g[a] = g[bb]
			g[bb] = t


static func _outline(g: PackedByteArray, w: int, h: int) -> void:
	var src := g.duplicate()
	for y in h:
		for x in w:
			if src[y * w + x] != T:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					var n := src[ny * w + nx]
					if n != T and n != OUTLINE:
						g[y * w + x] = OUTLINE
						break


static func _blit(img: Image, g: PackedByteArray, w: int, h: int, ox: int, oy: int, palette: Dictionary) -> void:
	for y in h:
		for x in w:
			var c := g[y * w + x]
			if c != T:
				img.set_pixel(ox + x, oy + y, palette.get(c, Color.MAGENTA))


# --- Snow Stalker ------------------------------------------------------------------------------

## 4 cols (idle, walkA, walkB, attack) x 4 rows (down, up, right, left).
static func stalker_sheet() -> Texture2D:
	if _cache.has("stalker"):
		return _cache["stalker"]
	var palette := {
		OUTLINE: Color(0.02, 0.02, 0.04),
		COAT: Color(0.1, 0.12, 0.17),
		SHADE: Color(0.06, 0.07, 0.1),
		SKIN: Color(0.36, 0.42, 0.5),
		HIGHLIGHT: Color(0.7, 0.8, 0.9),
		EYE: Color(0.85, 0.97, 1.0),
		PANTS: Color(0.08, 0.09, 0.13),
	}
	var img := Image.create_empty(STALKER_W * 4, STALKER_H * 4, false, Image.FORMAT_RGBA8)
	for dir in 4:
		for col in 4:
			var g := _new_grid(STALKER_W, STALKER_H)
			_draw_stalker(g, dir, col)
			_outline(g, STALKER_W, STALKER_H)
			_blit(img, g, STALKER_W, STALKER_H, col * STALKER_W, dir * STALKER_H, palette)
	var tex := ImageTexture.create_from_image(img)
	_cache["stalker"] = tex
	return tex


static func _draw_stalker(g: PackedByteArray, dir: int, col: int) -> void:
	var w := STALKER_W
	var h := STALKER_H
	var mirror := dir == 3
	if mirror:
		dir = 2
	var side := dir == 2
	var cx := 16
	var feet := h - 1
	var step := 1 if col == 1 else (-1 if col == 2 else 0)
	var leg_h := 17
	var legs_top := feet - leg_h
	var torso_h := 13
	var torso_top := legs_top - torso_h
	var sway := 1 if col == 1 else 0
	# Legs: long and thin, knees bent backwards when walking.
	if side:
		_rect(g, w, h, cx - 1 + step * 2, legs_top, 2, leg_h, PANTS)
		_rect(g, w, h, cx - 1 - step * 2, legs_top, 2, leg_h, SHADE)
	else:
		_rect(g, w, h, cx - 3, legs_top + maxi(0, step), 2, leg_h - maxi(0, step), PANTS)
		_rect(g, w, h, cx + 1, legs_top + maxi(0, -step), 2, leg_h - maxi(0, -step), PANTS)
	# Torso, narrow and hunched.
	var tw := 4 if side else 6
	var hunch := 3 if side else 0
	for i in torso_h:
		var off := int(float(hunch) * (1.0 - float(i) / torso_h))
		_rect(g, w, h, cx - tw / 2 + off, torso_top + i, tw, 1, COAT if i % 5 != 0 else SHADE)
	_rect(g, w, h, cx - tw / 2 + hunch, torso_top, tw, 1, HIGHLIGHT)
	# Arms reach below the knees.
	if col == 3:
		_rect(g, w, h, cx - tw / 2 - 5, torso_top - 6, 2, 12, COAT)
		_rect(g, w, h, cx + tw / 2 + 3, torso_top - 6, 2, 12, COAT)
		_rect(g, w, h, cx - tw / 2 - 6, torso_top - 8, 3, 3, SKIN)
		_rect(g, w, h, cx + tw / 2 + 3, torso_top - 8, 3, 3, SKIN)
	elif side:
		_rect(g, w, h, cx + 1 + hunch + step, torso_top + 1, 1, 20, SHADE)
		_rect(g, w, h, cx + 1 + hunch + step, torso_top + 21, 2, 2, SKIN)
	else:
		_rect(g, w, h, cx - tw / 2 - 2, torso_top + 1 + sway, 1, 21, COAT)
		_rect(g, w, h, cx + tw / 2 + 1, torso_top + 1 - sway + 1, 1, 21, COAT)
		_rect(g, w, h, cx - tw / 2 - 3, torso_top + 21 + sway, 2, 3, SKIN)
		_rect(g, w, h, cx + tw / 2 + 1, torso_top + 22 - sway, 2, 3, SKIN)
	# Head: small, elongated, pushed forward.
	var hx := cx - 2 + (hunch + 2 if side else 0)
	var head_top := torso_top - 7 + (2 if side else 0)
	_rect(g, w, h, hx, head_top, 4, 7, SKIN)
	_rect(g, w, h, hx, head_top, 4, 1, HIGHLIGHT)
	if dir == 0:
		_px(g, w, h, hx, head_top + 3, EYE)
		_px(g, w, h, hx + 3, head_top + 3, EYE)
	elif side:
		_px(g, w, h, hx + 3, head_top + 3, EYE)
	if mirror:
		_mirror(g, w, h)


# --- Item icons ---------------------------------------------------------------------------------

static func item_icon(item: ItemData) -> Texture2D:
	return IconArt.item_icon(item)
