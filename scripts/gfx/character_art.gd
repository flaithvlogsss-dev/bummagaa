class_name CharacterArt
extends RefCounted
## CharacterArt — procedural 32x32 pixel-art character sheets built from an appearance.
##
## Purpose: people differ by silhouette, hair, clothes and colour, and visibly wear what they
##   carry: hats, gas masks (twin-eye, panoramic, half mask), backpacks of different sizes.
##   The player's sheet is rebuilt when equipment changes; NPCs pull masks on outdoors.
## Sheet: FRAME x FRAME frames, COLS x ROWS:
##   rows 0 down (towards camera), 1 up, 2 right, 3 left (mirrored), 4 special
##   cols 0 idle, 1 idle (breath), 2-5 walk, 6 aim, 7 melee swing
##   special row: 0 sit (hurt), 1 lie, 2 crouch, 3 cough
## Appearance keys: silhouette, skin, hair, hair_style, coat, coat_style, pants, accent,
##   hat, mask, backpack, accessory, boots.
## Public API: sheet(appearance), appearance_for(data, masked), player_appearance()

const FRAME := 32
const COLS := 8
const ROWS := 5
const WALK: Array[int] = [2, 3, 4, 5]

enum { T, OUT, SKIN, SKIN_SH, HAIR, HAIR_SH, COAT, COAT_SH, COAT_HI, PANTS, PANTS_SH, BOOT,
	ACC, ACC_SH, EYE, SNOW, METAL, METAL_HI, RUB, RUB_SH, GLASS, BAG, BAG_SH, BLOOD, WHITE, HAT, HAT_SH, ROLL }

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


# --- Appearance ---------------------------------------------------------------------------------

## Appearance of a story character. `masked`: outdoors people wear their masks.
static func appearance_for(data: CharacterData, masked: bool = false) -> Dictionary:
	var a := {
		"silhouette": data.silhouette, "skin": data.skin_color, "hair": data.hair_color,
		"coat": data.coat_color, "pants": data.pants_color, "accent": data.accent_color,
		"hair_style": "short", "coat_style": "jacket", "hat": "", "mask": "", "backpack": "",
		"accessory": data.accessory, "boots": Color(0.14, 0.12, 0.11),
	}
	for key in data.look.keys():
		a[key] = data.look[key]
	match data.accessory:
		"cap":
			a.hat = "cap"
		"hood":
			a.hat = "hood"
		"helmet":
			a.hat = "helmet"
	if masked and a.mask == "":
		a.mask = str(data.look.get("outdoor_mask", "gas"))
	return a


## The player, dressed in whatever is equipped.
static func player_appearance() -> Dictionary:
	var data := Data.get_character("player")
	var a := appearance_for(data) if data else {}
	var inv := GameState.inventory
	match inv.get_equipped("head"):
		"knit_hat":
			a.hat = "beanie"
			a.hat_color = Color(0.7, 0.2, 0.2)
		"ushanka":
			a.hat = "ushanka"
			a.hat_color = Color(0.4, 0.34, 0.28)
		"hard_hat":
			a.hat = "helmet"
			a.hat_color = Color(0.88, 0.7, 0.2)
	match inv.get_equipped("body"):
		"warm_jacket":
			a.coat = Color(0.3, 0.44, 0.36)
			a.coat_style = "puffer"
		"military_parka":
			a.coat = Color(0.36, 0.4, 0.26)
			a.coat_style = "parka"
	match inv.get_equipped("backpack"):
		"improvised_backpack":
			a.backpack = "sack"
		"small_backpack":
			a.backpack = "small"
		"hiking_backpack":
			a.backpack = "big"
		"military_backpack":
			a.backpack = "military"
	if GameState.stats.mask_on:
		match inv.get_equipped("mask"):
			"gas_mask":
				a.mask = "gas"
			"military_gas_mask":
				a.mask = "pano"
			"protective_mask":
				a.mask = "half"
	return a


