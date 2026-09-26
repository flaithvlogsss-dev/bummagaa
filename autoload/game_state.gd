extends Node
## GameState — central store of everything that makes this playthrough unique.
##
## Purpose: a thin facade over small focused objects instead of a monolithic manager:
##   inventory / storage (Inventory), stats (PlayerStats), relationships (RelationshipSystem),
##   npcs (NPCRegistry), world (WorldState) + story flags, decisions, discoveries, shelter level.
## Dependencies: Data.
## Public API: new_game(), set_flag(), get_flag(), record_decision(), add_information(),
##   discover_location(), set_shelter_level(), notify(), hint(), present(), request_world(),
##   survivors_in_shelter(), serialize(), deserialize()
## Signals: story_flag_changed, decision_made, information_discovered, location_discovered,
##   shelter_upgraded, markers_changed, ending_requested, world_request, presentation_requested,
##   new_game_started, state_loaded
## Save Data: see serialize().

signal story_flag_changed(flag: String, value: Variant)
signal decision_made(key: String, value: Variant)
signal information_discovered(info_id: String)
signal location_discovered(location_id: String)
signal shelter_upgraded(level: int)
signal markers_changed
signal ending_requested(ending_id: String)
## Requests for the active level (spawn enemy, move npc node...). kind + payload.
signal world_request(kind: String, data: Dictionary)
## Requests for UI / camera / screen (notify, hint, title_card, shake...).
signal presentation_requested(kind: String, data: Dictionary)
signal location_changed(level_id: String)
signal new_game_started
signal state_loaded

const MAX_SHELTER_LEVEL := 3
## Worn at the start of a new game: slot -> item id.
const START_EQUIPMENT := {"backpack": "small_backpack", "head": "knit_hat"}

var player_name: String = "Alex"
var flags: Dictionary = {}
var decisions: Dictionary = {}
var discovered_locations: Array = []
var discovered_information: Array = []
var shelter_level: int = 1
## Level id the player is currently in ("shelter", "district").
var current_location: String = "shelter"
var player_position: Vector3 = Vector3.ZERO
var map_markers: Array = []
## Persistent per-object state for interactables: {persistent_id: {...}}
var world_objects: Dictionary = {}
## Items lying in the world: {level_id: [{"stack": {...}, "pos": [x, y, z]}]}
var dropped_items: Dictionary = {}
## Recipe ids the player knows (books, notes, people).
var known_recipes: Array = []
## Seed for per-playthrough randomness (loot rolls).
var world_seed: int = 0
var ending_id: String = ""
var play_time: float = 0.0

var inventory: Inventory
var storage: Inventory
var stats: PlayerStats
var relationships: RelationshipSystem
var npcs: NPCRegistry
var world: WorldState


func _ready() -> void:
	inventory = Inventory.new("player", true)
	storage = Inventory.new("storage", false)
	stats = PlayerStats.new()
	relationships = RelationshipSystem.new()
	npcs = NPCRegistry.new()
	world = WorldState.new()
	_register_conditions()
	_register_consequences()
	reset_state()
	TimeManager.hour_passed.connect(func(_d, _h): _tick_spoilage())


func _process(delta: float) -> void:
	play_time += delta


## Clears the playthrough to fresh defaults (does not touch other managers).
func reset_state() -> void:
	player_name = "Alex"
	var player_data := Data.get_character("player") if Data.characters.has("player") else null
	if player_data:
		player_name = player_data.display_name
	flags.clear()
	decisions.clear()
	discovered_locations.clear()
	discovered_information.clear()
	shelter_level = 1
	current_location = "shelter"
	player_position = Vector3.ZERO
	map_markers.clear()
	world_objects.clear()
	dropped_items.clear()
	known_recipes.clear()
	world_seed = randi()
	for r in Data.recipes.keys():
		if (Data.recipes[r] as RecipeData).known_from_start:
			known_recipes.append(r)
	ending_id = ""
	play_time = 0.0
	inventory.clear()
	storage.clear()
	stats.reset()
	relationships.clear()
	npcs.reset_from_data(Data.characters)
	for id in Data.characters.keys():
		var c: CharacterData = Data.characters[id]
		if c.is_npc:
			relationships.ensure(id, c.relationship_start)
	world.reset()


