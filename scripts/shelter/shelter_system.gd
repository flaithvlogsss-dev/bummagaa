class_name ShelterSystem
extends RefCounted
## ShelterSystem — shelter upgrades (data/world/shelter_upgrades.json).
##
## Purpose: Level 1 shelter → 2 workshop → 3 radio station. Each level lists a cost, extra
##   conditions (with a narrative hint) and consequences.
## Dependencies: Data, GameState, CraftingSystem (resource counting), Conditions, Consequences.
## Public API: next_level(), level_info(level), missing(level), can_upgrade(), upgrade()


static func level_info(level: int) -> Dictionary:
	var table: Dictionary = Data.get_world_table("shelter_upgrades")
	return table.get("levels", {}).get(str(level), {})


static func next_level() -> int:
	var n := GameState.shelter_level + 1
	return n if not level_info(n).is_empty() else -1


static func missing(level: int) -> Dictionary:
	var out := {}
	var cost: Dictionary = level_info(level).get("cost", {})
	for id in cost.keys():
		var have := CraftingSystem.available_count(str(id))
		if have < int(cost[id]):
			out[str(id)] = int(cost[id]) - have
	return out


static func conditions_met(level: int) -> bool:
	return Conditions.check_all(level_info(level).get("conditions", []))


static func can_upgrade() -> bool:
	var n := next_level()
	return n > 0 and missing(n).is_empty() and conditions_met(n)


static func upgrade() -> bool:
	if not can_upgrade():
		return false
	var n := next_level()
	var info := level_info(n)
	var cost: Dictionary = info.get("cost", {})
	for id in cost.keys():
		var need := int(cost[id])
		var from_bag := mini(need, GameState.inventory.count(str(id)))
		if from_bag > 0:
			GameState.inventory.remove(str(id), from_bag)
		if need - from_bag > 0:
			GameState.storage.remove(str(id), need - from_bag)
	TimeManager.advance_minutes(int(info.get("minutes", 60)))
	GameState.set_shelter_level(n)
	Consequences.apply_all(info.get("consequences", []))
	return true
