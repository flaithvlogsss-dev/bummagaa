@tool
class_name LowPolyBlock
extends StaticBody3D
## LowPolyBlock — the basic editable building brick (walls, roofs, floors, roads, furniture).
##
## Purpose: builds its own mesh + collision from `size`, so a level is just a list of blocks
##   positioned in the editor. Origin is the bottom-centre of the block.
## All blocks share one ShaderMaterial; colour / snow exposure are per-instance uniforms.
## Groups: add "cutaway:<id>" to hide the block while the player is inside that building.
## Public API: set_fade(amount), set_occluding(bool)

const MATERIAL_PATH := "res://shaders/lowpoly_snow.gdshader"

@export var size: Vector3 = Vector3(4, 3, 4):
	set(v):
		size = v
		_rebuild()
@export var color: Color = Color(0.45, 0.46, 0.5):
	set(v):
		color = v
		_rebuild()
@export_enum("box", "gable", "cylinder") var shape: String = "box":
	set(v):
		shape = v
		_rebuild()
## Surface material (WorldTextures); "auto" guesses from shape, size and colour.
@export_enum("auto", "plain", "asphalt", "sidewalk", "snow", "slush", "concrete", "brick", "plaster",
	"metal", "rust", "planks", "glass", "dirt", "ice", "roof", "door", "container", "paint",
	"floor_tiles", "wallpaper", "fabric", "parquet", "cardboard", "plastic", "wall_tiles", "cobble") var material: String = "auto":
	set(v):
		material = v
		_rebuild()
@export_range(0.0, 1.0) var snow_mask: float = 1.0:
	set(v):
		snow_mask = v
		_rebuild()
@export var emission: float = 0.0:
	set(v):
		emission = v
		_rebuild()
@export var has_collision: bool = true:
	set(v):
		has_collision = v
		_rebuild()
## Can be dithered away when it hides the player from the camera.
@export var fadeable: bool = true
## Blocks/props sharing a fade group (e.g. body, roof and windows of one building) fade together.
@export var fade_group: String = ""
@export var cast_shadows: bool = true:
	set(v):
		cast_shadows = v
		_rebuild()
## Shown on the map (M) when non-empty; also draws the block outline on the map.
@export var map_label: String = ""
@export var show_on_map: bool = false

const FADE_STEPS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]

static var _materials: Array[ShaderMaterial] = []

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _fade_tween: Tween
var _fade: float = 0.0
var _occluding: bool = false
var _cutaway: bool = false


static func shared_material(fade_amount: float = 0.0) -> ShaderMaterial:
	if _materials.is_empty():
		var shader: Shader = load(MATERIAL_PATH)
		var tex := WorldTextures.texture()
		for f in FADE_STEPS:
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter("fade", f)
			m.set_shader_parameter("world_tex", tex)
			m.set_shader_parameter("texels_per_metre", WorldTextures.TEXELS_PER_METRE)
			_materials.append(m)
	var best := 0
	for i in FADE_STEPS.size():
		if absf(FADE_STEPS[i] - fade_amount) < absf(FADE_STEPS[best] - fade_amount):
			best = i
	return _materials[best]


static func clear_materials() -> void:
	_materials.clear()


func _ready() -> void:
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Mesh"
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.name = "Shape"
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	var mat_id := resolve_material()
	var key := "block:%s:%s:%s:%.3f:%.3f:%d" % [shape, size, color.to_html(), snow_mask, emission, mat_id]
	var mesh := MeshBuilder.cached(key)
	if mesh == null:
		var mb := MeshBuilder.new()
		mb.add(_make_mesh(), Transform3D.IDENTITY, color, snow_mask, emission, mat_id)
		mesh = mb.commit()
		MeshBuilder.store(key, mesh)
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = shared_material(_fade)
	_mesh_instance.position = Vector3(0, size.y * 0.5, 0)
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := BoxShape3D.new()
	box.size = size
	_collision.shape = box
	_collision.position = Vector3(0, size.y * 0.5, 0)
	# Non-solid but fadeable geometry (roofs, upper floors) sits on the "occluder" layer (8)
	# so the camera can detect and fade it; nothing physically collides with that layer.
	_collision.disabled = not has_collision and not fadeable
	collision_layer = 1 if has_collision else (128 if fadeable else 0)


## Material id, guessing for "auto": roads/pavements/snow for flat outdoor blocks, brick for
## reddish walls, plaster for light ones, concrete otherwise; floors and wallpaper indoors.
func resolve_material() -> int:
	if material != "auto":
		return WorldTextures.id(material)
	var lum := color.get_luminance()
	var outdoor := snow_mask > 0.3
	if shape == "gable":
		return WorldTextures.id("roof")
	if shape == "cylinder":
		return WorldTextures.id("metal" if lum < 0.5 else "concrete")
	if emission > 0.2:
		return WorldTextures.id("glass")
	if size.y <= 0.35:
		if outdoor:
			if lum < 0.3:
				return WorldTextures.id("asphalt")
			return WorldTextures.id("sidewalk" if lum < 0.62 else "snow")
		return WorldTextures.id("parquet" if color.r > color.b + 0.04 else "floor_tiles")
	if not outdoor:
		return WorldTextures.id("wallpaper" if size.y > 1.5 else "planks")
	if color.r > color.g + 0.06 and color.r > color.b + 0.08:
		return WorldTextures.id("brick")
	return WorldTextures.id("plaster" if lum > 0.5 else "concrete")


func _make_mesh() -> PrimitiveMesh:
	match shape:
		"gable":
			var p := PrismMesh.new()
			p.size = size
			return p
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = size.x * 0.5
			c.bottom_radius = size.x * 0.5
			c.height = size.y
			c.radial_segments = 8
			c.rings = 1
			return c
	var b := BoxMesh.new()
	b.size = size
	return b


func set_fade(amount: float) -> void:
	if _mesh_instance == null or Engine.is_editor_hint():
		return
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_fade_now, _fade, amount, 0.25)


func _set_fade_now(v: float) -> void:
	_fade = v
	if _mesh_instance:
		var m := shared_material(v)
		if _mesh_instance.material_override != m:
			_mesh_instance.material_override = m


## Called by the camera occlusion fader.
func set_occluding(value: bool) -> void:
	if not fadeable or value == _occluding:
		return
	_occluding = value
	_update_fade()


## Called by IndoorZone for cut-away roofs / front walls.
func set_cutaway(value: bool) -> void:
	if value == _cutaway:
		return
	_cutaway = value
	_update_fade()


func _update_fade() -> void:
	# Occluders dissolve completely (the steps give a short dissolve animation); a half
	# dither left big noisy areas over the player.
	if _cutaway or _occluding:
		set_fade(1.0)
	else:
		set_fade(0.0)


## Map outline in world XZ (used by the map UI).
func get_map_rect() -> Rect2:
	return Rect2(position.x - size.x * 0.5, position.z - size.z * 0.5, size.x, size.z)