func new_game() -> void:
	reset_state()
	for slot in START_EQUIPMENT.keys():
		if inventory.add(START_EQUIPMENT[slot], 1, true, {"cond": 80.0}) > 0:
			inventory.equip(START_EQUIPMENT[slot])
	# The gas mask everyone in the city got in the first week, with an old filter in it.
	if inventory.add("gas_mask", 1, true, {"cond": 70.0, "data": {"filter": "filter_old", "filter_left": 30.0}}) > 0:
		inventory.equip("gas_mask")
	inventory.add("filter_homemade", 1, true)
	new_game_started.emit()


# --- Flags & decisions -----------------------------------------------------------

func set_flag(flag: String, value: Variant = true) -> void:
	if flag.is_empty():
		return
	if flags.has(flag) and Conditions.values_equal(flags[flag], value):
		return
	flags[flag] = value
	story_flag_changed.emit(flag, value)


func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)


func has_flag(flag: String) -> bool:
	return Conditions.truthy(flags.get(flag, false))


func clear_flag(flag: String) -> void:
	if flags.has(flag):
		flags.erase(flag)
		story_flag_changed.emit(flag, false)


## Decisions are long-term consequences read by events and endings. Also mirrored as flags.
func record_decision(key: String, value: Variant) -> void:
	decisions[key] = {"value": value, "day": TimeManager.current_day, "time": TimeManager.format_clock()}
	set_flag("decision_" + key, value)
	decision_made.emit(key, value)


func get_decision(key: String, default: Variant = null) -> Variant:
	return decisions.get(key, {}).get("value", default)


# --- Discoveries -------------------------------------------------------------------

func add_information(info_id: String) -> bool:
	if info_id.is_empty() or discovered_information.has(info_id):
		return false
	var info := Data.get_information(info_id)
	if info == null:
		return false
	discovered_information.append(info_id)
	for f in info.sets_flags:
		set_flag(f, true)
	information_discovered.emit(info_id)
	notify("Новая запись: %s" % info.title, "info")
	return true


func has_information(info_id: String) -> bool:
	return discovered_information.has(info_id)


func count_information(tag: String = "") -> int:
	var n := 0
	for id in discovered_information:
		var info := Data.get_information(id)
		if info and (tag.is_empty() or info.tags.has(tag) or info.info_type == tag):
			n += 1
	return n


func discover_location(location_id: String) -> bool:
	if location_id.is_empty() or discovered_locations.has(location_id):
		return false
	discovered_locations.append(location_id)
	location_discovered.emit(location_id)
	return true


# --- Shelter & survivors -------------------------------------------------------------

func set_shelter_level(level: int) -> void:
	level = clampi(level, 1, MAX_SHELTER_LEVEL)
	if level == shelter_level:
		return
	shelter_level = level
	shelter_upgraded.emit(level)


func set_location(level_id: String) -> void:
	if current_location == level_id:
		return
	current_location = level_id
	location_changed.emit(level_id)


func survivors_in_shelter() -> Array[String]:
	return npcs.in_shelter()


func alive_survivors() -> Array[String]:
	return npcs.alive_ids()


func dead_survivors() -> Array[String]:
	return npcs.dead_ids()


## Ready-to-eat food (not ingredients, not spoiled) in the backpack and the shelter storage.
func food_total() -> int:
	var n := 0
	for inv in [inventory, storage]:
		for e in inv.get_entries():
			if is_meal(e.item):
				n += int(e.count)
	return n


static func is_meal(item: ItemData) -> bool:
	return item != null and item.has_tag("food") and item.is_usable() and not item.has_tag("spoiled")


## Removes one meal from storage, soonest-to-spoil and cheapest first. Returns its id or "".
func _take_meal_from_storage() -> String:
	var best := -1
	var best_score := INF
	var list := storage.get_slots()
	for i in list.size():
		var st: Dictionary = list[i]
		if st.is_empty():
			continue
		var item := Data.get_item(st.id)
		if not is_meal(item):
			continue
		var score := float(item.value) + (float(st.data.exp) / 100000.0 if st.has("data") and st.data.has("exp") else 50.0)
		if score < best_score:
			best_score = score
			best = i
	if best < 0:
		return ""
	return str(storage.take_at(best, 1).get("id", ""))


