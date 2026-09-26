extends TestCase
## Unit tests for the core systems required by the prototype checklist.


func before_each() -> void:
	fresh_game()
	QuestManager.reset()
	EventManager.reset()
	RadioManager.reset()
	WeatherManager.reset()


# --- Inventory ------------------------------------------------------------------------------

func test_inventory_add_remove_count() -> void:
	var inv := GameState.inventory
	assert_eq(inv.add("cloth", 3), 3)
	assert_eq(inv.count("cloth"), 3)
	assert_true(inv.has_item("cloth", 3))
	assert_false(inv.remove("cloth", 5), "cannot remove more than owned")
	assert_eq(inv.count("cloth"), 3)
	assert_true(inv.remove("cloth", 2))
	assert_eq(inv.count("cloth"), 1)
	assert_eq(inv.add("no_such_item", 1), 0, "unknown item is rejected without crash")


func test_inventory_consume_and_equip() -> void:
	var inv := GameState.inventory
	GameState.stats.set_value("hunger", 20)
	inv.add("canned_food", 1)
	assert_true(inv.consume("canned_food"))
	assert_eq(inv.count("canned_food"), 0)
	assert_gt(GameState.stats.hunger, 50.0, "eating restores hunger")
	inv.add("warm_jacket", 1)
	assert_true(inv.consume("warm_jacket"), "use on equipment toggles equip")
	assert_true(inv.is_equipped("warm_jacket"))
	assert_gt(inv.get_insulation(), 0.3)
	inv.unequip("body")
	assert_false(inv.is_equipped("warm_jacket"))


func test_inventory_weight_and_serialization() -> void:
	var inv := GameState.inventory
	var added := inv.add("scrap_metal", 30)
	assert_lt(added, 30, "the carry limit stops pickups")
	assert_gt(added, 0)
	assert_false(inv.is_overweight(), "adding never overloads")
	assert_eq(inv.can_fit("scrap_metal", 5), 0)
	assert_true(inv.remove("scrap_metal", added))
	inv.add("pistol", 1, false, {"cond": 40.0})
	inv.equip("pistol")
	inv.add("cloth", 3)
	var data := inv.serialize()
	var other := Inventory.new("copy", true)
	data["slots"].append({"id": "removed_item_from_old_save", "count": 3})
	other.deserialize(data)
	assert_eq(other.count("cloth"), 3)
	assert_true(other.is_equipped("pistol"))
	assert_eq(other.get_equipped_stack("weapon").get("cond"), 40.0, "condition survives saving")
	assert_eq(other.count("removed_item_from_old_save"), 0)
	var legacy := Inventory.new("legacy", true)
	legacy.deserialize({"items": [["cloth", 2], ["pistol", 1]], "equipped": {"hand": "pistol"}})
	assert_eq(legacy.count("cloth"), 2, "v1 saves still load")
	assert_true(legacy.is_equipped("pistol"), "v1 'hand' slot maps to weapon")
	assert_eq(legacy.count("pistol"), 1)


func test_inventory_slots_backpack_and_instances() -> void:
	var inv := GameState.inventory
	assert_eq(inv.get_equipped("backpack"), "small_backpack", "new game starts with a backpack")
	var slots := inv.slot_count()
	assert_eq(slots, Inventory.BASE_SLOTS + 6)
	# Non-stackable gear takes one slot each and keeps its own condition.
	inv.add("knife", 1, false, {"cond": 30.0, "q": 2})
	inv.add("knife", 1, false, {"cond": 90.0})
	assert_eq(inv.count("knife"), 2)
	var conds: Array = []
	for s in inv.get_slots():
		if not s.is_empty() and s.id == "knife":
			conds.append(s.cond)
	conds.sort()
	assert_eq(conds, [30.0, 90.0])
	# Transfer keeps instance data.
	assert_eq(StorageSystem.transfer(inv, GameState.storage, "knife", -1), 2)
	assert_eq(StorageSystem.transfer(GameState.storage, inv, "knife", -1), 2)
	var q_found := false
	for s in inv.get_slots():
		if not s.is_empty() and s.id == "knife" and float(s.cond) == 30.0:
			q_found = int(s.q) == 2
	assert_true(q_found, "quality and condition survive transfers")
	# Filling every slot, then the backpack cannot come off.
	while inv.free_slots() > 0:
		inv.add("stone", 1, true, {"data": {"tag": inv.free_slots()}})
	assert_eq(inv.add("cloth", 1), 0, "no free slot")
	assert_false(inv.unequip("backpack"), "cannot drop the bag while it is full")
	assert_eq(inv.get_equipped("backpack"), "small_backpack")