static func sheet(a: Dictionary) -> Texture2D:
	var key := str(a.hash())
	if _cache.has(key):
		return _cache[key]
	var pal := _palette(a)
	var img := Image.create_empty(FRAME * COLS, FRAME * ROWS, false, Image.FORMAT_RGBA8)
	for dir in 4:
		for col in COLS:
			var c := Canvas.new()
			_person(c, dir, col, a, "")
			if dir == 3:
				c.mirror()
			c.outline()
			c.blit(img, col * FRAME, dir * FRAME, pal)
	var poses := ["sit", "lie", "crouch", "cough"]
	for i in poses.size():
		var c := Canvas.new()
		if poses[i] == "lie":
			var tmp := Canvas.new()
			_person(tmp, 2, 0, a, "")
			c = tmp.lying()
		else:
			_person(c, 0 if poses[i] != "cough" else 2, 0, a, poses[i])
		c.outline()
		c.blit(img, i * FRAME, 4 * FRAME, pal)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _palette(a: Dictionary) -> Dictionary:
	var coat: Color = a.get("coat", Color(0.3, 0.35, 0.45))
	var hair: Color = a.get("hair", Color(0.25, 0.18, 0.12))
	var skin: Color = a.get("skin", Color(0.9, 0.76, 0.64))
	var pants: Color = a.get("pants", Color(0.2, 0.2, 0.25))
	var acc: Color = a.get("accent", Color(0.8, 0.2, 0.2))
	var hat: Color = a.get("hat_color", acc)
	return {
		OUT: Color(0.05, 0.055, 0.07), SKIN: skin, SKIN_SH: skin.darkened(0.2),
		HAIR: hair, HAIR_SH: hair.darkened(0.3), COAT: coat, COAT_SH: coat.darkened(0.28),
		COAT_HI: coat.lightened(0.18), PANTS: pants, PANTS_SH: pants.darkened(0.3),
		BOOT: a.get("boots", Color(0.14, 0.12, 0.11)), ACC: acc, ACC_SH: acc.darkened(0.3),
		EYE: Color(0.06, 0.06, 0.08), SNOW: Color(0.9, 0.94, 1.0), METAL: Color(0.22, 0.23, 0.26),
		METAL_HI: Color(0.55, 0.58, 0.62), RUB: Color(0.2, 0.23, 0.2), RUB_SH: Color(0.12, 0.14, 0.12),
		GLASS: Color(0.55, 0.72, 0.8), BAG: a.get("bag_color", Color(0.3, 0.36, 0.3)),
		BAG_SH: (a.get("bag_color", Color(0.3, 0.36, 0.3)) as Color).darkened(0.3),
		BLOOD: Color(0.55, 0.06, 0.06), WHITE: Color(0.92, 0.92, 0.9), HAT: hat, HAT_SH: hat.darkened(0.3),
		ROLL: a.get("roll_color", Color(0.3, 0.46, 0.44)),
	}


static func _body(silhouette: String) -> Dictionary:
	var b := {"tw": 10, "th": 9, "lh": 9, "hw": 8, "hh": 8, "aw": 2}
	match silhouette:
		"tall":
			b.th = 10
			b.lh = 10
		"broad":
			b.tw = 12
			b.aw = 3
			b.hw = 8
		"short":
			b.th = 8
			b.lh = 7
			b.hw = 8
		"slim":
			b.tw = 8
			b.lh = 10
			b.hw = 7
	return b


# --- Drawing ------------------------------------------------------------------------------------------

