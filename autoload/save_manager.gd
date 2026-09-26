extends Node
## SaveManager — JSON save slots (1, 2, 3 + auto) and debounced autosave.
##
## Purpose: collects serialize() from every stateful system into one versioned document and
##   restores it. Unknown items / quests / NPCs / flags in old saves are skipped or kept
##   harmlessly; missing keys fall back to defaults.
## Autosave: start of a day, returning to the shelter, completed quests and major decisions
##   (never every second — at most once per AUTOSAVE_COOLDOWN).
## Dependencies: GameState, TimeManager, WeatherManager, QuestManager, EventManager, RadioManager.
## Public API: save_to_slot(slot), read_slot(slot), apply(data), autosave(reason, force),
##   slot_info(slot), latest_slot(), has_save(slot), delete_slot(slot)
## Signals: saved(slot), save_failed(slot, error)
## Save file: user://saves/slot_<slot>.json

signal saved(slot: String)
signal save_failed(slot: String, error: String)

const SAVE_DIR := "user://saves"
const VERSION := 2
const SLOTS: Array[String] = ["1", "2", "3", "auto"]
const AUTOSAVE_COOLDOWN_MS := 45000

var autosave_enabled: bool = true
var save_dir: String = SAVE_DIR
var _last_autosave_ms: int = -AUTOSAVE_COOLDOWN_MS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.decision_made.connect(func(_k, _v): autosave.call_deferred("decision"))
	TimeManager.morning_started.connect(func(_d):
		if not TimeManager.is_skipping:
			autosave.call_deferred("morning", true))


func _path(slot: String) -> String:
	return save_dir.path_join("slot_%s.json" % slot)


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_path(slot))


func build_save_data(label: String = "") -> Dictionary:
	var player := Main.get_player()
	if player:
		GameState.player_position = player.global_position
	return {
		"version": VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"meta": {
			"label": label,
			"day": TimeManager.current_day,
			"time": TimeManager.format_clock(),
			"location": GameState.current_location,
			"quest": QuestManager.get_tracked(),
		},
		"game_state": GameState.serialize(),
		"time": TimeManager.serialize(),
		"weather": WeatherManager.serialize(),
		"quests": QuestManager.serialize(),
		"events": EventManager.serialize(),
		"radio": RadioManager.serialize(),
	}


func save_to_slot(slot: String, label: String = "") -> bool:
	if not SLOTS.has(slot):
		push_warning("SaveManager: unknown slot '%s'" % slot)
		return false
	DirAccess.make_dir_recursive_absolute(save_dir)
	var data := build_save_data(label)
	var tmp := _path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		var err := error_string(FileAccess.get_open_error())
		save_failed.emit(slot, err)
		GameState.notify("Не удалось сохранить: %s" % err, "danger")
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(_path(slot)):
		DirAccess.remove_absolute(_path(slot))
	var rename_err := DirAccess.rename_absolute(tmp, _path(slot))
	if rename_err != OK:
		save_failed.emit(slot, error_string(rename_err))
		return false
	saved.emit(slot)
	return true


func read_slot(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var parsed = Data.load_json(_path(slot))
	if not (parsed is Dictionary) or not parsed.has("game_state"):
		push_warning("SaveManager: slot %s is corrupt" % slot)
		return {}
	return _migrate(parsed)


## Restores every system from a save document (level loading is done by Main).
func apply(data: Dictionary) -> void:
	GameState.deserialize(data.get("game_state", {}))
	TimeManager.deserialize(data.get("time", {}))
	QuestManager.deserialize(data.get("quests", {}))
	EventManager.deserialize(data.get("events", {}))
	RadioManager.deserialize(data.get("radio", {}))
	WeatherManager.deserialize(data.get("weather", {}))


func slot_info(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var parsed = Data.load_json(_path(slot))
	if not (parsed is Dictionary):
		return {}
	var info: Dictionary = parsed.get("meta", {}).duplicate()
	info["timestamp"] = int(parsed.get("timestamp", 0))
	return info


func latest_slot() -> String:
	var best := ""
	var best_t := -1
	for slot in SLOTS:
		var info := slot_info(slot)
		if not info.is_empty() and int(info.timestamp) > best_t:
			best_t = int(info.timestamp)
			best = slot
	return best


func delete_slot(slot: String) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_path(slot))


func autosave(reason: String = "", force: bool = false) -> void:
	if not autosave_enabled or Main.instance == null:
		return
	if Main.instance.mode != Main.Mode.PLAYING and reason != "ending":
		return
	var now := Time.get_ticks_msec()
	if not force and now - _last_autosave_ms < AUTOSAVE_COOLDOWN_MS:
		return
	_last_autosave_ms = now
	if save_to_slot("auto", reason):
		GameState.present("autosave", {"reason": reason})


## Upgrades older save documents to the current VERSION.
func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 0))
	if v < 1:
		# v0 (pre-release) stored the inventory at the top level.
		if data.has("inventory") and data.game_state is Dictionary:
			data.game_state["inventory"] = data.inventory
		data["version"] = 1
	if v < 2:
		# v1 -> v2: slot inventory. Inventory.deserialize reads the old item list itself; the
		# pistol's magazine and wear moved from the player stats onto the weapon stack.
		var gs: Dictionary = data.get("game_state", {})
		var inv: Dictionary = gs.get("inventory", {})
		var st: Dictionary = gs.get("stats", {})
		var eq: Dictionary = inv.get("equipped", {})
		var new_eq := {}
		for slot in eq.keys():
			var key: String = Inventory.LEGACY_SLOTS.get(str(slot), str(slot))
			var stack := {"id": str(eq[slot]), "count": 1}
			if key == "weapon":
				stack["cond"] = float(st.get("weapon_durability", 100.0))
				stack["data"] = {"mag": int(st.get("magazine", 0))}
			new_eq[key] = stack
		inv["equipped"] = new_eq
		if not gs.has("known_recipes"):
			var known: Array = []
			for r in Data.recipes.keys():
				if (Data.recipes[r] as RecipeData).known_from_start:
					known.append(r)
			gs["known_recipes"] = known
		data["version"] = 2
	return data
