class_name PixelCharacter
extends Sprite3D
## PixelCharacter — billboarded pixel-art sprite animator for the player, NPCs and enemies.
##
## Purpose: picks the sheet row from the facing direction relative to the active camera
##   (so it keeps working if the camera yaw changes), breathes when idle, cycles walk frames
##   and plays short one-shot actions (melee swing, cough).
## Layouts: CharacterArt sheets (8 cols: idle x2, walk x4, aim, swing; special row) and the
##   compact enemy sheets (4 cols: idle, walk A, walk B, attack).
## Public API: setup_character(data, masked), setup_appearance(dict), setup_sheet(tex, w, h,
##   cols, rows, layout), face(dir), moving, aiming, pose ("", "sit", "lie", "crouch"),
##   play_action("swing" | "cough"), flash(color)

const LAYOUT_PERSON := {"idle": [0, 1], "walk": [2, 3, 4, 5], "aim": 6, "swing": 7,
	"special": {"sit": 0, "lie": 1, "crouch": 2, "cough": 3}}
const LAYOUT_COMPACT := {"idle": [0], "walk": [1, 0, 2, 0], "aim": 3, "swing": 3,
	"special": {"sit": 0, "lie": 1, "crouch": 2}}

## World-space facing on the XZ plane.
var facing: Vector2 = Vector2(0, 1)
var moving: bool = false
var aiming: bool = false
var pose: String = ""
var anim_fps: float = 7.0

var _layout: Dictionary = LAYOUT_PERSON
var _anim_t: float = 0.0
var _idle_t: float = 0.0
var _has_special: bool = true
var _flash_tween: Tween
var _action: String = ""
var _action_t: float = 0.0
var _appearance_key: int = 0


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = true
	double_sided = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pixel_size = 0.062


func setup_character(data: CharacterData, masked: bool = false) -> void:
	if data and data.sprite_sheet:
		setup_sheet(data.sprite_sheet, CharacterArt.FRAME, CharacterArt.FRAME, CharacterArt.COLS, CharacterArt.ROWS, LAYOUT_PERSON)
		return
	setup_appearance(CharacterArt.appearance_for(data, masked))


## Rebuilds the sheet only when the appearance actually changed.
func setup_appearance(a: Dictionary) -> void:
	var key := a.hash()
	if key == _appearance_key and texture != null:
		return
	_appearance_key = key
	setup_sheet(CharacterArt.sheet(a), CharacterArt.FRAME, CharacterArt.FRAME, CharacterArt.COLS, CharacterArt.ROWS, LAYOUT_PERSON)


func setup_sheet(tex: Texture2D, _w: int, h: int, cols: int, rows: int, layout: Dictionary = LAYOUT_COMPACT) -> void:
	texture = tex
	hframes = cols
	vframes = rows
	_layout = layout
	_has_special = rows > 4
	centered = true
	# Feet at the node origin.
	offset = Vector2(0, h * 0.5)


func face(dir: Vector2) -> void:
	if dir.length_squared() > 0.0001:
		facing = dir.normalized()


## One-shot action frames: "swing" (melee), "cough" (bent over).
func play_action(action: String, duration: float = 0.3) -> void:
	_action = action
	_action_t = duration


func _process(delta: float) -> void:
	if _action_t > 0.0:
		_action_t -= delta
		if _action_t <= 0.0:
			_action = ""
	var special: Dictionary = _layout.get("special", {})
	var special_pose := pose
	if _action == "cough" and special.has("cough") and pose == "":
		special_pose = "cough"
	if special_pose != "" and _has_special and special.has(special_pose):
		frame = 4 * hframes + int(special[special_pose])
		return
	var row := _direction_row()
	var col := 0
	var idle: Array = _layout.get("idle", [0])
	if _action == "swing":
		col = int(_layout.get("swing", 0))
	elif aiming:
		col = int(_layout.get("aim", 0))
	elif moving:
		var walk: Array = _layout.get("walk", [0])
		_anim_t += delta * anim_fps
		col = int(walk[int(_anim_t) % walk.size()])
	else:
		_anim_t = 0.0
		_idle_t += delta
		# Slow breathing: a short rise every ~1.6 s.
		col = int(idle[1]) if idle.size() > 1 and fmod(_idle_t, 1.6) > 1.0 else int(idle[0])
	frame = row * hframes + col


func _direction_row() -> int:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var d3 := Vector3(facing.x, 0.0, facing.y)
	if cam:
		d3 = cam.global_basis.inverse() * d3
	if absf(d3.x) > absf(d3.z) * 1.1:
		return 2 if d3.x > 0.0 else 3
	return 0 if d3.z > 0.0 else 1


## Brief colour flash (hit feedback).
func flash(col: Color = Color(1, 0.4, 0.4)) -> void:
	if _flash_tween:
		_flash_tween.kill()
	modulate = col
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.25)