## dir: 0 down, 1 up, 2 right (left is mirrored). col: see header.
static func _person(c: Canvas, dir: int, col: int, a: Dictionary, pose: String) -> void:
	var b := _body(str(a.get("silhouette", "average")))
	var tw: int = b.tw
	var th: int = b.th
	var lh: int = b.lh
	var aw: int = b.aw
	var side := dir == 2
	var back := dir == 1
	var walking := col >= 2 and col <= 5
	var phase := col - 2 if walking else 0
	# Passing frames (1 and 3) lift the body by a pixel.
	var bob := 1 if walking and phase % 2 == 1 else 0
	var breath := 1 if col == 1 else 0
	if pose == "crouch":
		lh = maxi(3, lh - 4)
	elif pose == "sit":
		lh = 2
	var cx := 16
	var feet := FRAME - 1
	var legs_top := feet - lh - bob
	var torso_top := legs_top - th
	var head_top: int = torso_top - int(b.hh) + 1 - breath
	if pose == "cough":
		torso_top += 1
		head_top += 3
	var sw := tw if not side else maxi(6, tw - 4)
	var tx := cx - sw / 2
	var long_coat := str(a.get("coat_style", "")) in ["long", "parka"]
	# --- Backpack behind the body (seen from the front/side) ---
	var pack := str(a.get("backpack", ""))
	if pack != "" and not back:
		_backpack(c, pack, side, cx, tx, sw, torso_top, th, false)
	# --- Legs ---
	_legs(c, dir, phase if walking else -1, pose, cx, tx, sw, legs_top, lh, feet, bob)
	# --- Torso ---
	var coat_h := th + (3 if long_coat else 1)
	c.rect(tx, torso_top, sw, coat_h, COAT)
	c.rect(tx + sw - 2, torso_top + 1, 2, coat_h - 1, COAT_SH)
	c.rect(tx, torso_top + coat_h - 1, sw, 1, COAT_SH)
	c.px(tx, torso_top, SNOW)
	c.px(tx + sw - 1, torso_top, SNOW)
	var style := str(a.get("coat_style", "jacket"))
	if dir == 0:
		match style:
			"puffer":
				for yy in range(torso_top + 3, torso_top + coat_h - 1, 3):
					c.rect(tx, yy, sw, 1, COAT_SH)
				c.rect(cx - 1, torso_top + 1, 1, coat_h - 2, METAL_HI)
			"parka":
				c.rect(cx - 1, torso_top + 1, 1, coat_h - 2, COAT_SH)
				c.rect(tx + 1, torso_top + th - 3, 3, 2, COAT_SH)
				c.rect(tx + sw - 4, torso_top + th - 3, 3, 2, COAT_SH)
			"long":
				c.rect(cx - 1, torso_top + 1, 1, coat_h - 2, COAT_SH)
				for i in 3:
					c.px(cx, torso_top + 2 + i * 3, METAL_HI)
			_:
				c.rect(cx - 1, torso_top + 1, 1, coat_h - 3, COAT_SH)
				c.rect(tx + 1, torso_top + th - 3, 2, 2, COAT_SH)
				c.rect(tx + sw - 3, torso_top + th - 3, 2, 2, COAT_SH)
		c.rect(tx + 1, torso_top + 1, 1, 3, COAT_HI)
	elif back:
		c.rect(cx - 1, torso_top + 2, 2, 1, COAT_SH)
	# Belt
	if style != "long" and style != "parka":
		c.rect(tx, torso_top + th - 1, sw, 1, PANTS_SH)
	# --- Arms ---
	_arms(c, dir, col, phase if walking else -1, pose, cx, tx, sw, torso_top, th, aw)
	# --- Backpack over the back ---
	if pack != "" and back:
		_backpack(c, pack, side, cx, tx, sw, torso_top, th, true)
	# --- Head ---
	_head(c, dir, a, cx, head_top, b.hw, b.hh, pose)
	# --- Accessories ---
	_accessory(c, str(a.get("accessory", "none")), dir, cx, tx, sw, torso_top, th, head_top, b.hw)


static func _legs(c: Canvas, dir: int, phase: int, pose: String, cx: int, tx: int, sw: int, top: int, lh: int, feet: int, bob: int) -> void:
	if pose == "sit":
		c.rect(cx - 6, feet - 2, 5, 2, PANTS)
		c.rect(cx + 1, feet - 2, 5, 2, PANTS_SH)
		c.rect(cx - 8, feet - 2, 2, 3, BOOT)
		c.rect(cx + 6, feet - 2, 2, 3, BOOT)
		return
	if dir == 2:
		# Side view: legs scissor.
		var off: int = [0, 2, 0, -2][phase] if phase >= 0 else 0
		var fx: int = cx - 1 + off
		var bx: int = cx - 1 - off
		c.rect(bx, top, 3, lh, PANTS_SH)
		c.rect(bx, feet - 1 - bob + (1 if phase >= 0 and off != 0 else 0), 4, 2, BOOT)
		c.rect(fx, top, 3, lh, PANTS)
		c.rect(fx, feet - 1 - bob, 4, 2, BOOT)
		return
	var lx := cx - 4
	var rx := cx + 1
	var ll := 0
	var rl := 0
	if phase == 1:
		ll = 2
	elif phase == 3:
		rl = 2
	c.rect(lx, top, 3, lh - ll, PANTS)
	c.rect(lx, top + lh - ll - 1, 4, 2, BOOT)
	c.rect(rx, top, 3, lh - rl, PANTS_SH if dir == 0 else PANTS)
	c.rect(rx, top + lh - rl - 1, 4, 2, BOOT)
	c.rect(lx + 1, top, 1, lh - ll - 2, PANTS_SH)