## Morning routine: every survivor in the shelter eats one meal from storage.
func _feed_survivors() -> void:
	var ids := survivors_in_shelter()
	if ids.is_empty():
		return
	var hungry: PackedStringArray = []
	for id in ids:
		var ate := not _take_meal_from_storage().is_empty()
		if ate:
			npcs.modify_stat(id, "hope", 5.0)
		else:
			hungry.append(Data.get_character_name(id))
			npcs.modify_stat(id, "hope", -15.0)
			relationships.change(id, "trust", -5.0)
	if hungry.is_empty():
		notify("Утро. Все в убежище поели (%d еды со склада)." % ids.size(), "event")
	else:
		notify("Утро. Еды на складе не хватило: %s остались голодными." % ", ".join(hungry), "warning")
		stats.modify("stress", 8.0)


# --- Items in the world ----------------------------------------------------------------

## Gives items to the player; whatever does not fit is dropped at the player's feet.
## Returns how many went into the backpack.
func give_or_drop(item_id: String, amount: int, notify_player: bool = true, props: Dictionary = {}) -> int:
	if not Data.has_item(item_id) or amount <= 0:
		return 0
	var added := inventory.add(item_id, amount, false, props)
	var rest := amount - added
	if rest > 0:
		var stack := {"id": item_id, "count": rest}
		for k in props.keys():
			stack[k] = props[k]
		drop_stack(stack)
	if notify_player:
		var n := Data.get_item_name(item_id)
		if rest > 0:
			notify("+%d %s (%d не влезло — лежит рядом)" % [amount, n, rest], "warning")
		else:
			notify("+%d %s" % [amount, n], "item")
	return added


## Puts a stack on the ground near `pos` (default: the player) in the current level.
func drop_stack(stack: Dictionary, pos: Variant = null) -> void:
	if stack.is_empty():
		return
	var p: Vector3 = player_position
	var pl := Main.get_player() if Main.instance else null
	if pos is Vector3:
		p = pos
	elif pl:
		p = pl.global_position + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(0.3, 0.8))
	var entry := {"stack": stack.duplicate(true), "pos": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]}
	if not dropped_items.has(current_location):
		dropped_items[current_location] = []
	dropped_items[current_location].append(entry)
	request_world("item_dropped", {"entry": entry})


func get_dropped(level_id: String) -> Array:
	return dropped_items.get(level_id, [])


func remove_dropped(level_id: String, entry: Dictionary) -> void:
	if dropped_items.has(level_id):
		dropped_items[level_id].erase(entry)


func learn_recipe(recipe_id: String, announce: bool = true) -> bool:
	if known_recipes.has(recipe_id) or not Data.recipes.has(recipe_id):
		return false
	known_recipes.append(recipe_id)
	if announce:
		notify("Новый рецепт: %s" % Data.get_recipe(recipe_id).name, "info")
	return true


func knows_recipe(recipe_id: String) -> bool:
	return known_recipes.has(recipe_id)


func _tick_spoilage() -> void:
	for inv in [inventory, storage]:
		var spoiled: Array = inv.tick_spoilage(TimeManager.total_minutes)
		if inv == inventory and not spoiled.is_empty():
			notify("Испортилось: %s" % Data.get_item_name(str(spoiled[0])), "warning")


# --- Presentation helpers -------------------------------------------------------------

func notify(text: String, kind: String = "info") -> void:
	presentation_requested.emit("notify", {"text": text, "kind": kind})


func hint(text: String, duration: float = 7.0) -> void:
	presentation_requested.emit("hint", {"text": text, "duration": duration})


func present(kind: String, data: Dictionary = {}) -> void:
	presentation_requested.emit(kind, data)


func request_world(kind: String, data: Dictionary = {}) -> void:
	world_request.emit(kind, data)


func format_text(text: String) -> String:
	return text.replace("{player}", player_name)


# --- Map markers --------------------------------------------------------------------------

func add_marker(marker_type: String, pos: Vector2, label: String = "") -> void:
	map_markers.append({"type": marker_type, "x": pos.x, "y": pos.y, "label": label})
	markers_changed.emit()


func remove_marker(index: int) -> void:
	if index >= 0 and index < map_markers.size():
		map_markers.remove_at(index)
		markers_changed.emit()


# --- Persistent world objects ------------------------------------------------------------

func get_object_state(persistent_id: String) -> Dictionary:
	return world_objects.get(persistent_id, {})


func set_object_state(persistent_id: String, key: String, value: Variant) -> void:
	if not world_objects.has(persistent_id):
		world_objects[persistent_id] = {}
	world_objects[persistent_id][key] = value


