extends Node
## Acceptance test — plays the vertical slice through the real Main scene (checklist §70):
## intro → street → Mara → radio point → squall + Snow Stalker → combat → shelter → crafting →
## upgrade → save/load → sleep → new day → ending → death screen → load.
## Usage: godot --headless --path . res://tests/acceptance/AcceptanceTest.tscn

var failures: PackedStringArray = PackedStringArray()
var steps: int = 0
var main: Main
var player: Player


func _ready() -> void:
	SaveManager.save_dir = "user://acceptance_saves"
	for slot in SaveManager.SLOTS:
		SaveManager.delete_slot(slot)
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	await _run()
	for slot in SaveManager.SLOTS:
		SaveManager.delete_slot(slot)
	print("\n==== ACCEPTANCE: %d steps, %d failed ====" % [steps, failures.size()])
	for f in failures:
		print("  FAIL ", f)
	AudioManager.shutdown()
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit(failures.size())


func check(cond: bool, what: String) -> void:
	steps += 1
	if cond:
		print("  OK   ", what)
	else:
		print("  FAIL ", what)
		failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _node(path: String) -> Node:
	return main.current_level.get_node_or_null(path) if main.current_level else null


func _use(path: String) -> void:
	var n := _node(path) as Interactable
	check(n != null and n.is_available(), "interactable %s available" % path)
	if n:
		n._last_used = -1000.0
		n.interact(player)
	await _frames(2)
	# Containers open the looting panel: take everything, like pressing E there.
	var panel := UIRoot.instance.current as ContainerPanel if UIRoot.instance else null
	if panel and panel.open_data.has("inventory"):
		panel._take_all()
		UIRoot.close_all()
		await _frames(2)


## Finishes the active dialogue, choosing the first choice containing `pick` when given.
func _finish_dialogue(picks: Array = []) -> void:
	var guard := 0
	var lines: Array = []
	var cb := func(l): lines.append(l)
	DialogueManager.line_shown.connect(cb)
	if DialogueManager.is_active() and DialogueManager._node.size() > 0:
		lines.append({"choices": _current_choices()})
	while DialogueManager.is_active() and guard < 40:
		guard += 1
		var choices: Array = _current_choices()
		if choices.is_empty():
			DialogueManager.advance()
		else:
			var chosen := -1
			for pick in picks:
				for i in choices.size():
					if choices[i].enabled and str(choices[i].text).contains(pick):
						chosen = i
						break
				if chosen >= 0:
					break
			if chosen < 0:
				chosen = choices.size() - 1
			DialogueManager.choose(chosen)
		await _frames(1)
	DialogueManager.line_shown.disconnect(cb)
	await _frames(2)


func _current_choices() -> Array:
	var out: Array = []
	for c in DialogueManager._choices:
		out.append({"text": str(c.data.get("text", "")), "enabled": c.enabled})
	return out


