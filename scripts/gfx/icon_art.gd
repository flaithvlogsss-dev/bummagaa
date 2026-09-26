class_name IconArt
extends RefCounted
## IconArt — 16x16 pixel icons drawn from ASCII templates (res://data/art/icons.txt).
##
## Purpose: every item gets its own icon without external assets. A template is a tight
##   block of legend characters; it is centered on the 16x16 canvas and outlined here.
##   Items choose a template with ItemData.icon_shape ("book" or "book+cross" for a template
##   plus a 5x5 badge) and recolour it with ItemData.icon_colors (colours 1..4).
##   An ItemData.icon texture, when set, always wins.
## Public API: item_icon(item), template_icon(shape, colors), has_template(name), template_names(),
##   clear_cache()

const ICONS_PATH := "res://data/art/icons.txt"
const SIZE := 16
const OUTLINE := Color(0.06, 0.07, 0.09)
const FIXED := {
	"k": Color(0.08, 0.08, 0.1), "w": Color(0.92, 0.92, 0.88), "m": Color(0.6, 0.62, 0.66),
	"n": Color(0.34, 0.36, 0.4), "M": Color(0.84, 0.86, 0.88), "r": Color(0.8, 0.22, 0.18),
	"y": Color(0.96, 0.8, 0.3), "o": Color(0.95, 0.55, 0.2), "g": Color(0.62, 0.8, 0.92),
	"e": Color(0.42, 0.62, 0.3), "b": Color(0.6, 0.42, 0.24), "B": Color(0.4, 0.27, 0.15),
	"v": Color(0.92, 0.94, 0.96, 0.7),
}
## Pixels that never get an outline (steam, sparks).
const SOFT := "v"

static var _templates: Dictionary = {}
static var _badges: Dictionary = {}
static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()
	_templates.clear()
	_badges.clear()


static func item_icon(item: ItemData) -> Texture2D:
	if item == null:
		return null
	if item.icon:
		return item.icon
	var key := "item:" + item.id
	if not _cache.has(key):
		_cache[key] = template_icon(item.icon_shape, item.icon_colors)
	return _cache[key]


## Draws a template ("shape" or "shape+badge") with optional colour overrides.
static func template_icon(shape: String, colors: PackedColorArray = PackedColorArray()) -> Texture2D:
	_load()
	var key := "tpl:%s:%s" % [shape, str(colors)]
	if _cache.has(key):
		return _cache[key]
	var parts := shape.split("+")
	var tpl: Dictionary = _templates.get(parts[0], _templates.get("can", {}))
	if tpl.is_empty():
		return null
	var palette: Array = tpl.colors.duplicate()
	for i in mini(colors.size(), palette.size()):
		palette[i] = colors[i]
	var rows: Array = tpl.rows
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	var ox := (SIZE - w) / 2
	var oy := (SIZE - h) / 2
	var chars := []
	chars.resize(SIZE * SIZE)
	chars.fill(".")
	for y in h:
		for x in rows[y].length():
			chars[(oy + y) * SIZE + ox + x] = rows[y][x]
	if parts.size() > 1 and _badges.has(parts[1]):
		var b: Array = _badges[parts[1]]
		var bp: Vector2i = tpl.badge if tpl.badge.x >= 0 else Vector2i(w - 5, h - 5)
		for y in b.size():
			for x in b[y].length():
				var px: int = ox + bp.x + x
				var py: int = oy + bp.y + y
				if b[y][x] != "." and px >= 0 and py >= 0 and px < SIZE and py < SIZE:
					chars[py * SIZE + px] = b[y][x]
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var c: String = chars[y * SIZE + x]
			if c != ".":
				img.set_pixel(x, y, _color(c, palette))
			elif _needs_outline(chars, x, y):
				img.set_pixel(x, y, OUTLINE)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func has_template(template_name: String) -> bool:
	_load()
	return _templates.has(template_name.split("+")[0])


static func has_badge(badge_name: String) -> bool:
	_load()
	return _badges.has(badge_name)


static func template_names() -> Array:
	_load()
	return _templates.keys()


static func _needs_outline(chars: Array, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= SIZE or ny >= SIZE:
			continue
		var c: String = chars[ny * SIZE + nx]
		if c != "." and not SOFT.contains(c):
			return true
	return false


static func _color(c: String, palette: Array) -> Color:
	match c:
		"1", "2", "3", "4":
			return palette[int(c) - 1]
		"h":
			return (palette[0] as Color).lightened(0.35)
		"s":
			return (palette[0] as Color).darkened(0.35)
		"H":
			return (palette[1] as Color).lightened(0.35)
		"S":
			return (palette[1] as Color).darkened(0.35)
	return FIXED.get(c, Color.MAGENTA)


static func _load() -> void:
	if not _templates.is_empty():
		return
	var file := FileAccess.open(ICONS_PATH, FileAccess.READ)
	if file == null:
		push_warning("IconArt: cannot open %s" % ICONS_PATH)
		return
	var current: Dictionary = {}
	var badge_name := ""
	for raw in file.get_as_text().split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		if line.is_empty():
			current = {}
			badge_name = ""
			continue
		if line.begins_with("@@"):
			badge_name = line.substr(2)
			_badges[badge_name] = []
			current = {}
			continue
		if line.begins_with("@"):
			badge_name = ""
			current = _parse_header(line)
			_templates[current.name] = current
			continue
		if not badge_name.is_empty():
			(_badges[badge_name] as Array).append(line)
		elif not current.is_empty():
			(current.rows as Array).append(line)


static func _parse_header(line: String) -> Dictionary:
	var parts := line.substr(1).split(" ", false)
	var colors: Array = [Color(0.6, 0.6, 0.62), Color(0.45, 0.45, 0.5), Color(0.8, 0.3, 0.2), Color(0.9, 0.9, 0.85)]
	var badge := Vector2i(-1, -1)
	for i in range(1, parts.size()):
		var kv := parts[i].split("=")
		if kv.size() != 2:
			continue
		if kv[0] == "badge":
			var xy := kv[1].split(",")
			badge = Vector2i(int(xy[0]), int(xy[1]))
		elif kv[0].is_valid_int():
			var idx := int(kv[0]) - 1
			if idx >= 0 and idx < colors.size():
				colors[idx] = Color(kv[1])
	return {"name": parts[0], "rows": [], "colors": colors, "badge": badge}
