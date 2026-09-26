class_name CameraRig
extends Node3D
## CameraRig — three-quarter follow camera.
##
## Purpose: smooth follow with look-ahead, soft zoom-out outdoors/while sprinting, map-bound
##   clamping, a SpringArm3D so it never passes through camera-blocking walls, dithered fading
##   of buildings that hide the player, and trauma-based screen shake.
##   All tunables come from a CameraSettings resource (data/config/camera_settings.tres).
## Dependencies: CameraSettings, Settings (screen shake toggle).
## Public API: set_target(node), snap(), set_bounds(rect), set_interior(bool), add_trauma(x),
##   apply_settings()

@export var settings: CameraSettings

var target: Node3D
var bounds: Rect2 = Rect2(-1000, -1000, 2000, 2000)
var interior: bool = false

var _trauma: float = 0.0
var _zoom: float = 1.0
var _occluders: Dictionary = {}
var _occlusion_t: float = 0.0
var _noise_t: float = 0.0

@onready var yaw_pivot: Node3D = $Yaw
@onready var pitch_pivot: Node3D = $Yaw/Pitch
@onready var arm: SpringArm3D = $Yaw/Pitch/Arm
@onready var camera: Camera3D = $Yaw/Pitch/Arm/Camera
@onready var listener: AudioListener3D = $Yaw/Listener


func _ready() -> void:
	if settings == null:
		settings = CameraSettings.new()
	apply_settings()
	camera.make_current()
	listener.make_current()
	GameState.presentation_requested.connect(_on_presentation)


func apply_settings() -> void:
	yaw_pivot.rotation_degrees.y = settings.yaw_degrees
	pitch_pivot.rotation_degrees.x = settings.pitch_degrees
	camera.fov = settings.fov
	arm.spring_length = _desired_distance()
	arm.margin = settings.collision_margin
	arm.collision_mask = 64


func set_target(node: Node3D) -> void:
	target = node


func set_bounds(rect: Rect2) -> void:
	bounds = rect


func set_interior(value: bool) -> void:
	interior = value
	_clear_occluders()


func snap() -> void:
	if target:
		global_position = _clamped(target.global_position)
		arm.spring_length = _desired_distance()


func add_trauma(amount: float) -> void:
	if Settings.screen_shake:
		_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _desired_distance() -> float:
	if interior:
		return settings.interior_distance
	var d := settings.distance + settings.outdoor_extra_distance * 0.5
	if target and target.get("is_sprinting"):
		d += settings.sprint_extra_distance
	return d * clampf(_zoom, settings.min_zoom, settings.max_zoom)


func _clamped(p: Vector3) -> Vector3:
	var margin := 6.0
	p.x = clampf(p.x, bounds.position.x + margin, bounds.end.x - margin)
	p.z = clampf(p.z, bounds.position.y + margin, bounds.end.y - margin)
	p.y = 0.0
	return p


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var goal := target.global_position
	var vel = target.get("velocity")
	if vel is Vector3:
		goal += Vector3(vel.x, 0, vel.z) * settings.look_ahead * 0.25
	goal = _clamped(goal)
	var k := 1.0 - exp(-settings.follow_smoothing * delta)
	global_position = global_position.lerp(goal, k)
	arm.spring_length = lerpf(arm.spring_length, _desired_distance(), 1.0 - exp(-settings.zoom_smoothing * delta))
	# Shake
	_noise_t += delta * 30.0
	if _trauma > 0.0:
		var s := _trauma * _trauma * settings.shake_max_offset
		camera.h_offset = (sin(_noise_t * 1.3) + sin(_noise_t * 2.9) * 0.5) * s
		camera.v_offset = (cos(_noise_t * 1.7) + sin(_noise_t * 3.3) * 0.5) * s
		_trauma = maxf(0.0, _trauma - settings.shake_decay * delta)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	_occlusion_t -= delta
	if _occlusion_t <= 0.0:
		_occlusion_t = 0.12
		_update_occlusion()


func _update_occlusion() -> void:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var hit_now := {}
	for h in [0.4, 1.4]:
		var to := target.global_position + Vector3(0, h, 0)
		var exclude: Array[RID] = []
		if target is CollisionObject3D:
			exclude.append(target.get_rid())
		for i in 4:
			var q := PhysicsRayQueryParameters3D.create(from, to, 1)
			q.exclude = exclude
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			var col: Object = hit.collider
			if col and col.has_method("set_occluding"):
				var group: String = str(col.get("fade_group"))
				if group.is_empty():
					hit_now[col] = true
				else:
					for n in get_tree().get_nodes_in_group(group):
						hit_now[n] = true
			exclude.append(hit.rid)
	for col in _occluders.keys():
		if not hit_now.has(col) and is_instance_valid(col):
			col.set_occluding(false)
	for col in hit_now.keys():
		if is_instance_valid(col):
			col.set_occluding(true)
	_occluders = hit_now


func _clear_occluders() -> void:
	for col in _occluders.keys():
		if is_instance_valid(col):
			col.set_occluding(false)
	_occluders.clear()


func _on_presentation(kind: String, data: Dictionary) -> void:
	if kind == "shake":
		add_trauma(float(data.get("amount", 0.3)))
