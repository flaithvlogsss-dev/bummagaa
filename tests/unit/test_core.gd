extends TestCase
## Conditions / consequences / flags / time.


func before_each() -> void:
	fresh_game()


func test_flags_and_conditions() -> void:
	assert_false(Conditions.check({"flag": "radio_found"}))
	GameState.set_flag("radio_found")
	assert_true(Conditions.check({"flag": "radio_found"}))
	assert_true(Conditions.check_all([{"flag": "radio_found"}, {"not_flag": "helped_mara"}]))
	assert_true(Conditions.check({"any": [{"flag": "nope"}, {"flag": "radio_found"}]}))
	assert_false(Conditions.check({"not": {"flag": "radio_found"}}))


func test_unknown_condition_is_false_not_crash() -> void:
	assert_false(Conditions.check({"no_such_condition_key": 1}))


func test_unknown_flag_default() -> void:
	assert_eq(GameState.get_flag("never_set_flag"), false)


func test_consequences_apply() -> void:
	Consequences.apply_all([{"set_flag": ["helped_survivor", true]}, {"decision": ["mara_help", "medicine"]}])
	assert_true(GameState.has_flag("helped_survivor"))
	assert_eq(GameState.get_decision("mara_help"), "medicine")
	Consequences.apply({"if": {"flag": "nope"}, "set_flag": "guarded"})
	assert_false(GameState.has_flag("guarded"))


func test_time_day_changes_at_seven() -> void:
	var days := []
	TimeManager.day_changed.connect(func(d): days.append(d))
	TimeManager.set_time(1, 23, 50)
	TimeManager.advance_minutes(20)
	assert_eq(TimeManager.current_day, 1, "night stays on day 1")
	assert_true(TimeManager.is_night())
	TimeManager.skip_to_hour(7)
	assert_eq(TimeManager.current_day, 2)
	assert_eq(TimeManager.current_hour, 7)
	assert_eq(days, [2])


func test_world_state_serialization() -> void:
	GameState.world.set_value("snow_level", 0.5)
	GameState.world.set_route("north_road", false)
	var d := GameState.world.serialize()
	var w := WorldState.new()
	w.deserialize(d)
	assert_eq(w.get_snow_level(), 0.5)
	assert_false(w.is_route_open("north_road"))