func test_give_or_drop_spills_to_the_ground() -> void:
	var inv := GameState.inventory
	while inv.free_slots() > 0:
		inv.add("stone", 1, true, {"data": {"tag": inv.free_slots()}})
	var before := GameState.get_dropped(GameState.current_location).size()
	assert_eq(GameState.give_or_drop("canned_food", 2, false), 0)
	var drops := GameState.get_dropped(GameState.current_location)
	assert_eq(drops.size(), before + 1, "overflow lies on the ground")
	assert_eq(drops[-1].stack.id, "canned_food")
	assert_eq(int(drops[-1].stack.count), 2)
	var data := GameState.serialize()
	GameState.deserialize(data)
	assert_eq(GameState.get_dropped(GameState.current_location).size(), before + 1, "drops are saved")


func test_mask_filter_install_and_eject() -> void:
	var inv := GameState.inventory
	inv.add("filter_standard", 2)
	var idx := inv.find_index("filter_standard")
	assert_false(inv.use_at(idx), "no mask yet")
	inv.add("gas_mask", 1)
	assert_true(inv.equip("gas_mask"))
	assert_true(inv.use_at(inv.find_index("filter_standard")))
	assert_eq(inv.count("filter_standard"), 1)
	assert_eq(inv.get_mask_filter_left(), 60.0)
	inv.get_equipped_stack("mask").data["filter_left"] = 20.0
	assert_true(inv.use_at(inv.find_index("filter_standard")), "swap filters")
	assert_eq(inv.get_mask_filter_left(), 60.0)
	var used := {}
	for s in inv.get_slots():
		if not s.is_empty() and s.id == "filter_standard" and s.has("data"):
			used = s
	assert_eq(float(used.get("data", {}).get("left", 0.0)), 20.0, "the old filter keeps its charge")
	inv.get_equipped_stack("mask").data["filter_left"] = 0.0
	inv.eject_filter()
	assert_eq(inv.count("filter_spent"), 1, "an empty filter becomes a spent one")


func test_food_spoils_and_survivors_eat_meals() -> void:
	var inv := GameState.inventory
	inv.add("cooked_meal", 1)
	assert_eq(inv.count("cooked_meal"), 1)
	inv.tick_spoilage(TimeManager.total_minutes + 2 * 1440)
	assert_eq(inv.count("cooked_meal"), 0)
	assert_eq(inv.count("spoiled_food"), 1)
	GameState.storage.add("rice", 3)
	assert_eq(GameState.food_total(), 0, "raw rice and spoiled food are not meals")
	GameState.storage.add("canned_food", 1)
	assert_eq(GameState.food_total(), 1)


func test_loot_tables_roll_deterministically() -> void:
	var a := LootTables.roll("pharmacy_backroom", "district:test", 1)
	var b := LootTables.roll("pharmacy_backroom", "district:test", 1)
	assert_eq(a, b, "same container, same contents")
	assert_gt(a.size(), 0)
	for s in a:
		assert_true(Data.has_item(str(s.id)))
	assert_eq(LootTables.roll("no_such_table", "x", 1), [])
	var gear := LootTables.roll("military_crate", "district:crate", 3)
	for s in gear:
		var item := Data.get_item(str(s.id))
		if item.has_condition:
			assert_true(s.has("cond") and s.has("q"), "gear rolls condition and quality")


func test_storage_transfer() -> void:
	GameState.inventory.add("wood", 4)
	assert_eq(StorageSystem.transfer(GameState.inventory, GameState.storage, "wood", 3), 3)
	assert_eq(GameState.storage.count("wood"), 3)
	assert_eq(StorageSystem.transfer(GameState.storage, GameState.inventory, "wood", -1), 3)
	assert_eq(GameState.inventory.count("wood"), 4)


# --- Crafting -----------------------------------------------------------------------------------

