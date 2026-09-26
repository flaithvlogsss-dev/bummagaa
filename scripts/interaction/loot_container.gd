class_name LootContainer
extends Interactable
## Searchable container (cabinet, car, shelf). Everything inside goes to the backpack.
## Consequences run only on the first successful search.

@export var items: Dictionary = {}
@export_multiline var found_text: String = ""
@export var empty_text: String = "Пусто."


func _init() -> void:
	interaction_text = "Обыскать"
	interaction_sound = "search"


func is_looted() -> bool:
	return bool(get_state("looted", false))


func get_interaction_text() -> String:
	return interaction_text + (" (пусто)" if is_looted() else "")


func _on_interact(_actor: Node) -> bool:
	if is_looted():
		GameState.notify(empty_text)
		return false
	set_state("looted", true)
	if not found_text.is_empty():
		GameState.notify(GameState.format_text(found_text))
	if items.is_empty():
		GameState.notify(empty_text)
	for id in items.keys():
		var n := int(items[id])
		if GameState.inventory.add(str(id), n) > 0:
			GameState.notify("+%d %s" % [n, Data.get_item_name(str(id))], "item")
	return true
