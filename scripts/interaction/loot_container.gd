class_name LootContainer
extends Interactable
## Searchable container (cabinet, car, shelf, body). The first search fills it from `items`
## (fixed contents) and `loot_table` (random, see LootTables); then the ContainerPanel lets the
## player take only what they need. Whatever is left stays inside (saved per container).
## Consequences, found_text and the search sound happen only on the first search.

@export var items: Dictionary = {}
## Id in data/loot/tables.json ("" = fixed contents only).
@export var loot_table: String = ""
@export_multiline var found_text: String = ""
@export var empty_text: String = "Пусто."
## Shown under the container title in the panel.
@export var container_hint: String = ""


func _init() -> void:
	interaction_text = "Обыскать"
	interaction_sound = "search"


func is_searched() -> bool:
	return get_state("contents", null) != null


func is_looted() -> bool:
	var c = get_state("contents", null)
	return c is Array and c.is_empty()


func get_interaction_text() -> String:
	if not is_searched():
		return interaction_text
	return "Пусто" if is_looted() else "Открыть"


## Stacks inside, rolling them on first access.
func get_contents() -> Array:
	var c = get_state("contents", null)
	if c is Array:
		return c
	var stacks: Array = []
	for id in items.keys():
		var item := Data.get_item(str(id))
		if item == null:
			continue
		if item.is_stackable():
			stacks.append({"id": str(id), "count": int(items[id])})
		else:
			for i in int(items[id]):
				stacks.append({"id": str(id), "count": 1})
	if not loot_table.is_empty():
		stacks.append_array(LootTables.roll(loot_table, persistent_id, TimeManager.current_day))
	set_state("contents", stacks)
	return stacks


func get_inventory() -> Inventory:
	var inv := Inventory.new(persistent_id, false)
	inv.deserialize({"slots": get_contents().duplicate(true)})
	return inv


func store_inventory(inv: Inventory) -> void:
	set_state("contents", inv.serialize().slots)


## Moves everything that fits into the backpack (tests, quick loot). Returns items moved.
func take_all() -> int:
	var first := not is_searched()
	var inv := get_inventory()
	var moved := StorageSystem.transfer_all(inv, GameState.inventory)
	store_inventory(inv)
	if first:
		Consequences.apply_all(consequences, _ctx())
	return moved


func _on_interact(_actor: Node) -> bool:
	var first := not is_searched()
	var inv := get_inventory()
	if first and not found_text.is_empty():
		GameState.notify(GameState.format_text(found_text))
	if inv.is_empty() and first:
		GameState.notify(empty_text)
	UIRoot.open_panel("container", {
		"title": display_name,
		"inventory": inv,
		"hint": container_hint if not inv.is_empty() else empty_text,
		"on_close": store_inventory,
	})
	if not first:
		AudioManager.play_sfx("rustle")
	# Consequences and the search sound only the first time.
	return first
