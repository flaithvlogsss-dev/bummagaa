class_name Inventory
extends RefCounted
## Inventory — modular item container (player backpack, shelter storage, loot).
##
## Purpose: stores item ids with counts, equipment slots and weight.
## Dependencies: Data (item definitions), Consequences (item use effects).
## Public API: add, remove, count, has_item, consume, equip, unequip, is_equipped,
##   get_entries, get_total_weight, is_overweight, clear, serialize, deserialize
## Signals: item_added, item_removed, equipment_changed, changed
## Save Data: {"items": [[id, count], ...], "equipped": {slot: id}}

signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal equipment_changed(slot: String, item_id: String)
signal changed

var inventory_name: String = ""
## Soft limit: exceeding it slows the carrier instead of blocking pickups.
var max_weight: float = 0.0
var equipped: Dictionary = {}

var _counts: Dictionary = {}
var _order: Array[String] = []


func _init(p_name: String = "", p_max_weight: float = 0.0) -> void:
	inventory_name = p_name
	max_weight = p_max_weight


func add(item_id: String, amount: int = 1, silent: bool = false) -> int:
	if amount <= 0:
		return 0
	if not Data.has_item(item_id):
		push_warning("Inventory(%s).add: unknown item '%s'" % [inventory_name, item_id])
		return 0
	if not _counts.has(item_id):
		_counts[item_id] = 0
		_order.append(item_id)
	_counts[item_id] += amount
	if not silent:
		item_added.emit(item_id, amount)
		changed.emit()
	return amount


## Removes exactly `amount` or nothing. Returns true on success.
func remove(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if count(item_id) < amount:
		return false
	_counts[item_id] -= amount
	if _counts[item_id] <= 0:
		_counts.erase(item_id)
		_order.erase(item_id)
		for slot in equipped.keys():
			if equipped[slot] == item_id:
				unequip(slot)
	item_removed.emit(item_id, amount)
	changed.emit()
	return true


func count(item_id: String) -> int:
	return int(_counts.get(item_id, 0))


func has_item(item_id: String, amount: int = 1) -> bool:
	return count(item_id) >= amount


func count_category(category: String) -> int:
	var total := 0
	for id in _order:
		var item := Data.get_item(id)
		if item and item.category == category:
			total += count(id)
	return total


## Uses one item: equipment toggles, consumables apply their use_effects and are removed.
func consume(item_id: String, ctx: Dictionary = {}) -> bool:
	var item := Data.get_item(item_id)
	if item == null or not has_item(item_id):
		return false
	if item.is_equippable():
		if is_equipped(item_id):
			unequip(item.equip_slot)
		else:
			equip(item_id)
		return true
	if not item.usable:
		return false
	var context := ctx.duplicate()
	context["item"] = item_id
	remove(item_id, 1)
	Consequences.apply_all(item.use_effects, context)
	return true


func equip(item_id: String) -> bool:
	var item := Data.get_item(item_id)
	if item == null or not item.is_equippable() or not has_item(item_id):
		return false
	equipped[item.equip_slot] = item_id
	equipment_changed.emit(item.equip_slot, item_id)
	changed.emit()
	return true


func unequip(slot: String) -> void:
	if not equipped.has(slot):
		return
	equipped.erase(slot)
	equipment_changed.emit(slot, "")
	changed.emit()


func is_equipped(item_id: String) -> bool:
	return equipped.values().has(item_id)


func get_equipped(slot: String) -> String:
	return str(equipped.get(slot, ""))


## Sum of insulation of equipped items (clamped to 0.85).
func get_insulation() -> float:
	var total := 0.0
	for id in equipped.values():
		var item := Data.get_item(id)
		if item:
			total += item.insulation
	return minf(total, 0.85)


## Returns [{id, count, item}] in pickup order.
func get_entries() -> Array:
	var out: Array = []
	for id in _order:
		out.append({"id": id, "count": count(id), "item": Data.get_item(id)})
	return out


func get_ids() -> Array[String]:
	return _order.duplicate()


func get_total_weight() -> float:
	var total := 0.0
	for id in _order:
		var item := Data.get_item(id)
		if item:
			total += item.weight * count(id)
	return total


func is_overweight() -> bool:
	return max_weight > 0.0 and get_total_weight() > max_weight


func is_empty() -> bool:
	return _order.is_empty()


func clear() -> void:
	_counts.clear()
	_order.clear()
	equipped.clear()
	changed.emit()


func serialize() -> Dictionary:
	var list: Array = []
	for id in _order:
		list.append([id, count(id)])
	return {"items": list, "equipped": equipped.duplicate()}


## Unknown items (e.g. removed from the game since the save was made) are skipped.
func deserialize(data: Dictionary) -> void:
	_counts.clear()
	_order.clear()
	equipped.clear()
	for entry in data.get("items", []):
		if entry is Array and entry.size() >= 2:
			add(str(entry[0]), int(entry[1]), true)
	var eq: Dictionary = data.get("equipped", {})
	for slot in eq.keys():
		if has_item(str(eq[slot])):
			equipped[str(slot)] = str(eq[slot])
	changed.emit()