# --- Save / load --------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"player_name": player_name,
		"flags": flags.duplicate(true),
		"decisions": decisions.duplicate(true),
		"discovered_locations": discovered_locations.duplicate(),
		"discovered_information": discovered_information.duplicate(),
		"shelter_level": shelter_level,
		"current_location": current_location,
		"player_position": [player_position.x, player_position.y, player_position.z],
		"map_markers": map_markers.duplicate(true),
		"world_objects": world_objects.duplicate(true),
		"dropped_items": dropped_items.duplicate(true),
		"known_recipes": known_recipes.duplicate(),
		"world_seed": world_seed,
		"play_time": play_time,
		"inventory": inventory.serialize(),
		"storage": storage.serialize(),
		"stats": stats.serialize(),
		"relationships": relationships.serialize(),
		"npc_states": npcs.serialize(),
		"world": world.serialize(),
		# Derived, stored for readability of save files / debugging.
		"alive_survivors": alive_survivors(),
		"dead_survivors": dead_survivors(),
	}


func deserialize(d: Dictionary) -> void:
	reset_state()
	player_name = str(d.get("player_name", player_name))
	flags = d.get("flags", {}).duplicate(true)
	decisions = d.get("decisions", {}).duplicate(true)
	discovered_locations = d.get("discovered_locations", []).duplicate()
	discovered_information = []
	for id in d.get("discovered_information", []):
		if Data.information.has(id):
			discovered_information.append(id)
	shelter_level = clampi(int(d.get("shelter_level", 1)), 1, MAX_SHELTER_LEVEL)
	current_location = str(d.get("current_location", "shelter"))
	var p: Array = d.get("player_position", [0, 0, 0])
	if p.size() == 3:
		player_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	map_markers = d.get("map_markers", []).duplicate(true)
	world_objects = d.get("world_objects", {}).duplicate(true)
	dropped_items = d.get("dropped_items", {}).duplicate(true)
	world_seed = int(d.get("world_seed", world_seed))
	if d.has("known_recipes"):
		known_recipes = []
		for r in d.known_recipes:
			if Data.recipes.has(str(r)):
				known_recipes.append(str(r))
	play_time = float(d.get("play_time", 0.0))
	inventory.deserialize(d.get("inventory", {}))
	storage.deserialize(d.get("storage", {}))
	stats.deserialize(d.get("stats", {}))
	relationships.deserialize(d.get("relationships", {}))
	npcs.deserialize(d.get("npc_states", {}))
	world.deserialize(d.get("world", {}))
	state_loaded.emit()


# --- Condition keys ------------------------------------------------------------------------

