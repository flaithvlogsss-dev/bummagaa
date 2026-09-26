extends Node
## Developer tool: boots Main, jumps to a location/time/weather and saves a PNG.
## Env: SHOT_OUT, SHOT_LEVEL, SHOT_SPAWN, SHOT_HOUR, SHOT_DAY, SHOT_WEATHER, SHOT_PANEL, SHOT_FRAMES, SHOT_POS ("x,z")
## Usage: xvfb-run godot --path . --rendering-method gl_compatibility res://tools/Screenshot.tscn

func _ready() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await Main.instance.new_game()
	GameState.set_flag("intro_done", true)
	GameState.set_flag("phone_answered", true)
	GameState.set_flag("power_cut", true)
	TimeManager.set_time(int(_env("SHOT_DAY", "1")), int(_env("SHOT_HOUR", "21")), 0)
	var w := _env("SHOT_WEATHER", "")
	if not w.is_empty():
		WeatherManager.force_weather(w, 120, 0.01)
	await Main.instance.change_level(_env("SHOT_LEVEL", "district"), _env("SHOT_SPAWN", "shelter_door"), false)
	var pos := _env("SHOT_POS", "")
	if not pos.is_empty():
		var p := pos.split(",")
		Main.get_player().global_position = Vector3(float(p[0]), 0.1, float(p[1]))
		Main.instance.camera_rig.snap()
	GameState.stats.flashlight_on = _env("SHOT_FLASH", "0") == "1"
	GameState.inventory.add("flashlight")
	var panel := _env("SHOT_PANEL", "")
	for i in int(_env("SHOT_FRAMES", "90")):
		await get_tree().process_frame
	if not panel.is_empty():
		UIRoot.open_panel(panel, {"station": "radio_point"})
		for i in 10:
			await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(_env("SHOT_OUT", "user://shot.png"))
	print("saved ", _env("SHOT_OUT", "user://shot.png"))
	get_tree().quit()


func _env(k: String, d: String) -> String:
	var v := OS.get_environment(k)
	return d if v.is_empty() else v
