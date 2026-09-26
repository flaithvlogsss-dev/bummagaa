class_name DebugMenu
extends UIPanel
## DebugMenu (F1) — developer tools only (enabled in debug builds).
## Give items, heal, set temperature/time/day, weather, teleport, complete quests, set flags,
## spawn NPCs / enemies, upgrade the shelter, force the ending check, toggle the overlay.

var _temp: SpinBox
var _hour: SpinBox
var _day: SpinBox
var _teleport: OptionButton
var _quest: OptionButton
var _flag: LineEdit
var _flag_value: CheckBox
var _npc: OptionButton
var _info: Label
var _overlay: CheckBox
var _god: CheckBox
var _teleports: Array = []


static func debug_text() -> String:
	var s := GameState.stats
	var lines: PackedStringArray = []
	lines.append("Day: %d" % TimeManager.current_day)
	lines.append("Time: %s" % TimeManager.format_clock())
	lines.append("")
	lines.append("Temperature: %d" % int(s.temperature))
	lines.append("Hunger: %d" % int(s.hunger))
	lines.append("Hydration: %d" % int(s.hydration))
	lines.append("Health: %d  Stamina: %d  Stress: %d" % [int(s.health), int(s.stamina), int(s.stress)])
	lines.append("")
	lines.append("Weather: %s%s" % [WeatherManager.get_state(), " (forced)" if WeatherManager.is_forced() else ""])
	lines.append("Snow level: %.2f" % GameState.world.get_snow_level())
	lines.append("")
	lines.append("Shelter: %d" % GameState.shelter_level)
	lines.append("NPC Alive: %d" % GameState.alive_survivors().size())
	lines.append("In shelter: %s" % ", ".join(GameState.survivors_in_shelter()))
	lines.append("")
	var q := QuestManager.get_tracked()
	lines.append("Current Quest:")
	lines.append(str(Data.get_quest(q).get("title", "—")) if not q.is_empty() else "—")
	lines.append("")
	lines.append("Flags:")
	var n := 0
	for k in GameState.flags.keys():
		if str(k).begins_with("seen:") or str(k).begins_with("once:"):
			continue
		lines.append("%s = %s" % [k, str(GameState.flags[k]).to_lower()])
		n += 1
		if n >= 14:
			lines.append("…")
			break
	return "\n".join(lines)


func _build() -> void:
	add_backdrop(0.4)
	var p := UIKit.panel(Vector2(900, 560))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(p)
	var row := UIKit.hbox(16)
	p.add_child(row)
	var left := UIKit.vbox(5)
	left.custom_minimum_size.x = 560
	row.add_child(left)
	var head := UIKit.hbox(8)
	var t := UIKit.title("DEBUG (F1)")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Закрыть", close))
	left.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	for entry in [
		["Give Items", _give_items], ["Add Food", _add_food], ["Add Ammo", func(): GameState.inventory.add("pistol_ammo", 12)],
		["Heal", _heal], ["Trigger Blizzard", func(): WeatherManager.force_weather("BLIZZARD", 90)], ["Clear Weather", func(): WeatherManager.clear_forced()],
		["Heavy Snow", func(): WeatherManager.force_weather("HEAVY", 90)], ["Shelter +1", func(): GameState.set_shelter_level(GameState.shelter_level + 1)], ["Spawn Enemy", func(): GameState.request_world("spawn_stalker", {"near_player": true})],
		["Sleep (skip night)", func():
			close()
			Main.request_sleep()], ["Ending check", func():
			close()
			Consequences.apply({"evaluate_ending": true})], ["Quick Save (1)", func(): SaveManager.save_to_slot("1")],
	]:
		grid.add_child(UIKit.button(entry[0], entry[1], 180))
	left.add_child(UIKit.separator())
	_temp = _spin(0, 100, 50)
	left.add_child(_line("Set Temperature", _temp, func(): GameState.stats.set_value("temperature", _temp.value)))
	_hour = _spin(0, 23, 18)
	left.add_child(_line("Set Time (hour)", _hour, func(): TimeManager.set_time(TimeManager.current_day, int(_hour.value), 0)))
	_day = _spin(1, 4, 2)
	left.add_child(_line("Set Day", _day, func():
		TimeManager.set_time(int(_day.value), TimeManager.current_hour, TimeManager.current_minute)
		WeatherManager._on_day_changed(int(_day.value))))
	_teleport = OptionButton.new()
	left.add_child(_line("Teleport", _teleport, _do_teleport))
	_quest = OptionButton.new()
	left.add_child(_line("Complete Quest", _quest, _complete_quest))
	var flag_row := UIKit.hbox(6)
	_flag = LineEdit.new()
	_flag.placeholder_text = "flag_name"
	_flag.custom_minimum_size.x = 200
	_flag_value = CheckBox.new()
	_flag_value.text = "true"
	_flag_value.button_pressed = true
	flag_row.add_child(_flag)
	flag_row.add_child(_flag_value)
	left.add_child(_line("Set Story Flag", flag_row, func():
		if not _flag.text.strip_edges().is_empty():
			GameState.set_flag(_flag.text.strip_edges(), _flag_value.button_pressed)))
	_npc = OptionButton.new()
	left.add_child(_line("Spawn NPC here", _npc, _spawn_npc))
	var toggles := UIKit.hbox(12)
	_overlay = CheckBox.new()
	_overlay.text = "Debug overlay"
	_overlay.toggled.connect(func(on): UIRoot.instance.hud.set_debug_overlay(on))
	toggles.add_child(_overlay)
	_god = CheckBox.new()
	_god.text = "God mode"
	_god.toggled.connect(func(on):
		GameState.stats.god_mode = on
		var pl := Main.get_player()
		if pl:
			pl.god_mode = on)
	toggles.add_child(_god)
	left.add_child(toggles)
	_info = UIKit.label("", 12, Color(0.7, 1.0, 0.7))
	_info.custom_minimum_size.x = 300
	row.add_child(_info)


