class_name Inventory
extends RefCounted
## Inventory — slot-based item container (player pockets + backpack, shelter storage, loot).
##
## A stack is a Dictionary {"id", "count", "cond" (0..100, gear only), "q" (quality 0..3),
##   "data" (per-instance extras: mask filter, weapon magazine, food expiry, filter charge)}.
## A limited inventory (the player) has BASE_SLOTS pockets + the equipped backpack's slots and
##   a carry limit of BASE_WEIGHT + backpack capacity. An unlimited one (storage, containers)
##   grows as needed. Equipped items live in `equipped`, take no grid slot and worn clothing
##   weighs nothing, but everything counts for count()/has_item().
## Dependencies: Data (item definitions), Consequences (use effects), TimeManager (spoilage).
## Public API: add, add_stack, can_fit, remove, take, take_at, count, has_item, consume, use_at,
##   equip, equip_at, unequip, is_equipped, get_equipped, get_equipped_stack, get_slots,
##   get_entries, move_slot, split_at, sort, set_quick, tick_spoilage, damage_equipped,
##   get_total_weight, is_overweight, serialize, deserialize
## Signals: item_added, item_removed, equipment_changed, changed
## Save Data: {"slots": [stack|{}...], "equipped": {slot: stack}, "quick": [id x5]}

signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal equipment_changed(slot: String, item_id: String)
signal changed

const EQUIP_SLOTS: Array[String] = ["head", "mask", "body", "backpack", "weapon", "secondary", "utility"]
const SLOT_NAMES := {
	"head": "Голова", "mask": "Маска", "body": "Тело", "backpack": "Рюкзак",
	"weapon": "Оружие", "secondary": "Запасное", "utility": "Снаряжение",
}
const BASE_WEIGHT := 4.0
const BASE_SLOTS := 6
const QUICK_SLOTS := 5
## Old (v1) equipment slot names.
const LEGACY_SLOTS := {"hand": "weapon", "face": "mask"}

var inventory_name: String = ""
## true: pockets + backpack limits (player). false: unlimited (storage, containers).
var limited: bool = false
## Grid stacks; {} marks an empty slot.
var slots: Array = []
## slot name -> stack
var equipped: Dictionary = {}
## Item ids bound to keys 1..5.
var quick: Array = ["", "", "", "", ""]
## Carry limit in kg (0 = unlimited).
var max_weight: float:
	get:
		return get_max_weight()


func _init(p_name: String = "", p_limited: bool = false) -> void:
	inventory_name = p_name
	limited = p_limited
	_resize()


# --- Capacity --------------------------------------------------------------------------------

func get_max_weight() -> float:
	if not limited:
		return 0.0
	var pack := get_equipped_item("backpack")
	return BASE_WEIGHT + (pack.backpack_capacity * _quality_mult(equipped.backpack) if pack else 0.0)


func slot_count() -> int:
	if not limited:
		return slots.size()
	var pack := get_equipped_item("backpack")
	return BASE_SLOTS + (pack.backpack_slots if pack else 0)


func free_slots() -> int:
	var n := 0
	for s in slots:
		if s.is_empty():
			n += 1
	return n


func used_slots() -> int:
	return slots.size() - free_slots()


func get_total_weight() -> float:
	var total := 0.0
	for s in slots:
		total += stack_weight(s)
	for slot in equipped.keys():
		var item := Data.get_item(equipped[slot].id)
		if item and not item.is_worn():
			total += item.weight
	return total


func is_overweight() -> bool:
	return limited and get_total_weight() > get_max_weight() + 0.001


func is_empty() -> bool:
	return used_slots() == 0


static func stack_weight(s: Dictionary) -> float:
	if s.is_empty():
		return 0.0
	var item := Data.get_item(s.id)
	return item.weight * int(s.count) if item else 0.0