func test_crafting_validation() -> void:
	var r := Data.get_recipe("bandage")
	assert_false(CraftingSystem.can_craft(r))
	assert_eq(CraftingSystem.missing(r), {"cloth": 2})
	GameState.inventory.add("cloth", 1)
	GameState.storage.add("cloth", 1)
	assert_true(CraftingSystem.can_craft(r), "backpack + storage together")
	assert_true(CraftingSystem.craft(r))
	assert_eq(GameState.inventory.count("bandage"), 1)
	assert_eq(CraftingSystem.available_count("cloth"), 0)


func test_crafting_station_level_gate() -> void:
	var r := Data.get_recipe("repair_kit")
	GameState.inventory.add("scrap_metal", 2)
	GameState.inventory.add("electronics", 1)
	assert_false(CraftingSystem.can_craft(r), "needs workshop (level 2)")
	assert_false(CraftingSystem.lock_reason(r).is_empty())
	GameState.set_shelter_level(2)
	assert_true(CraftingSystem.craft(r))
	assert_eq(GameState.inventory.count("repair_kit"), 1)


func test_shelter_upgrade() -> void:
	assert_false(ShelterSystem.can_upgrade())
	GameState.inventory.add("scrap_metal", 3)
	GameState.inventory.add("wood", 3)
	GameState.inventory.add("cloth", 1)
	assert_true(ShelterSystem.upgrade())
	assert_eq(GameState.shelter_level, 2)
	GameState.inventory.add("electronics", 3)
	GameState.inventory.add("scrap_metal", 2)
	assert_false(ShelterSystem.can_upgrade(), "radio station needs schematic + generator")
	GameState.set_flag("radio_schematic")
	GameState.set_flag("generator_repaired")
	assert_true(ShelterSystem.upgrade())
	assert_eq(GameState.shelter_level, 3)


# --- Survival ------------------------------------------------------------------------------------

func _survival_with_level(level: Level) -> SurvivalSystem:
	var s := SurvivalSystem.new()
	s.set_level(level)
	return s


func test_survival_cold_outside_and_warm_inside() -> void:
	var outside := Level.new()
	outside.is_interior = false
	var s := _survival_with_level(outside)
	WeatherManager.force_weather("LIGHT", 60, 0.01)
	WeatherManager._blend = 1.0
	WeatherManager._apply_blend()
	GameState.stats.set_value("temperature", 80)
	for i in 50:
		s.tick(0.2)
	var after_light := GameState.stats.temperature
	assert_lt(after_light, 80.0, "outside cools the body")
	GameState.stats.set_value("temperature", 80)
	WeatherManager.force_weather("BLIZZARD", 60, 0.01)
	WeatherManager._blend = 1.0
	WeatherManager._apply_blend()
	for i in 50:
		s.tick(0.2)
	assert_lt(GameState.stats.temperature, after_light, "blizzard cools faster than light snow")
	GameState.stats.set_value("temperature", 80)
	GameState.inventory.add("warm_jacket")
	GameState.inventory.equip("warm_jacket")
	for i in 50:
		s.tick(0.2)
	assert_gt(GameState.stats.temperature, after_light - 20.0, "jacket slows heat loss")
	var inside := Level.new()
	inside.is_interior = true
	inside.heated_conditions = [{"flag": "stove_lit"}]
	GameState.set_flag("stove_lit")
	s.set_level(inside)
	GameState.stats.set_value("temperature", 20)
	for i in 50:
		s.tick(0.2)
	assert_gt(GameState.stats.temperature, 25.0, "heated interior warms the body")
	s.free()
	outside.free()
	inside.free()


func test_survival_critical_states_hurt_slowly() -> void:
	var outside := Level.new()
	var s := _survival_with_level(outside)
	GameState.stats.set_value("temperature", 0)
	GameState.stats.set_value("health", 100)
	WeatherManager.force_weather("BLIZZARD", 60, 0.01)
	for i in 5:
		s.tick(1.0)
	assert_lt(GameState.stats.health, 100.0, "hypothermia hurts")
	assert_gt(GameState.stats.health, 90.0, "but not instantly")
	s.free()
	outside.free()


func test_item_use_effects_bandage_stops_bleeding() -> void:
	GameState.stats.bleeding = 30.0
	GameState.stats.set_value("health", 50)
	GameState.inventory.add("bandage")
	assert_true(GameState.inventory.consume("bandage"))
	assert_eq(GameState.stats.bleeding, 0.0)
	assert_gt(GameState.stats.health, 60.0)