static func _arms(c: Canvas, dir: int, col: int, phase: int, pose: String, cx: int, tx: int, sw: int, torso_top: int, th: int, aw: int) -> void:
	var arm_len := th - 1
	if pose == "sit":
		c.rect(tx - aw, torso_top + 1, aw, arm_len - 1, COAT)
		c.rect(cx - 2, torso_top + 4, 4, 2, SKIN)
		c.rect(cx, torso_top + 6, 3, 2, BLOOD)
		c.rect(tx + sw, torso_top + 1, aw, arm_len - 1, COAT_SH)
		return
	if pose == "cough":
		# Hand to the mouth.
		c.rect(cx + 1, torso_top + 1, 2, 4, COAT_SH)
		c.rect(cx + 2, torso_top - 1, 2, 2, SKIN)
		return
	if dir == 2:
		if col == 6:
			# Aiming forward.
			c.rect(cx, torso_top + 2, 8, 2, COAT_SH)
			c.rect(cx + 8, torso_top + 2, 2, 2, SKIN)
			c.rect(cx + 9, torso_top + 1, 4, 2, METAL)
			c.px(cx + 12, torso_top + 1, METAL_HI)
		elif col == 7:
			# Swing: arm raised over the shoulder with the weapon.
			c.rect(cx, torso_top - 3, 2, 5, COAT_SH)
			c.rect(cx, torso_top - 5, 2, 2, SKIN)
			c.rect(cx - 3, torso_top - 9, 2, 5, METAL_HI)
		else:
			var swing: int = [0, 1, 0, -1][phase] if phase >= 0 else 0
			c.rect(cx - 1 + swing, torso_top + 1, aw + 1, arm_len, COAT_SH)
			c.rect(cx - 1 + swing, torso_top + arm_len + 1, aw + 1, 2, SKIN)
		return
	var la := 0
	var ra := 0
	if phase == 0:
		la = 1
	elif phase == 2:
		ra = 1
	if col == 6 and dir == 0:
		c.rect(tx - aw, torso_top + 1, aw, 4, COAT)
		c.rect(tx + sw, torso_top + 1, aw, 4, COAT_SH)
		c.rect(cx - 3, torso_top + 4, 6, 2, COAT)
		c.rect(cx - 2, torso_top + 5, 4, 2, SKIN)
		c.rect(cx - 1, torso_top + 3, 2, 3, METAL)
		return
	if col == 7:
		c.rect(tx - aw, torso_top + 1, aw, arm_len - 1, COAT)
		c.rect(tx + sw, torso_top - 4, aw, 5, COAT_SH)
		c.rect(tx + sw, torso_top - 6, aw, 2, SKIN)
		c.rect(tx + sw + 1, torso_top - 11, 2, 6, METAL_HI)
		return
	c.rect(tx - aw, torso_top + 1 + la, aw, arm_len - 1, COAT if dir == 0 else COAT_SH)
	c.rect(tx - aw, torso_top + arm_len + la, aw, 2, SKIN)
	c.rect(tx + sw, torso_top + 1 + ra, aw, arm_len - 1, COAT_SH)
	c.rect(tx + sw, torso_top + arm_len + ra, aw, 2, SKIN_SH)


