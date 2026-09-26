class_name Footprints
extends Node3D
## Footprints — pooled prints in the snow that fade over time (faster in a blizzard).
##
## Purpose: one MultiMesh for all prints (cheap). Recent print positions are kept so enemy
##   tracking can use them later (get_recent_positions()).

const MAX_PRINTS := 180
const STEP_DISTANCE := 0.6
const BASE_LIFETIME := 80.0

var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _births: PackedFloat32Array
var _positions: PackedVector3Array
var _index: int = 0
var _last_pos: Vector3 = Vector3.INF
var _side: float = 1.0
var _time: float = 0.0
var _update_t: float = 0.0


func _ready() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.27)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.45, 0.52, 0.66)
	mat.roughness = 1.0
	quad.material = mat
	_mm.mesh = quad
	_mm.instance_count = MAX_PRINTS
	_births.resize(MAX_PRINTS)
	_positions.resize(MAX_PRINTS)
	for i in MAX_PRINTS:
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		_mm.set_instance_color(i, Color(1, 1, 1, 0))
		_births[i] = -1000.0
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _mm
	_mmi.top_level = true
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mmi)
	_mmi.global_transform = Transform3D.IDENTITY


func track(pos: Vector3, facing: Vector2, on_snow: bool) -> void:
	if not on_snow:
		_last_pos = Vector3.INF
		return
	if _last_pos == Vector3.INF:
		_last_pos = pos
		return
	if pos.distance_to(_last_pos) < STEP_DISTANCE:
		return
	_last_pos = pos
	_side = -_side
	var yaw := atan2(facing.x, facing.y)
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var p := pos + right * _side * 0.11
	p.y = 0.05
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
	_mm.set_instance_transform(_index, Transform3D(basis, p))
	_mm.set_instance_color(_index, Color(1, 1, 1, 0.55))
	_births[_index] = _time
	_positions[_index] = p
	_index = (_index + 1) % MAX_PRINTS


func _process(delta: float) -> void:
	_time += delta
	_update_t -= delta
	if _update_t > 0.0:
		return
	_update_t = 0.35
	var lifetime := BASE_LIFETIME / maxf(WeatherManager.footprint_fade, 0.1)
	for i in MAX_PRINTS:
		var age := _time - _births[i]
		if age < 0.0 or age > lifetime + 1.0:
			continue
		var a := clampf(1.0 - age / lifetime, 0.0, 1.0) * 0.55
		_mm.set_instance_color(i, Color(1, 1, 1, a))


func clear() -> void:
	for i in MAX_PRINTS:
		_births[i] = -1000.0
		_mm.set_instance_color(i, Color(1, 1, 1, 0))
	_last_pos = Vector3.INF


func get_recent_positions(max_age: float = 30.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in MAX_PRINTS:
		if _time - _births[i] <= max_age:
			out.append(_positions[i])
	return out
