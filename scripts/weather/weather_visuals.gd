class_name WeatherVisuals
extends Node3D
## WeatherVisuals — snow particles that follow the camera target, driven by WeatherManager.
##
## Purpose: one GPUParticles3D box of snow around the player (cheap and always on screen).
##   Density = snow intensity, slant = wind. Inside interiors the snowfall is hidden.

@export var max_amount: int = 5000
@export var follow_path: NodePath

var _particles: GPUParticles3D
var _material: ParticleProcessMaterial
var _follow: Node3D
var interior: bool = false


func _ready() -> void:
	_follow = get_node_or_null(follow_path)
	_particles = GPUParticles3D.new()
	_particles.amount = max_amount
	_particles.lifetime = 4.0
	_particles.preprocess = 4.0
	_particles.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.local_coords = false
	_material = ParticleProcessMaterial.new()
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(24, 1, 24)
	_material.direction = Vector3(0, -1, 0)
	_material.spread = 8.0
	_material.initial_velocity_min = 2.5
	_material.initial_velocity_max = 4.0
	_material.gravity = Vector3(0, -1.0, 0)
	_material.scale_min = 0.6
	_material.scale_max = 1.4
	_material.turbulence_enabled = true
	_material.turbulence_noise_strength = 0.6
	_material.turbulence_noise_scale = 4.0
	_particles.process_material = _material
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.045)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.92, 0.95, 1.0, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	_particles.draw_pass_1 = q
	_particles.position = Vector3(0, 14, 0)
	add_child(_particles)


func _process(_delta: float) -> void:
	if _follow:
		global_position = Vector3(_follow.global_position.x, 0, _follow.global_position.z)
	var intensity := WeatherManager.intensity
	var wind := WeatherManager.wind
	var ratio := clampf(0.12 + intensity * 0.88, 0.0, 1.0)
	if interior:
		ratio = 0.0
	_particles.amount_ratio = ratio
	_particles.emitting = ratio > 0.01
	var w := WeatherManager.wind_direction * (1.0 + wind * 11.0)
	_material.gravity = Vector3(w.x, -1.5 - intensity, w.y)
	_material.initial_velocity_min = 2.0 + intensity * 2.0
	_material.initial_velocity_max = 3.5 + intensity * 3.0
	_material.emission_box_extents = Vector3(24 + wind * 8.0, 1, 24 + wind * 8.0)
	_particles.position = Vector3(-w.x * 0.8, 14, -w.y * 0.8)
