class_name BreathEffect
extends CPUParticles3D
## BreathEffect — visible breath in the cold; faster and heavier in a blizzard or when sprinting.

var _t: float = 1.0
var survival: SurvivalSystem


func _ready() -> void:
	emitting = false
	one_shot = true
	amount = 8
	lifetime = 1.3
	explosiveness = 0.7
	local_coords = false
	direction = Vector3(0, 0.3, 1)
	spread = 25.0
	initial_velocity_min = 0.25
	initial_velocity_max = 0.5
	gravity = Vector3(0, 0.25, 0)
	scale_amount_min = 0.6
	scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 1.4))
	scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.45))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	q.material = m
	mesh = q


func update_breath(delta: float, facing: Vector2) -> void:
	if survival == null:
		return
	var cold := not survival.is_indoors() or (not survival.is_heated() and GameState.stats.temperature < 60.0)
	if not cold:
		return
	_t -= delta
	if _t > 0.0:
		return
	var heavy := survival.sprinting or WeatherManager.is_blizzard() or GameState.stats.temperature < 30.0
	_t = randf_range(1.1, 1.5) if heavy else randf_range(2.4, 3.2)
	amount = 12 if heavy else 7
	direction = Vector3(facing.x, 0.35, facing.y)
	restart()