static func _head(c: Canvas, dir: int, a: Dictionary, cx: int, top: int, hw: int, hh: int, pose: String) -> void:
	var side := dir == 2
	var back := dir == 1
	var w := hw - (1 if side else 0)
	var hx := cx - w / 2
	var style := str(a.get("hair_style", "short"))
	var hat := str(a.get("hat", ""))
	var mask := str(a.get("mask", ""))
	# Neck + face.
	c.rect(cx - 1, top + hh - 1, 3, 2, SKIN_SH)
	c.rect(hx, top + 1, w, hh - 1, SKIN)
	c.rect(hx + 1, top, w - 2, 1, SKIN)
	c.rect(hx + w - 1, top + 2, 1, hh - 3, SKIN_SH)
	# Hair.
	if style != "bald" or back:
		if back:
			c.rect(hx, top, w, hh - 1, HAIR)
			c.rect(hx + w - 2, top + 1, 2, hh - 2, HAIR_SH)
		elif side:
			c.rect(hx, top, w, 3, HAIR)
			c.rect(hx, top, 3, hh - 2, HAIR)
		else:
			c.rect(hx, top, w, 3, HAIR)
			c.px(hx, top + 3, HAIR)
			c.px(hx + w - 1, top + 3, HAIR)
		if style == "long" or style == "ponytail":
			if back:
				c.rect(hx, top + hh - 1, w, 4, HAIR)
			elif side:
				c.rect(hx - 1, top + 2, 3, hh + 2, HAIR)
			else:
				c.rect(hx - 1, top + 2, 1, hh, HAIR)
				c.rect(hx + w, top + 2, 1, hh, HAIR)
		elif style == "bun":
			c.rect(cx - 2, top - 2, 4, 3, HAIR)
	# Eyes / mouth.
	if not back and mask == "":
		if side:
			c.px(hx + w - 2, top + 4, EYE)
		else:
			c.px(cx - 2, top + 4, EYE)
			c.px(cx + 1, top + 4, EYE)
			if pose == "sit" or pose == "cough":
				c.rect(cx - 1, top + 6, 2, 1, SKIN_SH)
	# Hat.
	match hat:
		"beanie":
			c.rect(hx - 1, top - 1, w + 2, 4, HAT)
			c.rect(hx - 1, top + 2, w + 2, 1, HAT_SH)
			c.rect(cx - 1, top - 3, 2, 2, WHITE)
		"ushanka":
			c.rect(hx - 1, top - 2, w + 2, 4, HAT)
			c.rect(hx - 2, top + 1, w + 4, 2, HAT_SH)
			if not side:
				c.rect(hx - 2, top + 2, 2, 5, HAT_SH)
				c.rect(hx + w, top + 2, 2, 5, HAT_SH)
			else:
				c.rect(hx - 1, top + 2, 3, 5, HAT_SH)
		"helmet":
			c.rect(hx - 1, top - 2, w + 2, 4, HAT)
			c.rect(hx - 2, top + 1, w + 4, 1, HAT_SH)
			c.rect(hx, top - 2, w - 2, 1, WHITE)
		"cap":
			c.rect(hx - 1, top - 1, w + 2, 3, HAT)
			if side:
				c.rect(hx + w, top + 1, 3, 1, HAT_SH)
			elif not back:
				c.rect(hx - 1, top + 1, w + 2, 1, HAT_SH)
		"hood":
			c.rect(hx - 2, top - 2, w + 4, 3, COAT)
			if back:
				c.rect(hx - 2, top, w + 4, hh, COAT)
				c.rect(hx + w, top, 2, hh, COAT_SH)
			elif side:
				c.rect(hx - 2, top, 4, hh + 1, COAT)
			else:
				c.rect(hx - 2, top, 2, hh + 1, COAT)
				c.rect(hx + w, top, 2, hh + 1, COAT_SH)
	# Mask over the face.
	if back or mask == "":
		if mask != "" and back:
			c.rect(hx, top + 4, w, 1, RUB_SH)
		return
	match mask:
		"gas", "pano":
			if side:
				c.rect(hx + 2, top + 2, w - 2, hh - 2, RUB)
				c.rect(hx + w - 2, top + 3, 2, 2, GLASS)
				c.rect(hx + w - 1, top + 6, 3, 3, RUB_SH)
				c.px(hx + w + 1, top + 7, METAL_HI)
			else:
				c.rect(hx, top + 2, w, hh - 2, RUB)
				if mask == "gas":
					c.rect(cx - 3, top + 3, 2, 2, GLASS)
					c.rect(cx + 1, top + 3, 2, 2, GLASS)
				else:
					c.rect(cx - 3, top + 3, 6, 2, GLASS)
				c.rect(cx - 2, top + 6, 4, 3, RUB_SH)
				c.rect(cx - 1, top + 7, 2, 2, METAL)
				c.px(cx - 1, top + 7, METAL_HI)
		"half":
			if side:
				c.rect(hx + 2, top + 5, w - 2, 3, WHITE)
				c.px(hx + w, top + 6, ACC)
			else:
				c.rect(hx, top + 5, w, 3, WHITE)
				c.px(hx, top + 6, ACC)
				c.px(hx + w - 1, top + 6, ACC)
				c.px(cx - 2, top + 4, EYE)
				c.px(cx + 1, top + 4, EYE)
		"scarf":
			c.rect(hx, top + 5, w, 3, ACC)


