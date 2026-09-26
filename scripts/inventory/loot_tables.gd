class_name LootTables
extends RefCounted
## LootTables — rolls container contents from res://data/loot/tables.json.
##
## Table: {"rolls": [min, max], "quality": [poor, normal, good, excellent] weights,
##   "cond": [min, max] condition % for gear, "guaranteed": [entry...], "entries": [entry...]}
## Entry: {"id", "w" (weight), "n": [min, max], "day": first day it can appear,
##   "left": [min, max] share of charge left (filters)}; {"id": "nothing"} rolls nothing.
## Rolls are deterministic per container (seed = world seed + container id), so reloading a
## save never rerolls, and scale with WorldState resource availability and the day
## ("scarcity" in the table: roll count multiplier lost per day after the first).


static func roll(table_id: String, seed_key: String, day: int = 1) -> Array:
	var t := Data.get_loot_table(table_id)
	if t.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [seed_key, GameState.world_seed])
	var out: Array = []
	for e in t.get("guaranteed", []):
		_add(out, e, t, rng)
	var r: Array = t.get("rolls", [1, 2])
	var n := rng.randi_range(int(r[0]), int(r[1]))
	var scarcity := float(t.get("scarcity", 0.1))
	var avail := float(GameState.world.resource_availability.get(GameState.current_location, 1.0))
	var mult := maxf(0.3, avail * (1.0 - scarcity * maxi(0, day - 1)))
	n = int(round(n * mult))
	var pool: Array = []
	var total := 0.0
	for e in t.get("entries", []):
		if int(e.get("day", 1)) > day:
			continue
		if str(e.id) != "nothing" and not Data.has_item(str(e.id)):
			push_warning("LootTables: %s has unknown item '%s'" % [table_id, e.id])
			continue
		pool.append(e)
		total += float(e.get("w", 1.0))
	if pool.is_empty() or total <= 0.0:
		return out
	for i in n:
		var pick := rng.randf() * total
		for e in pool:
			pick -= float(e.get("w", 1.0))
			if pick <= 0.0:
				if str(e.id) != "nothing":
					_add(out, e, t, rng)
				break
	return _merge(out)


static func _add(out: Array, e: Dictionary, t: Dictionary, rng: RandomNumberGenerator) -> void:
	var item := Data.get_item(str(e.id))
	if item == null:
		return
	var nr: Array = e.get("n", [1, 1])
	var count := rng.randi_range(int(nr[0]), int(nr[1]))
	if count <= 0:
		return
	if not item.is_stackable():
		for i in count:
			out.append(_instance(item, e, t, rng))
		return
	var s := {"id": item.id, "count": count}
	if item.spoil_days > 0.0:
		# Found food is already partly old.
		s["data"] = {"exp": TimeManager.total_minutes + item.spoil_days * 1440.0 * rng.randf_range(0.3, 1.0)}
	out.append(s)


static func _instance(item: ItemData, e: Dictionary, t: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var s := {"id": item.id, "count": 1}
	if item.has_condition:
		var cr: Array = e.get("cond", t.get("cond", [35, 95]))
		s["cond"] = float(rng.randi_range(int(cr[0]), int(cr[1])))
		s["q"] = _pick_quality(t.get("quality", [30, 50, 15, 5]), rng)
	if item.is_filter() and e.has("left"):
		var lr: Array = e.left
		s["data"] = {"left": snappedf(item.filter_capacity * rng.randf_range(float(lr[0]), float(lr[1])), 0.1)}
	return s


static func _pick_quality(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var pick := rng.randf() * total
	for i in weights.size():
		pick -= float(weights[i])
		if pick <= 0.0:
			return i
	return 1


## Folds repeated stackable rolls into full stacks.
static func _merge(stacks: Array) -> Array:
	var out: Array = []
	for s in stacks:
		var item := Data.get_item(str(s.id))
		var merged := false
		if item and item.is_stackable() and not s.has("data"):
			for o in out:
				if o.id == s.id and not o.has("data") and int(o.count) + int(s.count) <= item.stack_size:
					o.count = int(o.count) + int(s.count)
					merged = true
					break
		if not merged:
			out.append(s)
	return out
