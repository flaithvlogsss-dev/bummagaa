class_name RelationshipSystem
extends RefCounted
## RelationshipSystem — how each character feels about the player.
##
## Purpose: four axes per NPC (trust, fear, respect, affinity), each -100..100.
##   The UI never shows numbers, only a tier word (distrustful .. loyal).
## Dependencies: none.
## Public API: ensure, get_value, change, set_value, get_score, get_tier, get_tier_name
## Signals: relationship_changed(npc_id, stat, value), tier_changed(npc_id, tier)
## Save Data: {npc_id: {trust, fear, respect, affinity}}

signal relationship_changed(npc_id: String, stat: String, value: float)
signal tier_changed(npc_id: String, tier: String)

const STATS: Array[String] = ["trust", "fear", "respect", "affinity"]
const TIERS: Array[String] = ["distrustful", "neutral", "cooperative", "trusted", "loyal"]
const TIER_NAMES := {
	"distrustful": "Недоверие",
	"neutral": "Нейтрально",
	"cooperative": "Сотрудничество",
	"trusted": "Доверие",
	"loyal": "Преданность",
}

var _data: Dictionary = {}


func ensure(npc_id: String, initial: Dictionary = {}) -> void:
	if _data.has(npc_id):
		return
	var rel := {}
	for s in STATS:
		rel[s] = clampf(float(initial.get(s, 0.0)), -100.0, 100.0)
	_data[npc_id] = rel


func has_npc(npc_id: String) -> bool:
	return _data.has(npc_id)


func get_value(npc_id: String, stat: String) -> float:
	if not _data.has(npc_id):
		return 0.0
	return float(_data[npc_id].get(stat, 0.0))


func set_value(npc_id: String, stat: String, value: float) -> void:
	if not stat in STATS:
		push_warning("RelationshipSystem: unknown stat '%s'" % stat)
		return
	ensure(npc_id)
	var old_tier := get_tier(npc_id)
	_data[npc_id][stat] = clampf(value, -100.0, 100.0)
	relationship_changed.emit(npc_id, stat, _data[npc_id][stat])
	var new_tier := get_tier(npc_id)
	if new_tier != old_tier:
		tier_changed.emit(npc_id, new_tier)


func change(npc_id: String, stat: String, delta: float) -> float:
	set_value(npc_id, stat, get_value(npc_id, stat) + delta)
	return get_value(npc_id, stat)


## Weighted blend used for tiers. Fear only hurts once it dominates.
func get_score(npc_id: String) -> float:
	var trust := get_value(npc_id, "trust")
	var affinity := get_value(npc_id, "affinity")
	var respect := get_value(npc_id, "respect")
	var fear := get_value(npc_id, "fear")
	return trust * 0.5 + affinity * 0.3 + respect * 0.2 - maxf(0.0, fear - 30.0) * 0.4


func get_tier(npc_id: String) -> String:
	var s := get_score(npc_id)
	if s < -20.0:
		return "distrustful"
	if s < 12.0:
		return "neutral"
	if s < 30.0:
		return "cooperative"
	if s < 55.0:
		return "trusted"
	return "loyal"


func get_tier_name(npc_id: String) -> String:
	return TIER_NAMES.get(get_tier(npc_id), "?")


static func tier_rank(tier: String) -> int:
	return TIERS.find(tier)


func clear() -> void:
	_data.clear()


func serialize() -> Dictionary:
	return _data.duplicate(true)


func deserialize(d: Dictionary) -> void:
	for npc_id in d.keys():
		ensure(str(npc_id))
		var rel: Dictionary = d[npc_id] if d[npc_id] is Dictionary else {}
		for s in STATS:
			if rel.has(s):
				_data[str(npc_id)][s] = clampf(float(rel[s]), -100.0, 100.0)