func _register_conditions() -> void:
	var C := Conditions
	C.register("flag", func(v, _ctx):
		if v is Array and v.size() >= 2:
			return Conditions.values_equal(get_flag(str(v[0])), v[1])
		return has_flag(str(v)))
	C.register("not_flag", func(v, _ctx): return not has_flag(str(v)))
	C.register("item", func(v, _ctx):
		var pair := _id_count(v)
		return inventory.has_item(pair[0], pair[1]))
	C.register("no_item", func(v, _ctx): return not inventory.has_item(str(v)))
	C.register("any_item", func(v, _ctx):
		for id in v:
			if inventory.has_item(str(id)):
				return true
		return false)
	C.register("storage_item", func(v, _ctx):
		var pair := _id_count(v)
		return storage.has_item(pair[0], pair[1]))
	C.register("item_total", func(v, _ctx):
		var pair := _id_count(v)
		return inventory.count(pair[0]) + storage.count(pair[0]) >= pair[1])
	C.register("food_total_min", func(v, _ctx): return food_total() >= int(v))
	C.register("equipped", func(v, _ctx): return inventory.is_equipped(str(v)))
	C.register("item_tag", func(v, _ctx): return inventory.has_tag(str(v)))
	C.register("recipe_known", func(v, _ctx): return knows_recipe(str(v)))
	C.register("info", func(v, _ctx): return has_information(str(v)))
	C.register("not_info", func(v, _ctx): return not has_information(str(v)))
	C.register("info_count_min", func(v, _ctx):
		if v is Array:
			return count_information(str(v[0])) >= int(v[1])
		return count_information() >= int(v))
	C.register("discovered", func(v, _ctx): return discovered_locations.has(str(v)))
	C.register("location", func(v, _ctx): return current_location == str(v))
	C.register("shelter_level_min", func(v, _ctx): return shelter_level >= int(v))
	C.register("shelter_level", func(v, _ctx): return shelter_level == int(v))
	C.register("npc_alive", func(v, ctx): return npcs.is_alive(Conditions.resolve_npc(v, ctx)))
	C.register("npc_dead", func(v, ctx):
		var id := Conditions.resolve_npc(v, ctx)
		return npcs.has_npc(id) and not npcs.is_alive(id))
	C.register("npc_at", func(v, ctx):
		var id := Conditions.resolve_npc(v[0], ctx)
		return npcs.is_alive(id) and npcs.get_location(id) == str(v[1]))
	C.register("npc_not_at", func(v, ctx):
		var id := Conditions.resolve_npc(v[0], ctx)
		return npcs.get_location(id) != str(v[1]))
	C.register("npc_met", func(v, ctx): return bool(npcs.get_state(Conditions.resolve_npc(v, ctx)).get("met", false)))
	C.register("npc_injured", func(v, ctx): return bool(npcs.get_state(Conditions.resolve_npc(v, ctx)).get("injured", false)))
	C.register("relationship", func(v, ctx):
		var id := Conditions.resolve_npc(v.get("npc", "self"), ctx)
		var value := relationships.get_value(id, str(v.get("stat", "trust")))
		return value >= float(v.get("min", -1000.0)) and value <= float(v.get("max", 1000.0)))
	C.register("tier_min", func(v, ctx):
		var id := Conditions.resolve_npc(v[0], ctx)
		return RelationshipSystem.tier_rank(relationships.get_tier(id)) >= RelationshipSystem.tier_rank(str(v[1])))
	C.register("tier_max", func(v, ctx):
		var id := Conditions.resolve_npc(v[0], ctx)
		return RelationshipSystem.tier_rank(relationships.get_tier(id)) <= RelationshipSystem.tier_rank(str(v[1])))
	C.register("memory", func(v, ctx):
		var id := Conditions.resolve_npc(v[0], ctx)
		var expected = v[2] if v.size() > 2 else true
		return Conditions.values_equal(npcs.get_memory(id, str(v[1]), false), expected))
	C.register("decision", func(v, _ctx):
		if v is Array:
			return Conditions.values_equal(get_decision(str(v[0])), v[1])
		return decisions.has(str(v)))
	C.register("survivors_min", func(v, _ctx): return survivors_in_shelter().size() >= int(v))
	C.register("stat_below", func(v, _ctx): return stats.get_value(str(v[0])) < float(v[1]))
	C.register("stat_above", func(v, _ctx): return stats.get_value(str(v[0])) > float(v[1]))
	C.register("world", func(v, _ctx):
		for key in v.keys():
			if not Conditions.values_equal(world.get_value(key), v[key]):
				return false
		return true)
	C.register("world_min", func(v, _ctx): return float(world.get_value(str(v[0]), 0.0)) >= float(v[1]))
	C.register("route_open", func(v, _ctx): return world.is_route_open(str(v)))


static func _id_count(v: Variant) -> Array:
	if v is Array:
		return [str(v[0]), int(v[1]) if v.size() > 1 else 1]
	return [str(v), 1]


# --- Consequence keys ------------------------------------------------------------------------