static func _backpack(c: Canvas, pack: String, side: bool, cx: int, tx: int, sw: int, torso_top: int, th: int, over_back: bool) -> void:
	var h := th + (4 if pack in ["big", "military"] else 1)
	var w := sw - 2 + (2 if pack == "military" else 0)
	if over_back:
		var x := cx - w / 2
		var y := torso_top - (4 if pack == "big" else 0)
		c.rect(x, y, w, h, BAG)
		c.rect(x + w - 2, y + 1, 2, h - 1, BAG_SH)
		c.rect(x + 1, y + h - 5, w - 2, 3, BAG_SH)
		if pack == "big":
			c.rect(x - 1, y - 2, w + 2, 3, ROLL)
		elif pack == "military":
			c.rect(x - 2, y + 3, 2, 5, BAG_SH)
			c.rect(x + w, y + 3, 2, 5, BAG_SH)
		elif pack == "sack":
			c.rect(x + 1, y - 1, w - 2, 2, BAG)
		c.px(x + w / 2, y + 2, METAL_HI)
		return
	if side:
		var y := torso_top - (3 if pack == "big" else 0)
		c.rect(cx - 6, y, 4, h, BAG)
		c.rect(cx - 6, y + h - 1, 4, 1, BAG_SH)
		if pack == "big":
			c.rect(cx - 7, y - 2, 5, 3, ROLL)
	else:
		# Front view: only the straps and the bag's edges show.
		c.rect(tx + 1, torso_top, 1, th - 2, BAG_SH)
		c.rect(tx + sw - 2, torso_top, 1, th - 2, BAG_SH)
		if pack == "big":
			c.rect(tx - 1, torso_top - 3, sw + 2, 3, ROLL)


static func _accessory(c: Canvas, acc: String, dir: int, cx: int, tx: int, sw: int, torso_top: int, th: int, head_top: int, hw: int) -> void:
	var side := dir == 2
	match acc:
		"glasses":
			if dir == 0:
				c.rect(cx - 3, head_top + 4, 6, 1, METAL)
				c.px(cx - 2, head_top + 4, GLASS)
				c.px(cx + 1, head_top + 4, GLASS)
			elif side:
				c.rect(cx + 1, head_top + 4, 3, 1, METAL)
		"scarf":
			c.rect(tx, torso_top, sw, 2, ACC)
			if dir == 0:
				c.rect(cx + 1, torso_top + 2, 2, 4, ACC)
				c.rect(cx + 2, torso_top + 2, 1, 4, ACC_SH)
			elif side:
				c.rect(tx - 2, torso_top + 1, 2, 4, ACC)
		"armband":
			if side:
				c.rect(cx - 1, torso_top + 3, 3, 2, ACC)
			else:
				c.rect(tx - 2, torso_top + 3, 2, 2, ACC)
				c.px(tx - 2, torso_top + 3, BLOOD)
		"bag":
			if dir == 0:
				for i in th:
					c.px(tx + i * sw / th, torso_top + i, ACC_SH)
				c.rect(tx + sw, torso_top + th - 4, 3, 4, ACC)
			elif dir == 1:
				c.rect(tx + 1, torso_top + 2, sw - 2, th - 4, ACC)
			else:
				c.rect(tx - 3, torso_top + 3, 3, th - 4, ACC)


## Paletted pixel canvas with outline, mirroring and blitting.
class Canvas:
	var g: PackedByteArray
	var w: int
	var h: int

	func _init(width: int = CharacterArt.FRAME, height: int = CharacterArt.FRAME) -> void:
		w = width
		h = height
		g = PackedByteArray()
		g.resize(w * h)
		g.fill(CharacterArt.T)

	func rect(x: int, y: int, rw: int, rh: int, c: int) -> void:
		for yy in range(maxi(0, y), mini(h, y + rh)):
			for xx in range(maxi(0, x), mini(w, x + rw)):
				g[yy * w + xx] = c

	func px(x: int, y: int, c: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			g[y * w + x] = c

	func get_px(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= w or y >= h:
			return CharacterArt.T
		return g[y * w + x]

	func mirror() -> void:
		var out := g.duplicate()
		for y in h:
			for x in w:
				out[y * w + x] = g[y * w + (w - 1 - x)]
		g = out

	func outline() -> void:
		var out := g.duplicate()
		for y in h:
			for x in w:
				if g[y * w + x] != CharacterArt.T:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var v := get_px(x + d.x, y + d.y)
					if v != CharacterArt.T and v != CharacterArt.OUT:
						out[y * w + x] = CharacterArt.OUT
						break
		g = out

	## The side view rotated onto the ground (a body lying in the snow).
	func lying() -> Canvas:
		var out := Canvas.new(w, h)
		for y in h:
			for x in w:
				var v := g[y * w + x]
				if v == CharacterArt.T:
					continue
				out.px(h - 1 - y + 2, x - 2 + h / 4, v)
		return out

	func blit(img: Image, ox: int, oy: int, pal: Dictionary) -> void:
		for y in h:
			for x in w:
				var v := g[y * w + x]
				if v != CharacterArt.T:
					img.set_pixel(ox + x, oy + y, pal.get(v, Color.MAGENTA))