# --- Relationships ---------------------------------------------------------------------------------

func test_relationship_changes_and_tiers() -> void:
	var r := GameState.relationships
	assert_eq(r.get_tier("mara"), "neutral")
	Consequences.apply({"relationship": {"npc": "mara", "trust": 30, "affinity": 20}})
	assert_eq(r.get_value("mara", "trust"), 30.0)
	assert_true(RelationshipSystem.tier_rank(r.get_tier("mara")) >= RelationshipSystem.tier_rank("cooperative"))
	r.change("mara", "trust", 500)
	assert_eq(r.get_value("mara", "trust"), 100.0, "clamped to 100")
	r.change("anton", "trust", -200)
	assert_eq(r.get_tier("anton"), "distrustful")
	assert_true(Conditions.check({"tier_min": ["mara", "trusted"]}))


func test_npc_memory_flags() -> void:
	Consequences.apply({"memory": ["mara", "player_saved_me", true]})
	assert_true(Conditions.check({"memory": ["mara", "player_saved_me", true]}))
	assert_false(Conditions.check({"memory": ["mara", "player_lied_to_me", true]}))


# --- Dialogue ---------------------------------------------------------------------------------------

func test_dialogue_mara_choice_changes_world() -> void:
	GameState.inventory.add("medicine")
	var lines: Array = []
	var cb := func(l): lines.append(l)
	DialogueManager.line_shown.connect(cb)
	DialogueManager.start("mara", {"npc": "mara"})
	assert_true(DialogueManager.is_active())
	var first: Dictionary = lines[-1]
	var idx := -1
	for i in first.choices.size():
		if str(first.choices[i].text).contains("лекарство"):
			idx = i
	assert_true(idx >= 0, "medicine choice visible")
	DialogueManager.choose(idx)
	DialogueManager.advance()
	assert_false(DialogueManager.is_active())
	DialogueManager.line_shown.disconnect(cb)
	assert_eq(GameState.npcs.get_location("mara"), "shelter")
	assert_eq(GameState.get_decision("mara_help"), "medicine")
	assert_eq(GameState.inventory.count("medicine"), 0)
	assert_gt(GameState.relationships.get_value("mara", "trust"), 20.0)


func test_dialogue_disabled_choice_without_item() -> void:
	var lines: Array = []
	var cb := func(l): lines.append(l)
	DialogueManager.line_shown.connect(cb)
	DialogueManager.start("mara", {"npc": "mara"})
	var enabled_count := 0
	for c in lines[-1].choices:
		if c.enabled:
			enabled_count += 1
	assert_eq(enabled_count, 2, "only 'who are you' and 'leave' are possible without supplies")
	while DialogueManager.is_active():
		DialogueManager._end()
	DialogueManager.line_shown.disconnect(cb)


# --- Quests --------------------------------------------------------------------------------------------

func test_quest_completion_first_night() -> void:
	QuestManager.start_quest("main_first_night")
	assert_true(QuestManager.is_active("main_first_night"))
	GameState.inventory.add("flashlight")
	GameState.inventory.add("canned_food")
	GameState.set_flag("generator_checked")
	QuestManager.evaluate()
	assert_true(QuestManager.is_active("main_first_night"))
	GameState.set_flag("shelter_radio_on")
	QuestManager.evaluate()
	assert_true(QuestManager.is_completed("main_first_night"))
	assert_true(QuestManager.is_active("q03_signal"), "completion starts the next quests")
	assert_true(GameState.has_flag("first_night_prepared"))


func test_quest_objectives_latch() -> void:
	QuestManager.start_quest("q02_medicine")
	GameState.inventory.add("medicine")
	QuestManager.evaluate()
	GameState.inventory.remove("medicine")
	QuestManager.evaluate()
	assert_true(QuestManager.is_objective_done("q02_medicine", "medicine"), "objective stays done")


# --- Radio / weather / time / events ------------------------------------------------------------------

