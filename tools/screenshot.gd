extends Node
## Developer tool: boots Main, jumps to a location / time / weather and saves a PNG.
## Env: SHOT_OUT, SHOT_LEVEL, SHOT_SPAWN, SHOT_POS ("x,z"), SHOT_HOUR, SHOT_DAY, SHOT_WEATHER,
##      SHOT_FLASH (1 = flashlight on), SHOT_PANEL (ui panel), SHOT_DIALOGUE ("id" or "id:npc"),
##      SHOT_ENEMY (1 = spawn a Snow Stalker nearby), SHOT_TITLE (1 = title screen only),
##      SHOT_FRAMES, SHOT_ITEMS (1 = give sample items), SHOT_LEVELUP (shelter level),
##      SHOT_LOOT (loot table shown by SHOT_PANEL=container)
## Usage: xvfb-run godot --path . --rendering-method gl_compatibility res://tools/Screenshot.tscn

func _ready() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	if _env("SHOT_TITLE", "0") == "1":
		for i in 30:
			await get_tree().process_frame
		_save()
		return
	await Main.instance.new_game()
	for f in ["intro_done", "phone_answered", "power_cut"]:
		GameState.set_flag(f, true)
	GameState.inventory.add("flashlight")
	if _env("SHOT_ITEMS", "0") == "1":
		UIRoot.instance.panels["debug"]._give_items()
		var inv := GameState.inventory
		inv.equip("warm_jacket")
		inv.equip("pistol")
		inv.use_at(inv.find_index("filter_standard"))
		inv.set_quick(0, "bandage")
		inv.set_quick(1, "empty_bottle")
		inv.set_quick(2, "flare")
		QuestManager.start_quest("main_first_night")
		QuestManager.start_quest("q02_medicine")
	GameState.set_shelter_level(int(_env("SHOT_LEVELUP", "1")))
	TimeManager.set_time(int(_env("SHOT_DAY", "1")), int(_env("SHOT_HOUR", "21")), 0)
	var w := _env("SHOT_WEATHER", "")
	if not w.is_empty():
		WeatherManager.force_weather(w, 120, 0.01)
	await Main.instance.change_level(_env("SHOT_LEVEL", "district"), _env("SHOT_SPAWN", "shelter_door"), false)
	var pos := _env("SHOT_POS", "")
	var pl := Main.get_player()
	if not pos.is_empty():
		var p := pos.split(",")
		pl.global_position = Vector3(float(p[0]), 0.1, float(p[1]))
		Main.instance.camera_rig.snap()
	GameState.stats.flashlight_on = _env("SHOT_FLASH", "0") == "1"
	var face := _env("SHOT_FACE", "")
	if not face.is_empty():
		var fp := face.split(",")
		pl.facing = Vector2(float(fp[0]), float(fp[1]))
	if _env("SHOT_ENEMY", "0") == "1":
		GameState.request_world("stalker_apparition", {})
	for i in int(_env("SHOT_FRAMES", "90")):
		await get_tree().process_frame
	if _env("SHOT_CLOSE_DLG", "0") == "1":
		while DialogueManager.is_active():
			DialogueManager._end()
		for i in 20:
			await get_tree().process_frame
	var dlg := _env("SHOT_DIALOGUE", "")
	if not dlg.is_empty():
		var parts := dlg.split(":")
		DialogueManager.start(parts[0], {"npc": parts[1]} if parts.size() > 1 else {})
		for i in 150:
			await get_tree().process_frame
	var panel := _env("SHOT_PANEL", "")
	if not panel.is_empty():
		while DialogueManager.is_active():
			DialogueManager._end()
		await get_tree().process_frame
		if panel == "journal" or panel == "map":
			for id in ["note_evac", "radio_evac", "voicemail_elias"]:
				GameState.add_information(id)
			for id in ["square", "radio_point", "narrow_street", "shelter_street", "alley", "pharmacy", "house", "shop", "main_street", "car"]:
				GameState.discover_location(id)
			GameState.npcs.set_value("mara", "met", true)
			GameState.npcs.set_value("vera", "met", true)
			GameState.add_marker("danger", Vector2(-38, 30), "")
			GameState.add_marker("resource", Vector2(-10, 2), "")
		var pdata := {"station": _env("SHOT_STATION", "radio_point"), "ending": "home"}
		if panel == "container":
			var box := Inventory.new("shot", false)
			box.deserialize({"slots": LootTables.roll(_env("SHOT_LOOT", "military_crate"), "shot", 3) + LootTables.roll("pharmacy_backroom", "shot", 1)})
			pdata = {"title": "Армейский ящик", "inventory": box, "hint": "Крышка сорвана, но внутри кое-что осталось."}
		UIRoot.open_panel(panel, pdata)
		for i in 20:
			await get_tree().process_frame
		if panel == "radio":
			var r := UIRoot.instance.current as RadioPanel
			if r:
				r._slider.value = 102.3
			for i in 60:
				await get_tree().process_frame
	_save()


func _save() -> void:
	var pl := Main.get_player()
	if pl:
		print("player at ", pl.global_position, " level ", Main.instance.current_level_id, " paused ", get_tree().paused)
	var img := get_viewport().get_texture().get_image()
	img.save_png(_env("SHOT_OUT", "user://shot.png"))
	print("saved ", _env("SHOT_OUT", "user://shot.png"))
	AudioManager.shutdown()
	await get_tree().process_frame
	get_tree().quit()


func _env(k: String, d: String) -> String:
	var v := OS.get_environment(k)
	return d if v.is_empty() else v
