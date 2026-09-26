class_name VisorOverlay
extends Control
## VisorOverlay — what the world looks like through the worn mask.
##
## A low-resolution frame (rubber edges and eyepieces, scaled with nearest filtering so it
## matches the pixel art) generated per mask shape, a condensation layer that fogs up with
## breathing, cold and sprinting, and cracks when the mask is badly worn. Slides down when
## the mask is pulled on and fades when it comes off.

const W := 320
const H := 180

var _frame: TextureRect
var _fog: TextureRect
var _cracks: TextureRect
var _shape: String = ""
var _shown: float = 0.0
var _breath_t: float = 0.0
static var _cache: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog = _layer()
	_cracks = _layer()
	_frame = _layer()
	visible = false


func _layer() -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


## Updated by ScreenEffects each frame.
func update_visor(delta: float, player: Player) -> void:
	var inv := GameState.inventory
	var item := inv.get_equipped_item("mask")
	var wearing := player != null and item != null and GameState.stats.mask_on
	var target := 1.0 if wearing else 0.0
	_shown = move_toward(_shown, target, delta * (2.8 if wearing else 4.0))
	visible = _shown > 0.01
	if not visible:
		return
	if item:
		var shape := _shape_for(item)
		if shape != _shape:
			_shape = shape
			_frame.texture = _texture(shape, "frame")
			_fog.texture = _texture(shape, "fog")
			_cracks.texture = _texture(shape, "cracks")
	# Pull on: the frame slides down from above the eyes.
	var slide := 1.0 - _shown
	position.y = -slide * size.y * 0.35
	modulate.a = clampf(_shown * 1.4, 0.0, 1.0)
	# Condensation: breathing rhythm, more when cold, sprinting or the filter is clogged.
	_breath_t += delta
	var s := GameState.stats
	var cold := clampf((50.0 - s.temperature) / 50.0, 0.0, 1.0)
	var exert := 0.35 if player.is_sprinting else 0.0
	var clog := 0.25 if player.exposure and player.exposure.is_wearing() and player.exposure.filter_fraction() < ExposureSystem.FILTER_LOW else 0.0
	var rhythm := 0.5 + 0.5 * sin(_breath_t * TAU / (2.2 if not player.is_sprinting else 1.2))
	_fog.modulate.a = clampf(0.12 + cold * 0.35 + exert + clog, 0.0, 0.85) * (0.55 + 0.45 * rhythm)
	var cond := float(inv.get_equipped_stack("mask").get("cond", 100.0))
	_cracks.visible = cond < 35.0
	_cracks.modulate.a = clampf((35.0 - cond) / 25.0, 0.3, 1.0)


static func _shape_for(item: ItemData) -> String:
	match item.icon_shape:
		"panomask":
			return "panoramic"
		"respirator":
			return "half"
	return "twin"


## 0 = open view, 1 = rubber. Distance-to-edge is used for rims and fog.
static func _inside(shape: String, x: float, y: float) -> float:
	var u := x / W
	var v := y / H
	match shape:
		"twin":
			var dl := Vector2((u - 0.31) / 0.3, (v - 0.48) / 0.54).length()
			var dr := Vector2((u - 0.69) / 0.3, (v - 0.48) / 0.54).length()
			return minf(dl, dr)
		"panoramic":
			var d := Vector2((u - 0.5) / 0.54, (v - 0.47) / 0.53)
			return pow(pow(absf(d.x), 3.0) + pow(absf(d.y), 3.0), 1.0 / 3.0)
		"half":
			return 0.0 if v < 0.9 else 1.2
	return 0.0


static func _texture(shape: String, kind: String) -> Texture2D:
	var key := shape + ":" + kind
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	match kind:
		"frame":
			for y in H:
				for x in W:
					var d := _inside(shape, x + 0.5, y + 0.5)
					if d >= 1.0:
						var shade := 0.03 + 0.02 * float((x / 3 + y / 3) % 2) * 0.5
						img.set_pixel(x, y, Color(shade, shade + 0.006, shade + 0.01, 0.86))
					elif d > 0.955:
						img.set_pixel(x, y, Color(0.2, 0.22, 0.24, 0.95))
					elif d > 0.93:
						img.set_pixel(x, y, Color(0.42, 0.45, 0.48, 0.7))
					elif shape == "half" and y > H - 22:
						img.set_pixel(x, y, Color(0.02, 0.025, 0.03, float(y - (H - 22)) / 22.0 * 0.8))
		"fog":
			for y in H:
				for x in W:
					var d := _inside(shape, x + 0.5, y + 0.5)
					if d < 1.0:
						# Thicker near the lower edge of the glass, where breath rises.
						var edge := smoothstep(0.55, 0.97, d)
						var low := clampf((float(y) / H - 0.35) * 1.5, 0.0, 1.0)
						var speck := 0.8 + 0.2 * rng.randf()
						img.set_pixel(x, y, Color(0.86, 0.9, 0.94, clampf(edge * (0.4 + low * 0.6) * speck, 0.0, 0.9)))
		"cracks":
			for c in 3:
				var p := Vector2(rng.randf_range(0.15, 0.85) * W, rng.randf_range(0.2, 0.8) * H)
				for branch in 4:
					var q := p
					var dir := Vector2.from_angle(rng.randf() * TAU)
					for step in rng.randi_range(18, 40):
						dir = dir.rotated(rng.randf_range(-0.5, 0.5))
						q += dir
						var ix := int(q.x)
						var iy := int(q.y)
						if ix >= 0 and iy >= 0 and ix < W and iy < H and _inside(shape, ix, iy) < 0.95:
							img.set_pixel(ix, iy, Color(0.95, 0.97, 1.0, 0.75))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