func _teleport(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	main.camera_rig.snap()
	await _frames(4)


func _run() -> void:
	# 1-2. Start the game, new save.
	await main.new_game()
	player = main.player
	await _frames(5)
	check(main.current_level_id == "shelter", "new game starts in the shelter")
	check(not get_tree().paused, "world not paused after start")
	# Intro: phone → window → blackout.
	await _use("Interactables/Phone")
	check(DialogueManager.is_active(), "phone starts a dialogue")
	await _finish_dialogue()
	check(GameState.has_flag("phone_answered"), "phone answered")
	check(QuestManager.is_active("q02_medicine"), "medicine quest started from voicemail")
	await _use("Interactables/WindowIntro")
	await _finish_dialogue()
	check(GameState.has_flag("intro_done") and GameState.has_flag("power_cut"), "window → blackout → intro done")
	check(TimeManager.running, "clock runs after intro")
	check(QuestManager.is_active("main_first_night"), "THE FIRST NIGHT started")
	# 6. Find items. 7-8. Inventory use.
	await _use("Interactables/Kitchen")
	await _use("Interactables/FirstAid")
	await _use("Interactables/Flashlight")
	check(GameState.inventory.has_item("flashlight") and GameState.inventory.has_item("canned_food"), "found flashlight and food")
	GameState.stats.set_value("hunger", 40)
	check(GameState.inventory.consume("canned_food") and GameState.stats.hunger > 60.0, "used food from the inventory")
	UIRoot.open_panel("inventory")
	await _frames(2)
	check(get_tree().paused and UIRoot.instance.current is InventoryPanel, "inventory panel opens and pauses")
	UIRoot.close_all()
	await _frames(2)
	await _use("Interactables/Generator")
	await _finish_dialogue()
	check(GameState.has_flag("generator_checked"), "generator checked")
	await _use("Interactables/RadioBasic")
	check(UIRoot.instance.current is RadioPanel, "radio panel opened")
	await _wait(3.2)
	UIRoot.close_all()
	await _frames(3)
	check(GameState.has_flag("shelter_radio_on") and GameState.has_information("radio_warning"), "radio broadcast heard and saved as Information")
	check(QuestManager.is_completed("main_first_night"), "THE FIRST NIGHT completed")
	check(QuestManager.is_active("q03_signal"), "Signal quest started")

	# 3-4. Leave the shelter, explore.
	await _use("Interactables/Exit")
	await _wait(1.2)
	await _frames(5)
	check(main.current_level_id == "district", "left the shelter into the district")
	await _frames(10)
	if DialogueManager.is_active():
		await _finish_dialogue()
	check(GameState.has_flag("seen:first_outside"), "first outside narration")
	# 9. Cold.
	var t0 := GameState.stats.temperature
	await _wait(1.5)
	check(GameState.stats.temperature < t0, "body cools outdoors")
	# 11-13. Meet Mara, choose, relationship.
	await _teleport(Vector3(0.5, 0.1, -18.5))
	var mara := main.current_level.get_node_or_null("Actors/NPC_mara")
	check(mara != null, "Mara spawned on the narrow street")
	if mara:
		mara.talk(player)
		await _frames(2)
		await _finish_dialogue(["лекарство", "бинтом"])
	check(GameState.get_decision("mara_help") in ["medicine", "bandage"], "moral choice recorded (%s)" % GameState.get_decision("mara_help"))
	check(GameState.relationships.get_value("mara", "trust") > 5.0, "Mara's trust changed")
	# 10. Warm up at the fire.
	GameState.stats.set_value("temperature", 30)
	await _teleport(Vector3(0, 0.1, -42.2))
	await _wait(1.5)
	check(GameState.has_flag("found_heat_source"), "found the burning barrel")
	check(GameState.stats.temperature > 32.0, "warming near the fire")
	# 18. Radio point + tuning mini-game.
	await _teleport(Vector3(12, 0.1, -50.0))
	await _use("Interactables/RadioPoint")
	var radio := UIRoot.instance.current as RadioPanel
	check(radio != null, "radio point opens the scanner")
	if radio:
		radio._slider.value = 102.5
		await _wait(2.0)
	UIRoot.close_all()
	await _frames(3)
	check(RadioManager.is_found("rs_evac"), "locked a signal by tuning")
	check(QuestManager.is_active("q03_signal") and QuestManager.is_objective_done("q03_signal", "tune"), "Signal quest advanced")
	# 19-20. The squall and the first threat.
	TimeManager.advance_minutes(4)
	await _frames(3)
	check(WeatherManager.get_state() == "BLIZZARD", "first squall began")
	TimeManager.advance_minutes(4)
	await _frames(5)
	var enemies := get_tree().get_nodes_in_group("enemy")
	check(enemies.size() >= 1, "Snow Stalker appeared")
	# 21. Weapon.
	await _teleport(Vector3(-10.3, 0.1, 3.4))
	await _use("Interactables/CarInterior")
	check(GameState.inventory.has_item("pistol"), "found the pistol")
	GameState.inventory.equip("pistol")
	player.combat.reload()
	await _wait(1.8)
	check(player.combat.get_magazine() > 0, "reloaded the pistol")
	if not enemies.is_empty() and is_instance_valid(enemies[0]):
		var st: SnowStalker = enemies[0]
		var hp := st.health
		await _teleport(st.global_position + Vector3(0, 0, 4))
		var to := st.global_position - player.global_position
		player.combat.aim_direction = Vector2(to.x, to.z).normalized()
		player.combat.fire()
		await _frames(3)
		check(not is_instance_valid(st) or st.health < hp or st.state == SnowStalker.State.RETREAT, "shot hit the Stalker (it reacts)")
	# 22. Return home.
	await _teleport(Vector3(-51.5, 0.1, -8.0))
	await _use("Interactables/ShelterDoor")
	await _wait(1.2)
	await _frames(5)
	check(main.current_level_id == "shelter", "returned to the shelter")
	check(QuestManager.is_completed("q03_signal"), "Signal quest completed on return")
	if GameState.get_decision("mara_help") == "medicine":
		check(main.current_level.get_node_or_null("Actors/NPC_mara") != null, "Mara waits inside the shelter")
	# 16-17. Resources → craft.
	for id in ["scrap_metal", "wood", "cloth", "electronics"]:
		GameState.storage.add(id, 4)
	await _use("Interactables/Workbench")
	var craft := UIRoot.instance.current as CraftingPanel
	check(craft != null, "workbench opens crafting")
	if craft:
		craft._list.select(0)
		craft._show()
		await craft._craft()
	UIRoot.close_all()
	await _frames(2)
	check(GameState.has_flag("crafted_any"), "crafted an item")
	# 23. Upgrade base.
	check(ShelterSystem.upgrade(), "upgraded the shelter to level 2")
	await _frames(3)
	check(CraftingSystem.craft(Data.get_recipe("repair_kit")), "crafted a repair kit in the workshop")
	await _use("Interactables/Generator")
	await _finish_dialogue()
	check(GameState.has_flag("generator_repaired"), "generator repaired")
	# 26-28. Save, change, load.
	check(SaveManager.save_to_slot("1"), "saved to slot 1")
	var wood_before := GameState.inventory.count("wood")
	GameState.inventory.remove("wood", wood_before)
	GameState.set_flag("after_save_flag")
	await main.load_slot("1")
	await _wait(1.0)
	await _frames(5)
	check(GameState.inventory.count("wood") == wood_before, "load restored the inventory")
	check(not GameState.has_flag("after_save_flag"), "load restored the flags")
	check(GameState.has_flag("generator_repaired") and GameState.shelter_level == 2, "load restored shelter state")
	check(main.current_level_id == "shelter", "load restored the location")
	# 24. Sleep → new day.
	TimeManager.set_time(TimeManager.current_day, 23, 0)
	await _use("Interactables/Bed")
	await _wait(3.0)
	for i in 3:
		if DialogueManager.is_active():
			await _finish_dialogue(["Открыть"])
	await _frames(5)
	check(TimeManager.current_day == 2 and TimeManager.current_hour == 7, "slept until day 2, 07:00")
	check(SaveManager.has_save("auto"), "morning autosave written")
	check(QuestManager.is_active("q04_tracks"), "day 2 starts the Tracks quest")
	# 25. Reach an ending on the morning of day 4.
	TimeManager.set_time(3, 23, 30)
	await _use("Interactables/Bed")
	await _wait(3.0)
	for i in 3:
		if DialogueManager.is_active():
			await _finish_dialogue()
	await _wait(2.5)
	check(main.mode == Main.Mode.ENDING, "prototype ending reached (%s)" % GameState.ending_id)
	check(UIRoot.instance.current is EndingScreen, "ending screen shown")
	# Death → THE NIGHT CONTINUES → load last save.
	await main.load_slot("1")
	await _wait(1.0)
	GameState.stats.set_value("health", 0)
	await _wait(1.8)
	check(main.mode == Main.Mode.DEAD and UIRoot.instance.current is DeathScreen, "death shows THE NIGHT CONTINUES")
	await main.load_slot(SaveManager.latest_slot())
	await _wait(1.0)
	check(main.mode == Main.Mode.PLAYING and GameState.stats.health > 0.0, "continued from the last save after death")