## How many of `item_id` would fit (slots and weight), up to `amount`.
func can_fit(item_id: String, amount: int = 1, props: Dictionary = {}) -> int:
	var item := Data.get_item(item_id)
	if item == null or amount <= 0:
		return 0
	if not limited:
		return amount
	var by_weight := amount
	if item.weight > 0.0:
		by_weight = int(floor((get_max_weight() - get_total_weight() + 0.0001) / item.weight))
	var room := 0
	var probe := _new_stack(item, 1, props)
	for s in slots:
		if s.is_empty():
			room += item.stack_size if item.is_stackable() else 1
		elif _can_merge(s, probe):
			room += item.stack_size - int(s.count)
	return clampi(mini(by_weight, room), 0, amount)


# --- Adding ----------------------------------------------------------------------------------------

## Adds up to `amount` items and returns how many were added (limited inventories may take
## fewer). props: {"cond", "q", "data"} for the new stack(s).
func add(item_id: String, amount: int = 1, silent: bool = false, props: Dictionary = {}) -> int:
	if amount <= 0:
		return 0
	var item := Data.get_item(item_id)
	if item == null:
		push_warning("Inventory(%s).add: unknown item '%s'" % [inventory_name, item_id])
		return 0
	var n := can_fit(item_id, amount, props)
	if n <= 0:
		return 0
	var left := n
	var probe := _new_stack(item, 1, props)
	if item.is_stackable():
		for s in slots:
			if left <= 0:
				break
			if not s.is_empty() and _can_merge(s, probe):
				var put := mini(left, item.stack_size - int(s.count))
				s.count = int(s.count) + put
				_merge_data(s, probe)
				left -= put
	while left > 0:
		var idx := _free_index()
		if idx < 0:
			break
		var put := mini(left, item.stack_size if item.is_stackable() else 1)
		slots[idx] = _new_stack(item, put, props)
		left -= put
	var added := n - left
	if added > 0 and not silent:
		item_added.emit(item_id, added)
	if added > 0:
		changed.emit()
	return added


## Adds a whole stack keeping its condition/quality/data. Returns how many were added.
func add_stack(stack: Dictionary, silent: bool = false) -> int:
	if stack.is_empty():
		return 0
	var props := {}
	for k in ["cond", "q", "data"]:
		if stack.has(k):
			props[k] = stack[k] if not (stack[k] is Dictionary) else stack[k].duplicate(true)
	return add(str(stack.id), int(stack.count), silent, props)


func _free_index() -> int:
	for i in slots.size():
		if slots[i].is_empty():
			return i
	if not limited:
		slots.append({})
		return slots.size() - 1
	return -1


func _new_stack(item: ItemData, count: int, props: Dictionary) -> Dictionary:
	var s := {"id": item.id, "count": count}
	if item.has_condition:
		s["cond"] = float(props.get("cond", 100.0))
		s["q"] = int(props.get("q", 1))
	var data: Dictionary = props.get("data", {}).duplicate(true)
	if item.spoil_days > 0.0 and not data.has("exp"):
		data["exp"] = TimeManager.total_minutes + item.spoil_days * 1440.0
	if item is WeaponData and (item as WeaponData).is_firearm() and not data.has("mag"):
		data["mag"] = 0
	if not data.is_empty():
		s["data"] = data
	return s


## Stacks merge when they are the same stackable item and carry no unique data
## (food expiry merges to the earliest date).
func _can_merge(a: Dictionary, b: Dictionary) -> bool:
	if a.id != b.id:
		return false
	var item := Data.get_item(a.id)
	if item == null or not item.is_stackable() or int(a.count) >= item.stack_size:
		return false
	var da: Dictionary = a.get("data", {})
	var db: Dictionary = b.get("data", {})
	for k in da.keys():
		if k != "exp" and (not db.has(k) or not Conditions.values_equal(da[k], db[k])):
			return false
	for k in db.keys():
		if k != "exp" and not da.has(k):
			return false
	return true


func _merge_data(into: Dictionary, other: Dictionary) -> void:
	var db: Dictionary = other.get("data", {})
	if db.has("exp"):
		var d: Dictionary = into.get("data", {})
		d["exp"] = minf(float(d.get("exp", db.exp)), float(db.exp))
		into["data"] = d


