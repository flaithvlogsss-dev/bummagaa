class_name PixelCharacter
extends Sprite3D
## PixelCharacter — billboarded pixel-art sprite animator for the player, NPCs and enemies.
##
## Purpose: picks the sheet row from the facing direction relative to the active camera
##   (so it keeps working if the camera yaw changes) and cycles walk frames.
## Public API: setup_character(data), setup_sheet(tex, w, h, cols, rows), face(dir),
##   moving, aiming, pose ("", "sit", "lie", "crouch"), flash(color)

## World-space facing on the XZ plane.
var facing: Vector2 = Vector2(0, 1)
var moving: bool = false
var aiming: bool = false
var pose: String = ""
var anim_fps: float = 7.0

var _frame_w: int = PixelArt.FRAME_W
var _frame_h: int = PixelArt.FRAME_H
var _anim_t: float = 0.0
var _walk_cycle: Array[int] = [1, 0, 2, 0]
var _has_special: bool = true
var _flash_tween: Tween


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = true
	double_sided = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pixel_size = 0.072


func setup_character(data: CharacterData) -> void:
	setup_sheet(PixelArt.character_sheet(data), PixelArt.FRAME_W, PixelArt.FRAME_H, PixelArt.COLS, PixelArt.ROWS)
	_has_special = true


func setup_sheet(tex: Texture2D, w: int, h: int, cols: int, rows: int) -> void:
	texture = tex
	_frame_w = w
	_frame_h = h
	hframes = cols
	vframes = rows
	_has_special = rows > 4
	centered = true
	# Feet at the node origin.
	offset = Vector2(0, h * 0.5)


func face(dir: Vector2) -> void:
	if dir.length_squared() > 0.0001:
		facing = dir.normalized()


func _process(delta: float) -> void:
	if pose != "" and _has_special:
		var col: int = int({"sit": 0, "lie": 1, "crouch": 2}.get(pose, 0))
		frame = 4 * hframes + col
		return
	var row := _direction_row()
	var col := 0
	if aiming and hframes > 3:
		col = 3
	elif moving:
		_anim_t += delta * anim_fps
		col = _walk_cycle[int(_anim_t) % _walk_cycle.size()]
	else:
		_anim_t = 0.0
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
