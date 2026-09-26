class_name EnemyArt
extends RefCounted
## EnemyArt — procedural sheets for the things in the snow (40x48 frames).
##
## stalker: tall, thin, pale, hunched, arms to the knees — fast and hungry.
## watcher: a very tall still figure in a long dark shape, a pale face plate with a glowing
##          slit — sees far, rarely moves.
## brute:   broad, heavy, crusted with ice, fists like stones — slow and strong.
## Layout (PixelCharacter.LAYOUT_COMPACT): cols 0 idle, 1 walk A, 2 walk B, 3 attack;
##   rows 0 down, 1 up, 2 right, 3 left (mirrored), 4 special (0 dead, 1 dead, 2 crouch).
## Public API: sheet(kind), W, H

const W := 40
const H := 48
const COLS := 4
const ROWS := 5

static var _cache: Dictionary = {}

# Palette slots reuse CharacterArt's enum values.
const C := preload("res://scripts/gfx/character_art.gd")


static func clear_cache() -> void:
	_cache.clear()


static func sheet(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var pal := _palette(kind)
	var img := Image.create_empty(W * COLS, H * ROWS, false, Image.FORMAT_RGBA8)
	for dir in 4:
		for col in COLS:
			var cv := CharacterArt.Canvas.new(W, H)
			_draw(cv, kind, 2 if dir == 3 else dir, col)
			if dir == 3:
				cv.mirror()
			cv.outline()
			cv.blit(img, col * W, dir * H, pal)
	# Special row: the fallen body (side view on the ground) and a crouch.
	var side := CharacterArt.Canvas.new(W, H)
	_draw(side, kind, 2, 0)
	var dead := side.lying()
	dead.outline()
	dead.blit(img, 0, 4 * H, pal)
	dead.blit(img, W, 4 * H, pal)
	var crouch := CharacterArt.Canvas.new(W, H)
	_draw(crouch, kind, 0, 1)
	crouch.outline()
	crouch.blit(img, 2 * W, 4 * H, pal)
	var tex := ImageTexture.create_from_image(img)
	_cache[kind] = tex
	return tex


static func _palette(kind: String) -> Dictionary:
	var skin := Color(0.78, 0.84, 0.9)
	var rags := Color(0.2, 0.22, 0.26)
	var glow := Color(0.55, 0.9, 1.0)
	match kind:
		"watcher":
			skin = Color(0.86, 0.86, 0.82)
			rags = Color(0.11, 0.12, 0.15)
			glow = Color(1.0, 0.55, 0.2)
		"brute":
			skin = Color(0.5, 0.56, 0.63)
			rags = Color(0.22, 0.24, 0.27)
			glow = Color(0.75, 0.9, 1.0)
	return {
		C.OUT: Color(0.04, 0.045, 0.06), C.SKIN: skin, C.SKIN_SH: skin.darkened(0.3),
		C.COAT: rags, C.COAT_SH: rags.darkened(0.35), C.COAT_HI: rags.lightened(0.2),
		C.EYE: Color(0.03, 0.03, 0.05), C.GLASS: glow, C.SNOW: Color(0.88, 0.94, 1.0),
		C.WHITE: Color(0.95, 0.97, 1.0), C.METAL: Color(0.3, 0.33, 0.38), C.BLOOD: Color(0.4, 0.05, 0.08),
	}


static func _draw(c: CharacterArt.Canvas, kind: String, dir: int, col: int) -> void:
	match kind:
		"watcher":
			_watcher(c, dir, col)
		"brute":
			_brute(c, dir, col)
		_:
			_stalker(c, dir, col)


# --- Stalker -------------------------------------------------------------------------------------

static func _stalker(c: CharacterArt.Canvas, dir: int, col: int) -> void:
	var cx := 20
	var ground := H - 1
	var step := 0 if col == 0 or col == 3 else (1 if col == 1 else -1)
	var attack := col == 3
	var side := dir == 2
	var hip := ground - 17
	# Legs: long, thin, knees bent.
	if side:
		c.rect(cx - 2 - step * 3, hip, 2, 9, C.SKIN_SH)
		c.rect(cx - 3 - step * 4, hip + 9, 2, 8, C.SKIN_SH)
		c.rect(cx - 4 - step * 4, ground, 4, 1, C.SKIN_SH)
		c.rect(cx + step * 3, hip, 2, 9, C.SKIN)
		c.rect(cx - 1 + step * 4, hip + 9, 2, 8, C.SKIN)
		c.rect(cx - 2 + step * 4, ground, 4, 1, C.SKIN)
	else:
		c.rect(cx - 4, hip, 2, 9 - maxi(0, step) * 2, C.SKIN)
		c.rect(cx - 5, hip + 9 - maxi(0, step) * 2, 2, 8, C.SKIN)
		c.rect(cx + 2, hip, 2, 9 - maxi(0, -step) * 2, C.SKIN_SH)
		c.rect(cx + 3, hip + 9 - maxi(0, -step) * 2, 2, 8, C.SKIN_SH)
		c.rect(cx - 6, ground, 3, 1, C.SKIN)
		c.rect(cx + 3, ground, 3, 1, C.SKIN_SH)
	# Torso: narrow, hunched forward (side view leans towards +x).
	var lean := 3 if side else 0
	var top := hip - 13
	for i in 13:
		var shift := lean * (13 - i) / 13
		c.rect(cx - 3 + shift, top + i, 7 if not side else 5, 1, C.SKIN)
	# Ribs and rags.
	if dir == 0:
		for i in 3:
			c.rect(cx - 2, top + 4 + i * 2, 5, 1, C.SKIN_SH)
		c.rect(cx - 3, hip - 3, 7, 4, C.COAT)
		c.rect(cx - 2, hip + 1, 2, 3, C.COAT_SH)
	elif dir == 1:
		c.rect(cx, top + 2, 1, 10, C.SKIN_SH)
		c.rect(cx - 3, hip - 3, 7, 4, C.COAT)
	else:
		c.rect(cx - 1, hip - 3, 5, 4, C.COAT)
	# Frost on the shoulders.
	c.rect(cx - 3 + lean, top, 3, 1, C.SNOW)
	# Arms: long enough to reach the knees; claws.
	if attack:
		if side:
			c.rect(cx + lean, top + 2, 12, 2, C.SKIN)
			c.rect(cx + lean + 12, top, 2, 2, C.WHITE)
			c.rect(cx + lean + 12, top + 3, 2, 2, C.WHITE)
		else:
			c.rect(cx - 10, top - 4, 2, 10, C.SKIN)
			c.rect(cx + 9, top - 4, 2, 10, C.SKIN_SH)
			c.rect(cx - 11, top - 6, 3, 2, C.WHITE)
			c.rect(cx + 9, top - 6, 3, 2, C.WHITE)
	elif side:
		c.rect(cx + lean - step * 2, top + 2, 2, 19, C.SKIN_SH)
		c.rect(cx + lean - step * 2, top + 21, 3, 2, C.WHITE)
	else:
		c.rect(cx - 6, top + 1 + maxi(0, step), 2, 19, C.SKIN)
		c.rect(cx + 5, top + 1 + maxi(0, -step), 2, 19, C.SKIN_SH)
		c.rect(cx - 7, top + 20 + maxi(0, step), 3, 2, C.WHITE)
		c.rect(cx + 5, top + 20 + maxi(0, -step), 3, 2, C.WHITE)
	# Head: small, pushed forward, hollow eyes.
	var hx := cx - 3 + (lean + 2 if side else 0)
	var hy := top - 6 + (2 if side else 0)
	c.rect(hx, hy, 6, 6, C.SKIN)
	c.rect(hx + 5, hy + 1, 1, 5, C.SKIN_SH)
	if dir == 0:
		c.rect(hx + 1, hy + 2, 2, 2, C.EYE)
		c.rect(hx + 4, hy + 2, 1, 2, C.EYE)
		c.px(hx + 1, hy + 2, C.GLASS)
		c.rect(hx + 2, hy + 5, 2, 1, C.EYE if attack else C.SKIN_SH)
	elif side:
		c.rect(hx + 4, hy + 2, 2, 2, C.EYE)
		c.px(hx + 5, hy + 2, C.GLASS)
		if attack:
			c.rect(hx + 3, hy + 4, 3, 2, C.EYE)


# --- Watcher -------------------------------------------------------------------------------------

static func _watcher(c: CharacterArt.Canvas, dir: int, col: int) -> void:
	var cx := 20
	var ground := H - 1
	var sway := 0 if col == 0 or col == 3 else (1 if col == 1 else -1)
	var side := dir == 2
	var gaze := col == 3
	# Thin legs under the hem.
	c.rect(cx - 3 + sway, ground - 6, 2, 6, C.COAT_SH)
	c.rect(cx + 2 - sway, ground - 6, 2, 6, C.COAT_SH)
	# Long dark shape widening to the hem.
	var top := ground - 34
	for i in 28:
		var half := 3 + i / 5
		if side:
			half = 2 + i / 7
		c.rect(cx - half + (sway if i > 18 else 0), top + i, half * 2 + 1, 1, C.COAT)
	c.rect(cx + 1, top + 2, 1, 25, C.COAT_SH)
	c.rect(cx - 5, top + 26, 11, 1, C.COAT_HI)
	# Arms: very thin, hanging down to the hem; in "gaze" one points forward.
	if gaze:
		if side:
			c.rect(cx + 2, top + 5, 13, 1, C.SKIN_SH)
			c.rect(cx + 15, top + 4, 2, 3, C.SKIN)
		else:
			c.rect(cx + 6, top + 3, 1, 8, C.SKIN_SH)
			c.rect(cx + 6, top - 1, 1, 4, C.SKIN)
	elif not side:
		c.rect(cx - 7, top + 5, 1, 20, C.SKIN_SH)
		c.rect(cx + 7, top + 5, 1, 20, C.SKIN_SH)
		c.rect(cx - 8, top + 25, 2, 2, C.SKIN)
		c.rect(cx + 7, top + 25, 2, 2, C.SKIN)
	# Tall head: a pale plate with a single vertical slit that glows.
	var hx := cx - 3
	var hy := top - 11
	c.rect(cx - 1, top - 2, 3, 3, C.COAT_SH)
	if dir == 1:
		c.rect(hx, hy, 7, 10, C.COAT)
		c.rect(hx + 1, hy + 1, 5, 8, C.COAT_SH)
		return
	c.rect(hx + (1 if side else 0), hy, 7 - (2 if side else 0), 10, C.SKIN)
	c.rect(hx + 5 - (1 if side else 0), hy + 1, 1, 8, C.SKIN_SH)
	var slit_x := hx + 3 + (1 if side else 0)
	c.rect(slit_x, hy + 2, 1, 6 if not gaze else 7, C.GLASS)
	if gaze:
		c.px(slit_x - 1, hy + 4, C.GLASS)
		c.px(slit_x + 1, hy + 4, C.GLASS)


# --- Brute ---------------------------------------------------------------------------------------

static func _brute(c: CharacterArt.Canvas, dir: int, col: int) -> void:
	var cx := 20
	var ground := H - 1
	var step := 0 if col == 0 or col == 3 else (1 if col == 1 else -1)
	var smash := col == 3
	var side := dir == 2
	# Short, thick legs.
	var hip := ground - 11
	if side:
		c.rect(cx - 4 - step * 2, hip, 5, 11, C.SKIN_SH)
		c.rect(cx - 1 + step * 2, hip, 5, 11, C.SKIN)
		c.rect(cx - 5 - step * 2, ground - 1, 7, 2, C.COAT_SH)
		c.rect(cx - 2 + step * 2, ground - 1, 7, 2, C.COAT)
	else:
		c.rect(cx - 8, hip + maxi(0, step), 6, 11 - maxi(0, step), C.SKIN)
		c.rect(cx + 2, hip + maxi(0, -step), 6, 11 - maxi(0, -step), C.SKIN_SH)
		c.rect(cx - 9, ground - 1, 7, 2, C.COAT)
		c.rect(cx + 2, ground - 1, 7, 2, C.COAT_SH)
	# Huge hunched torso.
	var top := hip - 17
	var tw := 20 if not side else 14
	c.rect(cx - tw / 2, top + 2, tw, 15, C.SKIN)
	c.rect(cx - tw / 2 + 2, top, tw - 4, 3, C.SKIN)
	c.rect(cx + tw / 2 - 4, top + 2, 4, 15, C.SKIN_SH)
	c.rect(cx - tw / 2, hip - 3, tw, 5, C.COAT)
	c.rect(cx - tw / 2, hip + 1, tw, 1, C.COAT_SH)
	# Ice crust on shoulders and back.
	for i in 4:
		c.rect(cx - tw / 2 + 1 + i * 5, top - 2 + (i % 2), 3, 3, C.SNOW)
		c.px(cx - tw / 2 + 2 + i * 5, top - 3 + (i % 2), C.WHITE)
	if dir == 1:
		for i in 3:
			c.rect(cx - 6 + i * 5, top + 5 + i * 2, 3, 4, C.GLASS)
	# Arms: massive, fists near the ground.
	if smash:
		if side:
			c.rect(cx + 2, top - 10, 6, 12, C.SKIN)
			c.rect(cx + 1, top - 15, 8, 6, C.SKIN_SH)
		else:
			c.rect(cx - tw / 2 - 5, top - 8, 6, 12, C.SKIN)
			c.rect(cx + tw / 2 - 1, top - 8, 6, 12, C.SKIN_SH)
			c.rect(cx - 8, top - 14, 16, 6, C.SKIN_SH)
	elif side:
		c.rect(cx + 2 - step, top + 3, 6, 17, C.SKIN_SH)
		c.rect(cx + 1 - step, top + 19, 8, 6, C.SKIN)
	else:
		c.rect(cx - tw / 2 - 5, top + 3 + maxi(0, step), 6, 17, C.SKIN)
		c.rect(cx + tw / 2 - 1, top + 3 + maxi(0, -step), 6, 17, C.SKIN_SH)
		c.rect(cx - tw / 2 - 6, top + 19 + maxi(0, step), 8, 6, C.SKIN_SH)
		c.rect(cx + tw / 2 - 2, top + 19 + maxi(0, -step), 8, 6, C.SKIN_SH)
	# Small head sunk between the shoulders.
	if dir == 1:
		return
	var hx := cx - 3 + (5 if side else 0)
	var hy := top + 1
	c.rect(hx, hy, 7, 6, C.SKIN_SH)
	if side:
		c.rect(hx + 5, hy + 2, 2, 1, C.GLASS)
		c.rect(hx + 4, hy + 4, 3, 1, C.EYE)
	else:
		c.rect(hx + 1, hy + 2, 2, 1, C.GLASS)
		c.rect(hx + 4, hy + 2, 2, 1, C.GLASS)
		c.rect(hx + 2, hy + 4, 3, 1, C.EYE if smash else C.SKIN)
