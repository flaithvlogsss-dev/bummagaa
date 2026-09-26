extends TestCase
## Content integrity: every reference in data files must resolve, every condition and
## consequence key must be known. Catches typos in dialogues/quests/events before playtests.

const ID_KEYS_ITEM := ["item", "no_item", "storage_item", "item_total", "equipped", "give_item", "take_item", "give_storage", "take_storage"]
const ID_KEYS_NPC := ["npc_alive", "npc_dead", "npc_met", "npc_injured", "kill_npc"]


func _walk(v: Variant, where: String, out: Array) -> void:
	if v is Dictionary:
		out.append([v, where])
		for k in v.keys():
			_walk(v[k], where + "." + str(k), out)
	elif v is Array:
		for i in v.size():
			_walk(v[i], where + "[%d]" % i, out)


func _check_ref(key: String, value: Variant, where: String) -> void:
	var first: Variant = value[0] if value is Array and not value.is_empty() else value
	if key in ID_KEYS_ITEM and not Data.has_item(str(first)):
		fail("%s: unknown item '%s'" % [where, first])
	if key in ID_KEYS_NPC and str(first) != "self" and not Data.characters.has(str(first)):
		fail("%s: unknown npc '%s'" % [where, first])
	if key in ["npc_at", "npc_not_at", "memory", "tier_min", "tier_max", "npc_location", "npc_value", "npc_stat"] and value is Array:
		if str(value[0]) != "self" and not Data.characters.has(str(value[0])):
			fail("%s: unknown npc '%s'" % [where, value[0]])
	if key in ["info", "not_info", "add_info"] and not Data.information.has(str(first)):
		fail("%s: unknown information '%s'" % [where, first])
	if key in ["start_quest", "complete_quest", "quest_active", "quest_completed", "quest_not_started"] and not Data.quests.has(str(first)):
		fail("%s: unknown quest '%s'" % [where, first])
	if key in ["schedule_event", "trigger_event", "event_fired", "cancel_event"] and not Data.events.has(str(first)):
		fail("%s: unknown event '%s'" % [where, first])
	if key in ["start_dialogue", "dialogue_seen"] and not Data.dialogues.has(str(first)):
		fail("%s: unknown dialogue '%s'" % [where, first])
	if key == "radio_lock" and not Data.radio_signals.has(str(first)):
		fail("%s: unknown radio signal '%s'" % [where, first])


## Scans "conditions", "if", "requires", "condition", "available_if" as conditions and
## "consequences", "rewards", "on_complete", "use_effects" as consequences.
func _check_lists(root: Variant, where: String) -> void:
	var dicts: Array = []
	_walk(root, where, dicts)
	for entry in dicts:
		var d: Dictionary = entry[0]
		for k in d.keys():
			var list = d[k]
			var is_cond: bool = k in ["conditions", "if", "requires", "condition", "available_if", "auto_start"]
			var is_cons: bool = k in ["consequences", "rewards", "on_complete", "use_effects"]
			if not (is_cond or is_cons):
				continue
			var items: Array = list if list is Array else [list]
			for c in items:
				if not (c is Dictionary):
					continue
				for key in c.keys():
					if key == "if" and is_cons:
						continue
					var known := Conditions.has_handler(key) if is_cond else Consequences.has_handler(key)
					if not known:
						fail("%s.%s: unknown %s key '%s'" % [entry[1], k, "condition" if is_cond else "consequence", key])
					_check_ref(key, c[key], entry[1])


func test_dialogue_graphs() -> void:
	for id in Data.dialogues.keys():
		var d: Dictionary = Data.dialogues[id]
		var nodes: Dictionary = d.get("nodes", {})
		if not nodes.has(str(d.get("start", "start"))):
			fail("dialogue %s: missing start node" % id)
		for nid in nodes.keys():
			var n: Dictionary = nodes[nid]
			var targets: Array = []
			if n.has("next"):
				targets.append(n.next)
			for c in n.get("choices", []):
				targets.append(c.get("next", "end"))
			for b in n.get("branch", []):
				targets.append(b.get("next", "end"))
			for t in targets:
				if str(t) != "end" and not nodes.has(str(t)):
					fail("dialogue %s.%s: next '%s' does not exist" % [id, nid, t])
			var sp := str(n.get("speaker", ""))
			if not sp.is_empty() and not sp in ["narrator", "player", "radio", "self"] and not Data.characters.has(sp):
				fail("dialogue %s.%s: unknown speaker '%s'" % [id, nid, sp])
		_check_lists(d, "dialogue " + id)