# --- Removing ------------------------------------------------------------------------------------

## Removes exactly `amount` (grid first, then equipped) or nothing. Returns true on success.
func remove(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if count(item_id) < amount:
		return false
	take(item_id, amount)
	return true


## Removes up to `amount` and returns the removed stacks (keeping their instance data).
func take(item_id: String, amount: int = 1) -> Array:
	var out: Array = []
	var left := amount
	for i in range(slots.size() - 1, -1, -1):
		if left <= 0:
			break
		var s: Dictionary = slots[i]
		if s.is_empty() or s.id != item_id:
			continue
		var n := mini(left, int(s.count))
		out.append(_split_off(i, n))
		left -= n
	for slot in EQUIP_SLOTS:
		if left <= 0:
			break
		if equipped.has(slot) and equipped[slot].id == item_id:
			out.append(equipped[slot])
			equipped.erase(slot)
			left -= 1
			equipment_changed.emit(slot, "")
	var taken := amount - left
	if taken > 0:
		_compact_if_unlimited()
		item_removed.emit(item_id, taken)
		changed.emit()
	return out


## Removes `amount` (-1 = all) from grid slot `index`. Returns the removed stack.
func take_at(index: int, amount: int = -1) -> Dictionary:
	if index < 0 or index >= slots.size() or slots[index].is_empty():
		return {}
	var s: Dictionary = slots[index]
	var n := int(s.count) if amount < 0 else mini(amount, int(s.count))
	var out := _split_off(index, n)
	_compact_if_unlimited()
	item_removed.emit(str(out.id), n)
	changed.emit()
	return out


func _split_off(index: int, n: int) -> Dictionary:
	var s: Dictionary = slots[index]
	if n >= int(s.count):
		slots[index] = {}
		return s
	s.count = int(s.count) - n
	var part := s.duplicate(true)
	part.count = n
	return part


func _compact_if_unlimited() -> void:
	if limited:
		return
	var kept: Array = []
	for s in slots:
		if not s.is_empty():
			kept.append(s)
	slots = kept


# --- Queries -------------------------------------------------------------------------------------

func count(item_id: String) -> int:
	var n := count_in_grid(item_id)
	for slot in equipped.keys():
		if equipped[slot].id == item_id:
			n += 1
	return n


func count_in_grid(item_id: String) -> int:
	var n := 0
	for s in slots:
		if not s.is_empty() and s.id == item_id:
			n += int(s.count)
	return n


func has_item(item_id: String, amount: int = 1) -> bool:
	return count(item_id) >= amount


func has_tag(tag: String) -> bool:
	for id in get_ids():
		var item := Data.get_item(id)
		if item and item.has_tag(tag):
			return true
	for slot in equipped.keys():
		var item := Data.get_item(equipped[slot].id)
		if item and item.has_tag(tag):
			return true
	return false


func count_category(category: String) -> int:
	var total := 0
	for s in slots:
		if s.is_empty():
			continue
		var item := Data.get_item(s.id)
		if item and item.category == category:
			total += int(s.count)
	return total


func find_index(item_id: String) -> int:
	for i in slots.size():
		if not slots[i].is_empty() and slots[i].id == item_id:
			return i
	return -1


func get_slot(index: int) -> Dictionary:
	return slots[index] if index >= 0 and index < slots.size() else {}


## Grid stacks including empty slots ({}).
func get_slots() -> Array:
	return slots


## Aggregated grid contents [{id, count, item}] in first-seen order.
func get_entries() -> Array:
	var order: Array = []
	var counts := {}
	for s in slots:
		if s.is_empty():
			continue
		if not counts.has(s.id):
			order.append(s.id)
			counts[s.id] = 0
		counts[s.id] += int(s.count)
	var out: Array = []
	for id in order:
		out.append({"id": id, "count": counts[id], "item": Data.get_item(id)})
	return out


func get_ids() -> Array[String]:
	var out: Array[String] = []
	for s in slots:
		if not s.is_empty() and not out.has(str(s.id)):
			out.append(str(s.id))
	return out


# --- Using -----------------------------------------------------------------------------------------

## Uses one item by id: equipment toggles, consumables apply their use_effects.
func consume(item_id: String, ctx: Dictionary = {}) -> bool:
	var idx := find_index(item_id)
	if idx >= 0:
		return use_at(idx, ctx)
	for slot in equipped.keys():
		if equipped[slot].id == item_id:
			return unequip(slot)
	return false


func use_at(index: int, ctx: Dictionary = {}) -> bool:
	var s := get_slot(index)
	if s.is_empty():
		return false
	var item := Data.get_item(s.id)
	if item == null:
		return false
	if item.is_filter():
		return install_filter_at(index)
	if item.is_equippable() and not item.is_usable():
		return equip_at(index)
	if not item.is_usable():
		return false
	var context := ctx.duplicate()
	context["item"] = item.id
	context["stack"] = s.duplicate(true)
	if not item.keep_on_use:
		take_at(index, 1)
	Consequences.apply_all(item.use_effects, context)
	return true


# --- Equipment -------------------------------------------------------------------------------------

func equip(item_id: String) -> bool:
	var idx := find_index(item_id)
	return equip_at(idx) if idx >= 0 else false


## Moves one item from grid slot `index` to its equipment slot; whatever was there goes
## back to the same grid slot.
func equip_at(index: int, target_slot: String = "") -> bool:
	var s := get_slot(index)
	if s.is_empty():
		return false
	var item := Data.get_item(s.id)
	if item == null or not item.is_equippable():
		return false
	var slot := target_slot if not target_slot.is_empty() else item.equip_slot
	if slot == "secondary" and item.equip_slot != "weapon":
		return false
	var one := _split_off(index, 1)
	var previous: Dictionary = equipped.get(slot, {})
	equipped[slot] = one
	if not previous.is_empty():
		if slots[index].is_empty():
			slots[index] = previous
		else:
			var idx := _free_index()
			if idx < 0:
				# No room for the swapped item: undo.
				equipped[slot] = previous
				_return_to(index, one)
				return false
			slots[idx] = previous
	if slot == "backpack" and not _fits_after_resize():
		equipped[slot] = previous
		if previous.is_empty():
			equipped.erase(slot)
		_remove_exact(previous)
		_return_to(index, one)
		GameState.notify("Всё не поместится в этот рюкзак — сначала выложи лишнее.", "warning")
		return false
	_resize()
	equipment_changed.emit(slot, str(one.id))
	changed.emit()
	return true


func _return_to(index: int, stack: Dictionary) -> void:
	if slots[index].is_empty():
		slots[index] = stack
	elif _can_merge(slots[index], stack):
		slots[index].count = int(slots[index].count) + int(stack.count)
	else:
		var idx := _free_index()
		if idx >= 0:
			slots[idx] = stack


func _remove_exact(stack: Dictionary) -> void:
	if stack.is_empty():
		return
	for i in slots.size():
		if slots[i] == stack:
			slots[i] = {}
			return


## Moves the equipped item back to the grid. Fails when there is no free slot.
func unequip(slot: String) -> bool:
	if not equipped.has(slot):
		return false
	var s: Dictionary = equipped[slot]
	equipped.erase(slot)
	if slot == "backpack":
		if used_slots() + 1 > slot_count():
			equipped[slot] = s
			GameState.notify("Без рюкзака всё не унести — сначала выложи лишнее.", "warning")
			return false
		_resize()
	var idx := _free_index()
	if idx < 0:
		equipped[slot] = s
		GameState.notify("Некуда положить — рюкзак полон.", "warning")
		return false
	slots[idx] = s
	equipment_changed.emit(slot, "")
	changed.emit()
	return true


## Destroys the equipped item (broken gear).
func destroy_equipped(slot: String) -> void:
	if not equipped.has(slot):
		return
	var id := str(equipped[slot].id)
	equipped.erase(slot)
	_resize()
	equipment_changed.emit(slot, "")
	item_removed.emit(id, 1)
	changed.emit()


func swap_weapons() -> bool:
	if not equipped.has("secondary"):
		return false
	var a: Dictionary = equipped.get("weapon", {})
	equipped["weapon"] = equipped["secondary"]
	if a.is_empty():
		equipped.erase("secondary")
	else:
		equipped["secondary"] = a
	equipment_changed.emit("weapon", get_equipped("weapon"))
	changed.emit()
	return true


func is_equipped(item_id: String) -> bool:
	for slot in equipped.keys():
		if equipped[slot].id == item_id:
			return true
	return false


func get_equipped(slot: String) -> String:
	slot = LEGACY_SLOTS.get(slot, slot)
	return str(equipped[slot].id) if equipped.has(slot) else ""


func get_equipped_stack(slot: String) -> Dictionary:
	return equipped.get(LEGACY_SLOTS.get(slot, slot), {})


func get_equipped_item(slot: String) -> ItemData:
	var id := get_equipped(slot)
	return Data.get_item(id) if not id.is_empty() else null


## Sum of insulation of worn clothing (quality and wear scale it), clamped to 0.85.
func get_insulation() -> float:
	var total := 0.0
	for slot in ["head", "body", "mask"]:
		var item := get_equipped_item(slot)
		if item:
			total += item.insulation * _quality_mult(equipped[slot]) * _wear_mult(equipped[slot])
	return minf(total, 0.85)


## Damage reduction from worn gear, 0..0.6.
func get_protection() -> float:
	var total := 0.0
	for slot in ["head", "body"]:
		var item := get_equipped_item(slot)
		if item:
			total += item.protection * _quality_mult(equipped[slot]) * _wear_mult(equipped[slot])
	return minf(total, 0.6)


## Wears the equipped item in `slot`. Returns true when it just broke.
func damage_equipped(slot: String, amount: float) -> bool:
	if not equipped.has(slot) or not equipped[slot].has("cond"):
		return false
	var s: Dictionary = equipped[slot]
	var before := float(s.cond)
	s.cond = maxf(0.0, before - amount)
	if before > 0.0 and s.cond <= 0.0:
		changed.emit()
		return true
	if int(before) != int(s.cond):
		changed.emit()
	return false


static func _quality_mult(s: Dictionary) -> float:
	return ItemData.QUALITY_MULT[clampi(int(s.get("q", 1)), 0, 3)]


static func _wear_mult(s: Dictionary) -> float:
	return 0.5 if s.has("cond") and float(s.cond) <= 0.0 else 1.0


# --- Gas mask filters ---------------------------------------------------------------------------

## Mask stack data: {"filter": item_id, "filter_left": minutes}. A partly used loose filter
## carries {"left": minutes}; an empty one becomes filter_spent.
func install_filter_at(index: int) -> bool:
	var s := get_slot(index)
	var f := Data.get_item(str(s.get("id", "")))
	if f == null or not f.is_filter():
		return false
	if not equipped.has("mask"):
		GameState.notify("Сначала надень маску.", "warning")
		return false
	var fresh := _split_off(index, 1)
	var left := float(fresh.get("data", {}).get("left", f.filter_capacity))
	var old := eject_filter(true)
	var mask: Dictionary = equipped.mask
	if not mask.has("data"):
		mask["data"] = {}
	mask.data["filter"] = f.id
	mask.data["filter_left"] = left
	if not old.is_empty():
		var idx := index if slots[index].is_empty() else _free_index()
		if idx >= 0:
			slots[idx] = old
		else:
			GameState.drop_stack(old)
	equipment_changed.emit("mask", str(mask.id))
	changed.emit()
	return true


## Takes the filter out of the equipped mask. Returns it as a stack (spent filters become
## filter_spent) or, unless `keep`, puts it into the grid.
func eject_filter(keep: bool = false) -> Dictionary:
	var mask: Dictionary = equipped.get("mask", {})
	var d: Dictionary = mask.get("data", {})
	if str(d.get("filter", "")).is_empty():
		return {}
	var f := Data.get_item(str(d.filter))
	var left := float(d.get("filter_left", 0.0))
	var out := {}
	if f == null or left <= 0.5:
		out = {"id": "filter_spent", "count": 1}
	elif left >= f.filter_capacity - 0.01:
		out = {"id": f.id, "count": 1}
	else:
		out = {"id": f.id, "count": 1, "data": {"left": snappedf(left, 0.1)}}
	d.erase("filter")
	d.erase("filter_left")
	if not keep:
		var idx := _free_index()
		if idx >= 0:
			slots[idx] = out
		else:
			GameState.drop_stack(out)
		equipment_changed.emit("mask", str(mask.id))
		changed.emit()
	return out


func get_mask_filter_left() -> float:
	return float(equipped.get("mask", {}).get("data", {}).get("filter_left", 0.0))


# --- Grid management -------------------------------------------------------------------------------

## Drag & drop inside the grid: merge, else swap.
func move_slot(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= slots.size() or to >= slots.size():
		return
	var a: Dictionary = slots[from]
	var b: Dictionary = slots[to]
	if a.is_empty():
		return
	if not b.is_empty() and _can_merge(b, a):
		var item := Data.get_item(a.id)
		var put := mini(int(a.count), item.stack_size - int(b.count))
		b.count = int(b.count) + put
		a.count = int(a.count) - put
		if int(a.count) <= 0:
			slots[from] = {}
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()


## Splits `amount` off a stack into a free slot. Returns the new index or -1.
func split_at(index: int, amount: int) -> int:
	var s := get_slot(index)
	if s.is_empty() or amount <= 0 or amount >= int(s.count):
		return -1
	var idx := _free_index()
	if idx < 0:
		return -1
	slots[idx] = _split_off(index, amount)
	changed.emit()
	return idx


const SORT_ORDER := ["Quest", "Weapon", "Ammunition", "Mask", "Medical", "Food", "Water", "Survival", "Tool", "Electronics", "Clothing", "Material", "Book"]


func sort() -> void:
	var stacks: Array = []
	for s in slots:
		if not s.is_empty():
			stacks.append(s)
	stacks.sort_custom(func(a, b):
		var ia := Data.get_item(a.id)
		var ib := Data.get_item(b.id)
		var ca := SORT_ORDER.find(ia.category) if ia else 99
		var cb := SORT_ORDER.find(ib.category) if ib else 99
		if ca != cb:
			return ca < cb
		return str(a.id) < str(b.id))
	# Merge partial stacks of the same item.
	var merged: Array = []
	for s in stacks:
		if not merged.is_empty() and _can_merge(merged[-1], s):
			var item := Data.get_item(s.id)
			var put := mini(int(s.count), item.stack_size - int(merged[-1].count))
			merged[-1].count = int(merged[-1].count) + put
			s.count = int(s.count) - put
			if int(s.count) <= 0:
				continue
		merged.append(s)
	while slots.size() < merged.size():
		slots.append({})
	for i in slots.size():
		slots[i] = merged[i] if i < merged.size() else {}
	if not limited:
		slots = merged
	changed.emit()


func _fits_after_resize() -> bool:
	return used_slots() <= slot_count()


## Resizes the grid to slot_count(), packing stacks forward if it shrinks.
func _resize() -> void:
	if not limited:
		return
	var n := slot_count()
	if slots.size() == n:
		return
	if slots.size() > n:
		var kept: Array = []
		for s in slots:
			if not s.is_empty():
				kept.append(s)
		slots = kept
	while slots.size() < n:
		slots.append({})


# --- Quick slots -------------------------------------------------------------------------------------

func set_quick(index: int, item_id: String) -> void:
	if index < 0 or index >= QUICK_SLOTS:
		return
	for i in QUICK_SLOTS:
		if quick[i] == item_id:
			quick[i] = ""
	quick[index] = item_id
	changed.emit()


func get_quick(index: int) -> String:
	return str(quick[index]) if index >= 0 and index < QUICK_SLOTS else ""


# --- Time ------------------------------------------------------------------------------------------------

## Turns expired food into spoiled_food. Returns the ids that spoiled.
func tick_spoilage(now_minutes: float) -> Array:
	var spoiled: Array = []
	for i in slots.size():
		var s: Dictionary = slots[i]
		if s.is_empty() or not s.has("data") or not s.data.has("exp"):
			continue
		if float(s.data.exp) <= now_minutes:
			spoiled.append(str(s.id))
			var n := int(s.count)
			slots[i] = {}
			if Data.has_item("spoiled_food"):
				slots[i] = {"id": "spoiled_food", "count": n}
	if not spoiled.is_empty():
		changed.emit()
	return spoiled


# --- Save / load ---------------------------------------------------------------------------------------

func clear() -> void:
	slots.clear()
	equipped.clear()
	quick = ["", "", "", "", ""]
	_resize()
	changed.emit()


func serialize() -> Dictionary:
	return {"slots": slots.duplicate(true), "equipped": equipped.duplicate(true), "quick": quick.duplicate()}


## Reads the v2 format and the v1 format ({"items": [[id, n]], "equipped": {slot: id}}).
## Unknown items (removed from the game since the save was made) are skipped.
func deserialize(data: Dictionary) -> void:
	slots.clear()
	equipped.clear()
	quick = ["", "", "", "", ""]
	var eq: Dictionary = data.get("equipped", {})
	for slot in eq.keys():
		var v = eq[slot]
		var stack: Dictionary = v if v is Dictionary else {"id": str(v), "count": 1}
		var key := str(LEGACY_SLOTS.get(str(slot), str(slot)))
		if Data.has_item(str(stack.get("id", ""))) and key in EQUIP_SLOTS:
			equipped[key] = _clean_stack(stack)
	_resize()
	if data.has("slots"):
		var list: Array = data.slots
		if not limited:
			for v in list:
				if v is Dictionary and not v.is_empty() and Data.has_item(str(v.get("id", ""))):
					slots.append(_clean_stack(v))
		else:
			# Keep positions; anything beyond the current capacity overflows into extra slots.
			for i in list.size():
				var v = list[i]
				if not (v is Dictionary) or v.is_empty() or not Data.has_item(str(v.get("id", ""))):
					continue
				if i < slots.size() and slots[i].is_empty():
					slots[i] = _clean_stack(v)
				else:
					slots.append(_clean_stack(v))
	else:
		var legacy_equipped := {}
		for slot in equipped.keys():
			legacy_equipped[equipped[slot].id] = true
		for entry in data.get("items", []):
			if entry is Array and entry.size() >= 2:
				var n := int(entry[1]) - (1 if legacy_equipped.has(str(entry[0])) else 0)
				if n > 0:
					_force_add(str(entry[0]), n)
	var q: Array = data.get("quick", [])
	for i in mini(q.size(), QUICK_SLOTS):
		quick[i] = str(q[i])
	changed.emit()


## Adds ignoring limits (loading old saves must never lose items); extra slots overflow.
func _force_add(item_id: String, amount: int) -> void:
	if not Data.has_item(item_id):
		return
	var was := limited
	limited = false
	add(item_id, amount, true)
	limited = was


func _clean_stack(v: Dictionary) -> Dictionary:
	var s := {"id": str(v.id), "count": maxi(1, int(v.get("count", 1)))}
	var item := Data.get_item(s.id)
	if item and item.has_condition:
		s["cond"] = clampf(float(v.get("cond", 100.0)), 0.0, 100.0)
		s["q"] = clampi(int(v.get("q", 1)), 0, 3)
	if v.has("data") and v.data is Dictionary and not v.data.is_empty():
		s["data"] = v.data.duplicate(true)
	return s
