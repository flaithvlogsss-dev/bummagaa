extends Node3D
## Developer tool: lays out every LowPolyProp kind in a grid under daylight and saves a PNG.
## Env: SHOT_OUT (png path), GALLERY_KINDS (comma list, default all), GALLERY_COLS (default 8)
## Usage: xvfb-run godot --path . --rendering-method gl_compatibility res://tools/PropGallery.tscn

func _ready() -> void:
	var kinds: Array = LowPolyProp.KINDS.duplicate()
	var only := OS.get_environment("GALLERY_KINDS")
	if not only.is_empty():
		kinds = Array(only.split(","))
	var cols := int(OS.get_environment("GALLERY_COLS")) if not OS.get_environment("GALLERY_COLS").is_empty() else 8
	var spacing := 12.0
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.6, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.65)
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	var ground := LowPolyBlock.new()
	var rows := int(ceil(kinds.size() / float(cols)))
	ground.size = Vector3(cols * spacing + 10, 0.2, rows * spacing + 10)
	ground.color = Color(0.5, 0.5, 0.52)
	ground.material = "sidewalk"
	ground.position = Vector3((cols - 1) * spacing * 0.5, -0.2, (rows - 1) * spacing * 0.5)
	add_child(ground)
	RenderingServer.global_shader_parameter_set("snow_amount", 0.25)
	for i in kinds.size():
		var p := LowPolyProp.new()
		p.kind = kinds[i]
		p.lit = true
		p.position = Vector3((i % cols) * spacing, 0, (i / cols) * spacing)
		if kinds[i] in ["wires", "string_lights"]:
			p.position.y = -4.0 if kinds[i] == "wires" else 0.0
		add_child(p)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(cols, rows) * spacing * 0.8
	cam.far = 400.0
	add_child(cam)
	var center := Vector3((cols - 1) * spacing * 0.5, 1.5, (rows - 1) * spacing * 0.5)
	cam.position = center + Vector3(-45, 62, 78)
	cam.look_at(center)
	cam.make_current()
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	print("saved ", kinds.size(), " props")
	get_tree().quit()