func test_radio_probe_and_lock() -> void:
	var far := RadioManager.probe(100.0, "radio_point")
	var near := RadioManager.probe(102.5, "radio_point")
	assert_lt(float(far.clarity), 0.1)
	assert_gt(float(near.clarity), 0.95)
	assert_eq(near.id, "rs_evac")
	assert_true(RadioManager.lock("rs_evac"))
	assert_false(RadioManager.lock("rs_evac"), "locking twice does nothing")
	assert_true(GameState.has_information("radio_evac"))
	assert_true(GameState.has_flag("radio_point_signal_found"))
	assert_true(EventManager.is_scheduled("first_squall"), "finding the signal schedules the squall")


func test_weather_force_and_schedule() -> void:
	TimeManager.set_time(3, 14, 0)
	assert_eq(WeatherManager.scheduled_state(), "BLIZZARD")
	TimeManager.set_time(2, 9, 0)
	assert_eq(WeatherManager.scheduled_state(), "LIGHT")
	WeatherManager.force_weather("HEAVY", 30)
	assert_eq(WeatherManager.get_state(), "HEAVY")
	assert_true(Conditions.check({"weather": "HEAVY"}))


func test_scheduled_event_and_consequence_delay() -> void:
	GameState.npcs.set_value("mara", "injured", true)
	EventManager.schedule("first_squall_end", 30)
	TimeManager.advance_minutes(29)
	assert_true(GameState.npcs.is_alive("mara"))
	TimeManager.advance_minutes(2)
	assert_false(GameState.npcs.is_alive("mara"), "untreated Mara dies after the squall (delayed consequence)")
	assert_true(GameState.has_flag("mara_died"))


func test_ending_evaluation() -> void:
	assert_eq(EndingDirector.evaluate(), "long_winter")
	GameState.set_shelter_level(2)
	GameState.set_flag("stove_lit")
	GameState.npcs.set_location("elias", "shelter")
	GameState.npcs.set_location("tomas", "shelter")
	GameState.storage.add("canned_food", 3)
	assert_eq(EndingDirector.evaluate(), "home")
	assert_false(EndingDirector.epilogue_lines().is_empty())


# --- Save / load -----------------------------------------------------------------------------------------

func test_save_load_round_trip() -> void:
	SaveManager.save_dir = "user://test_saves"
	GameState.inventory.add("wood", 2)
	GameState.storage.add("cloth", 5)
	GameState.set_flag("radio_found")
	var vera_trust := GameState.relationships.change("vera", "trust", 17)
	GameState.npcs.set_location("anton", "shelter")
	GameState.set_shelter_level(2)
	QuestManager.start_quest("q03_signal")
	RadioManager.lock("rs_depot")
	TimeManager.set_time(2, 15, 30)
	assert_true(SaveManager.save_to_slot("2"))
	fresh_game()
	QuestManager.reset()
	RadioManager.reset()
	assert_eq(GameState.inventory.count("wood"), 0)
	var data := SaveManager.read_slot("2")
	assert_false(data.is_empty())
	SaveManager.apply(data)
	assert_eq(GameState.inventory.count("wood"), 2)
	assert_eq(GameState.storage.count("cloth"), 5)
	assert_true(GameState.has_flag("radio_found"))
	assert_eq(GameState.relationships.get_value("vera", "trust"), vera_trust)
	assert_eq(GameState.npcs.get_location("anton"), "shelter")
	assert_eq(GameState.shelter_level, 2)
	assert_true(QuestManager.is_active("q03_signal"))
	assert_true(RadioManager.is_found("rs_depot"))
	assert_eq(TimeManager.current_day, 2)
	assert_eq(TimeManager.format_clock(), "15:30")
	var info := SaveManager.slot_info("2")
	assert_eq(int(info.day), 2)
	SaveManager.delete_slot("2")
	SaveManager.save_dir = SaveManager.SAVE_DIR


func test_load_tolerates_old_and_broken_saves() -> void:
	var legacy := {"version": 0, "inventory": {"items": [["wood", 3], ["deleted_item", 1]]}, "game_state": {"flags": {"unknown_old_flag": 1}, "npc_states": {"ghost_npc": {"alive": true}}}}
	var migrated := SaveManager._migrate(legacy)
	SaveManager.apply(migrated)
	assert_eq(GameState.inventory.count("wood"), 3)
	assert_eq(GameState.get_flag("unknown_old_flag"), 1)
	assert_false(GameState.npcs.has_npc("ghost_npc"))
	assert_eq(QuestManager.get_active_quests().size(), 0)
