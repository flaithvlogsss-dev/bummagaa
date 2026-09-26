class_name CraftingSystem
extends RefCounted
## CraftingSystem — validates and executes RecipeData.
##
## Purpose: ingredients are taken from the backpack first, then from shelter storage (you craft
##   at home). Crafting spends game time. Lock reasons are human-readable, never numbers.
## Dependencies: Data, GameState (inventory, storage, shelter level), TimeManager, Conditions.
## Public API: get_recipes(station), is_unlocked(recipe), lock_reason(recipe),
##   available_count(item), missing(recipe), can_craft(recipe), craft(recipe)


static func get_recipes(station: String = "") -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for id in Data.recipes.keys():
		var r: RecipeData = Data.recipes[id]
		if station.is_empty() or r.required_station == station:
			out.append(r)
	out.sort_custom(func(a, b): return a.required_shelter_level < b.required_shelter_level or (a.required_shelter_level == b.required_shelter_level and a.name < b.name))
	return out


static func is_unlocked(recipe: RecipeData) -> bool:
	return GameState.shelter_level >= recipe.required_shelter_level and Conditions.check_all(recipe.conditions)


static func lock_reason(recipe: RecipeData) -> String:
	if GameState.shelter_level < recipe.required_shelter_level:
		return "Нужна мастерская (уровень убежища %d)" % recipe.required_shelter_level
	if not Conditions.check_all(recipe.conditions):
		return "Нужны подходящие условия"
	return ""


static func available_count(item_id: String, use_storage: bool = true) -> int:
	return GameState.inventory.count(item_id) + (GameState.storage.count(item_id) if use_storage else 0)


## item_id -> how many are still missing.
static func missing(recipe: RecipeData, use_storage: bool = true) -> Dictionary:
	var out := {}
	for id in recipe.ingredients.keys():
		var need := int(recipe.ingredients[id])
		var have := available_count(str(id), use_storage)
		if have < need:
			out[str(id)] = need - have
	return out


static func can_craft(recipe: RecipeData, use_storage: bool = true) -> bool:
	return recipe != null and is_unlocked(recipe) and missing(recipe, use_storage).is_empty() and Data.has_item(recipe.result_item)


static func craft(recipe: RecipeData, use_storage: bool = true) -> bool:
	if not can_craft(recipe, use_storage):
		return false
	for id in recipe.ingredients.keys():
		var need := int(recipe.ingredients[id])
		var from_bag := mini(need, GameState.inventory.count(str(id)))
		if from_bag > 0:
			GameState.inventory.remove(str(id), from_bag)
		if need - from_bag > 0:
			GameState.storage.remove(str(id), need - from_bag)
	GameState.inventory.add(recipe.result_item, recipe.result_count)
	if recipe.crafting_time > 0:
		TimeManager.advance_minutes(recipe.crafting_time)
	GameState.set_flag("crafted_" + recipe.id, true)
	GameState.set_flag("crafted_any", true)
	return true