func test_quests_events_radio_references() -> void:
	for id in Data.quests.keys():
		_check_lists(Data.quests[id], "quest " + id)
	for id in Data.events.keys():
		var e: Dictionary = Data.events[id]
		_check_lists(e, "event " + id)
		if e.has("dialogue") and not Data.dialogues.has(str(e.dialogue)):
			fail("event %s: unknown dialogue %s" % [id, e.dialogue])
	for id in Data.radio_signals.keys():
		var s: Dictionary = Data.radio_signals[id]
		_check_lists(s, "radio " + id)
		if s.has("info") and not Data.information.has(str(s.info)):
			fail("radio %s: unknown info %s" % [id, s.info])
	_check_lists(Data.get_world_table("endings"), "endings")
	_check_lists(Data.get_world_table("shelter_upgrades"), "shelter_upgrades")


func test_items_recipes_characters() -> void:
	assert_true(Data.items.size() >= 90, "at least 90 items")
	var icons := {}
	for id in Data.items.keys():
		var it: ItemData = Data.items[id]
		assert_eq(it.id, id, "item id matches its row")
		assert_true(not it.name.is_empty(), "item %s has a name" % id)
		assert_true(not it.description.is_empty(), "item %s has a description" % id)
		assert_true(ItemData.CATEGORY_NAMES.has(it.category), "item %s category %s" % [id, it.category])
		assert_true(IconArt.has_template(it.icon_shape), "item %s icon template %s" % [id, it.icon_shape])
		var parts := it.icon_shape.split("+")
		if parts.size() > 1:
			assert_true(IconArt.has_badge(parts[1]), "item %s icon badge %s" % [id, parts[1]])
		var icon_key := "%s|%s" % [it.icon_shape, str(it.icon_colors)]
		assert_false(icons.has(icon_key), "item %s has the same icon as %s" % [id, icons.get(icon_key, "")])
		icons[icon_key] = id
		if it.is_equippable():
			assert_true(it.equip_slot in Inventory.EQUIP_SLOTS, "item %s slot %s" % [id, it.equip_slot])
		if it is WeaponData and (it as WeaponData).is_firearm():
			assert_true(Data.has_item((it as WeaponData).ammo_type), "weapon %s ammo" % id)
		if it.equip_slot == "backpack":
			assert_gt(it.backpack_capacity, 0.0, "backpack %s capacity" % id)
		if it.is_filter():
			assert_gt(it.filter_efficiency, 0.0, "filter %s efficiency" % id)
		if it.equip_slot == "mask":
			assert_gt(it.mask_efficiency, 0.0, "mask %s efficiency" % id)
		_check_lists({"use_effects": it.use_effects}, "item " + id)
	for t in Data.loot_tables.keys():
		var table: Dictionary = Data.loot_tables[t]
		for e in table.get("entries", []) + table.get("guaranteed", []):
			assert_true(str(e.id) == "nothing" or Data.has_item(str(e.id)), "loot table %s item %s" % [t, e.id])
	for id in Data.recipes.keys():
		var r: RecipeData = Data.recipes[id]
		assert_true(Data.has_item(r.result_item), "recipe %s result exists" % id)
		for ing in r.ingredients.keys():
			assert_true(Data.has_item(str(ing)), "recipe %s ingredient %s exists" % [id, ing])
	for id in ["mara", "elias", "tomas", "vera", "anton", "grey"]:
		var c := Data.get_character(id)
		assert_true(c != null, "character %s exists" % id)
		if c:
			assert_true(Data.dialogues.has(c.dialogue_id), "character %s dialogue exists" % id)
	assert_true(Data.radio_signals.size() >= 5, "at least 5 radio signals")
	assert_true(Data.quests.size() >= 5, "at least 5 quests")


func test_level_interactables_reference_valid_data() -> void:
	for path in ["res://scenes/world/District.tscn", "res://scenes/shelter/Shelter.tscn"]:
		var root: Node = load(path).instantiate()
		var stack: Array = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n is LootContainer:
				for id in n.items.keys():
					assert_true(Data.has_item(str(id)), "%s: loot item %s" % [n.name, id])
				if not n.loot_table.is_empty():
					assert_true(Data.loot_tables.has(n.loot_table), "%s: loot table %s" % [n.name, n.loot_table])
			if n is ItemPickup:
				assert_true(Data.has_item(n.item_id), "%s: pickup item %s" % [n.name, n.item_id])
			if n is InfoPickup:
				assert_true(Data.information.has(n.info_id), "%s: info %s" % [n.name, n.info_id])
			if n is Examine and not n.dialogue_id.is_empty():
				assert_true(Data.dialogues.has(n.dialogue_id), "%s: dialogue %s" % [n.name, n.dialogue_id])
			if n is Interactable:
				_check_lists({"conditions": n.conditions, "available_if": n.available_if, "consequences": n.consequences}, path + ":" + n.name)
		root.free()


func test_validator_detects_errors() -> void:
	var before := failures.size()
	_check_lists({"conditions": [{"bogus_key": 1}], "consequences": [{"give_item": ["no_such_item", 1]}]}, "selftest")
	var found := failures.size() - before
	failures.resize(before)
	assert_eq(found, 2, "validator must report both injected errors")