func _spin(lo: float, hi: float, v: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = v
	return s


func _line(title_text: String, control: Control, cb: Callable) -> HBoxContainer:
	var h := UIKit.hbox(6)
	var l := UIKit.label(title_text, 13)
	l.custom_minimum_size.x = 150
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	h.add_child(UIKit.button("OK", cb, 50))
	return h


func _on_open(_data: Dictionary) -> void:
	_teleports = [["shelter", "start", "Убежище"], ["district", "shelter_door", "Улица у убежища"], ["district", "square", "Площадь"], ["district", "pharmacy", "Аптека"], ["district", "alley", "Переулок"], ["district", "north_road", "Северная дорога"], ["district", "house", "Жилой дом"], ["district", "shop", "Магазин"], ["district", "narrow_street", "Узкая улица"]]
	_teleport.clear()
	for t in _teleports:
		_teleport.add_item(t[2])
	_quest.clear()
	for id in QuestManager.get_active_quests():
		_quest.add_item(str(Data.get_quest(id).get("title", id)))
		_quest.set_item_metadata(_quest.item_count - 1, id)
	for id in Data.quests.keys():
		if QuestManager.get_status(id).is_empty():
			_quest.add_item("(не начато) " + str(Data.quests[id].get("title", id)))
			_quest.set_item_metadata(_quest.item_count - 1, id)
	_npc.clear()
	for id in GameState.npcs.alive_ids():
		_npc.add_item(Data.get_character_name(id))
		_npc.set_item_metadata(_npc.item_count - 1, id)
	_god.button_pressed = GameState.stats.god_mode


func _process(_delta: float) -> void:
	if is_open:
		_info.text = debug_text()


## Military backpack first (room), then a survival kit; what does not fit lands at the feet.
func _give_items() -> void:
	var inv := GameState.inventory
	if inv.get_equipped("backpack") != "military_backpack":
		inv.add_stack({"id": "military_backpack", "count": 1}, true)
		inv.equip("military_backpack")
	if inv.get_equipped("mask").is_empty():
		inv.add("gas_mask", 1, true)
		inv.equip("gas_mask")
	var kit := {"scrap_metal": 3, "cloth": 4, "electronics": 2, "canned_food": 2, "water_bottle": 2,
		"bandage": 2, "medicine": 1, "filter_standard": 2, "flashlight": 1, "crowbar": 1, "pistol": 1,
		"pistol_ammo": 12, "empty_bottle": 2, "flare": 1, "warm_jacket": 1}
	for id in kit.keys():
		GameState.give_or_drop(id, kit[id], false)
	GameState.notify("Debug: предметы выданы.")


func _add_food() -> void:
	for id in ["canned_food", "dry_food", "water_bottle"]:
		GameState.give_or_drop(id, 2, false)


func _heal() -> void:
	var s := GameState.stats
	for stat in ["health", "hunger", "hydration", "temperature"]:
		s.set_value(stat, 100.0)
	s.set_value("stamina", s.max_stamina)
	s.set_value("stress", 0.0)
	s.bleeding = 0.0
	s.illness = false


func _do_teleport() -> void:
	var t: Array = _teleports[_teleport.selected] if _teleport.selected >= 0 else []
	if t.is_empty():
		return
	close()
	Main.request_level_change(t[0], t[1])


func _complete_quest() -> void:
	if _quest.selected < 0:
		return
	var id := str(_quest.get_item_metadata(_quest.selected))
	QuestManager.complete_quest(id)
	_on_open({})


func _spawn_npc() -> void:
	if _npc.selected < 0:
		return
	var id := str(_npc.get_item_metadata(_npc.selected))
	GameState.npcs.set_location(id, GameState.current_location, "debug")
	GameState.request_world("npc_moved", {"npc": id})
	close()
