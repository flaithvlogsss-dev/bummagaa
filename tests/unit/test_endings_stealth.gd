extends TestCase
## Endings reachable through their action dialogues; stealth rules; Snow Stalker FSM.

var _ending: String = ""


func before_each() -> void:
	fresh_game()
	QuestManager.reset()
	EventManager.reset()
	WeatherManager.reset()
	_ending = ""
	if not GameState.ending_requested.is_connected(_on_ending):
		GameState.ending_requested.connect(_on_ending)


func after_each() -> void:
	if GameState.ending_requested.is_connected(_on_ending):
		GameState.ending_requested.disconnect(_on_ending)


func _on_ending(id: String) -> void:
	_ending = id


func _run_dialogue(id: String, pick: String) -> Array:
	var texts: Array = []
	var cb := func(l):
		texts.append(l.text)
	DialogueManager.line_shown.connect(cb)
	DialogueManager.start(id)
	var guard := 0
	while DialogueManager.is_active() and guard < 20:
		guard += 1
		var chosen := -1
		for i in DialogueManager._choices.size():
			var c: Dictionary = DialogueManager._choices[i]
			if c.enabled and str(c.data.get("text", "")).contains(pick):
				chosen = i
		if DialogueManager._choices.is_empty():
			DialogueManager.advance()
		elif chosen >= 0:
			DialogueManager.choose(chosen)
		else:
			DialogueManager.choose(DialogueManager._choices.size() - 1)
	DialogueManager.line_shown.disconnect(cb)
	return texts


func test_signal_ending_needs_hidden_conditions() -> void:
	GameState.set_shelter_level(3)
	_run_dialogue("transmitter", "Выйти в эфир")
	assert_eq(_ending, "", "no power → no ending")
	GameState.set_flag("generator_repaired")
	GameState.add_information("radio_depot")
	_run_dialogue("transmitter", "Выйти в эфир")
	assert_eq(_ending, "", "no protocol → no ending")
	GameState.set_flag("vera_protocol")
	_run_dialogue("transmitter", "Выйти в эфир")
	assert_eq(_ending, "signal")


func test_departure_ending_needs_route_gear_food_and_guide() -> void:
	TimeManager.set_time(3, 10, 0)
	WeatherManager.force_weather("LIGHT", 60, 0.01)
	_run_dialogue("north_road", "Уходим")
	assert_eq(_ending, "", "unknown route")
	GameState.set_flag("north_route_known")
	GameState.inventory.add("warm_jacket")
	GameState.storage.add("canned_food", 3)
	_run_dialogue("north_road", "Уходим")
	assert_eq(_ending, "", "no guide yet")
	GameState.npcs.set_location("anton", "shelter")
	WeatherManager.force_weather("BLIZZARD", 60, 0.01)
	_run_dialogue("north_road", "Уходим")
	assert_eq(_ending, "", "blizzard blocks the road")
	WeatherManager.force_weather("LIGHT", 60, 0.01)
	_run_dialogue("north_road", "Уходим")
	assert_eq(_ending, "departure")


func test_home_and_fallback_endings() -> void:
	assert_eq(EndingDirector.evaluate(), "long_winter")
	GameState.set_shelter_level(2)
	GameState.set_flag("generator_repaired")
	GameState.npcs.set_location("mara", "shelter")
	GameState.npcs.set_location("vera", "shelter")
	GameState.storage.add("dry_food", 2)
	assert_eq(EndingDirector.evaluate(), "home")


func test_stealth_visibility_and_noise() -> void:
	var p := Player.new()
	p.set("noise_level", 0.35)
	var walk := Stealth.player_noise_radius(p)
	p.set("noise_level", 0.8)
	assert_gt(Stealth.player_noise_radius(p), walk, "sprinting is louder than walking")
	TimeManager.set_time(1, 23, 0)
	GameState.stats.flashlight_on = false
	var dark := Stealth.player_visibility(p)
	GameState.stats.flashlight_on = true
	assert_gt(Stealth.player_visibility(p), dark, "flashlight makes you visible")
	GameState.stats.flashlight_on = false
	p.hiding_spot = Node3D.new()
	assert_lt(Stealth.player_visibility(p), dark * 0.5, "hiding almost hides you")
	p.hiding_spot.free()
	p.free()


func test_stalker_fsm_reacts_to_noise_and_damage() -> void:
	var world := Node3D.new()
	tree.root.add_child(world)
	var st: SnowStalker = load("res://scenes/enemies/SnowStalker.tscn").instantiate()
	world.add_child(st)
	st.global_position = Vector3(0, 0, 0)
	await tree.physics_frame
	st.hear_noise(Vector3(10, 0, 0), 1.0, "test")
	assert_eq(st.state, SnowStalker.State.INVESTIGATE, "noise → investigate")
	st.take_damage(10.0)
	assert_eq(st.state, SnowStalker.State.CHASE, "hurt → chase")
	st.take_damage(40.0)
	assert_eq(st.state, SnowStalker.State.RETREAT, "badly hurt → retreat")
	st.take_damage(100.0)
	assert_true(GameState.has_flag("stalker_killed"), "can be killed (not required)")
	world.queue_free()
	await tree.process_frame
