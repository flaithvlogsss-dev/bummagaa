class_name StorageSystem
extends RefCounted
## StorageSystem — moves items between inventories (backpack <-> shelter storage).
## The shelter storage is a separate Inventory in GameState.storage and is saved with the game.


## Moves `amount` (or the whole stack when amount < 0). Returns how many were moved.
static func transfer(from: Inventory, to: Inventory, item_id: String, amount: int = 1) -> int:
	var n := from.count(item_id) if amount < 0 else mini(amount, from.count(item_id))
	if n <= 0:
		return 0
	if from.is_equipped(item_id) and n >= from.count(item_id):
		var item := Data.get_item(item_id)
		if item:
			from.unequip(item.equip_slot)
	if not from.remove(item_id, n):
		return 0
	to.add(item_id, n)
	return n