func _register_consequences() -> void:
	var K := Consequences
	K.register("set_flag", func(v, _ctx):
		if v is Array:
			set_flag(str(v[0]), v[1] if v.size() > 1 else true)
		else:
			set_flag(str(v), true))
	K.register("clear_flag", func(v, _ctx): clear_flag(str(v)))
	K.register("give_item", func(v, _ctx):
		var pair := _id_count(v)
		give_or_drop(pair[0], pair[1]))
	K.register("return_item", func(v, _ctx):
		var pair := _id_count(v)
		give_or_drop(pair[0], pair[1], false))
	K.register("learn_recipes", func(v, _ctx):
		var learned := 0
		for r in (v if v is Array else [v]):
			if learn_recipe(str(r), false):
				learned += 1
		if learned > 0:
			notify("Изучено рецептов: %d. Смотри в мастерской." % learned, "info")
		else:
			notify("Ничего нового — всё это ты уже знаешь.", "info"))
	K.register("illness_chance", func(v, _ctx):
		var chance := float(v) * (0.5 if stats.vitamins > 0.0 else 1.0)
		if randf() < chance and not stats.illness:
			stats.illness = true
			stats.changed.emit("status", 0.0)
			notify("Тебя знобит. Кажется, ты заболел.", "danger"))
	K.register("charge_flashlight", func(v, _ctx):
		stats.flashlight_battery = minf(100.0, stats.flashlight_battery + float(v))
		stats.changed.emit("status", 0.0))
	K.register("take_item", func(v, _ctx):
		var pair := _id_count(v)
		if inventory.remove(pair[0], pair[1]):
			notify("−%d %s" % [pair[1], Data.get_item_name(pair[0])], "item"))
	K.register("give_storage", func(v, _ctx):
		var pair := _id_count(v)
		storage.add(pair[0], pair[1]))
	K.register("take_storage", func(v, _ctx):
		var pair := _id_count(v)
		storage.remove(pair[0], pair[1]))
	K.register("relationship", func(v, ctx):
		var id := Conditions.resolve_npc(v.get("npc", "self"), ctx)
		for stat in RelationshipSystem.STATS:
			if v.has(stat):
				relationships.change(id, stat, float(v[stat])))
	K.register("memory", func(v, ctx):
		var id := Conditions.resolve_npc(v[0], ctx)
		npcs.set_memory(id, str(v[1]), v[2] if v.size() > 2 else true))
	K.register("add_info", func(v, _ctx): add_information(str(v)))
	K.register("discover_location", func(v, _ctx): discover_location(str(v)))
	K.register("npc_location", func(v, ctx):
		var id := Conditions.resolve_npc(v[0], ctx)
		npcs.set_location(id, str(v[1]), str(v[2]) if v.size() > 2 else "")
		request_world("npc_moved", {"npc": id}))
	K.register("npc_value", func(v, ctx):
		npcs.set_value(Conditions.resolve_npc(v[0], ctx), str(v[1]), v[2]))
	K.register("npc_met", func(v, ctx):
		npcs.set_value(Conditions.resolve_npc(v, ctx), "met", true))
	K.register("npc_stat", func(v, ctx):
		npcs.modify_stat(Conditions.resolve_npc(v[0], ctx), str(v[1]), float(v[2])))
	K.register("kill_npc", func(v, ctx):
		var id := Conditions.resolve_npc(v if not (v is Array) else v[0], ctx)
		npcs.kill(id, str(v[1]) if v is Array and v.size() > 1 else "")
		request_world("npc_moved", {"npc": id}))
	K.register("stat", func(v, _ctx):
		for stat in v.keys():
			stats.modify(str(stat), float(v[stat])))
	K.register("status", func(v, _ctx):
		if v.has("bleeding"):
			stats.bleeding = maxf(0.0, float(v["bleeding"]))
		if v.has("illness"):
			stats.illness = bool(v["illness"])
		if v.has("warm_pack"):
			stats.warm_pack_time = maxf(stats.warm_pack_time, float(v["warm_pack"]))
		if v.has("vitamins"):
			stats.vitamins = maxf(stats.vitamins, float(v["vitamins"]))
		stats.changed.emit("status", 0.0))
	K.register("decision", func(v, _ctx): record_decision(str(v[0]), v[1] if v.size() > 1 else true))
	K.register("notify", func(v, _ctx): notify(format_text(str(v))))
	K.register("hint", func(v, _ctx): hint(format_text(str(v))))
	K.register("title_card", func(v, _ctx): present("title_card", {"text": format_text(str(v))}))
	K.register("shake", func(v, _ctx): present("shake", {"amount": float(v)}))
	K.register("flash", func(v, _ctx): present("flash", {"amount": float(v)}))
	K.register("shelter_level", func(v, _ctx): set_shelter_level(int(v)))
	K.register("world", func(v, _ctx):
		for key in v.keys():
			world.set_value(str(key), v[key]))
	K.register("route", func(v, _ctx): world.set_route(str(v[0]), bool(v[1])))
	K.register("faction", func(v, _ctx):
		for f in v.keys():
			world.change_faction(str(f), float(v[f])))
	K.register("world_request", func(v, _ctx):
		request_world(str(v[0]), v[1] if v.size() > 1 and v[1] is Dictionary else {}))
	K.register("ending", func(v, _ctx):
		ending_id = str(v)
		ending_requested.emit(ending_id))
	K.register("feed_survivors", func(_v, _ctx): _feed_survivors())
	K.register("evaluate_ending", func(_v, _ctx):
		ending_id = EndingDirector.evaluate()
		ending_requested.emit(ending_id))
