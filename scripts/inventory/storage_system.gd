class_name StorageSystem
extends RefCounted
## StorageSystem — moves items between inventories (backpack <-> shelter storage <-> containers).
## Stacks keep their condition, quality and data. The target's limits (slots, weight) apply;
## whatever does not fit stays where it was.


## Moves `amount` of an item id from the grid (-1 = all of it). Returns how many were moved.
static func transfer(from: Inventory, to: Inventory, item_id: String, amount: int = 1) -> int:
	var have := from.count_in_grid(item_id)
	var n := have if amount < 0 else mini(amount, have)
	n = mini(n, to.can_fit(item_id, n))
	if n <= 0:
		return 0
	var moved := 0
	for stack in from.take(item_id, n):
		var added := to.add_stack(stack)
		moved += added
		if added < int(stack.count):
			var rest: Dictionary = stack.duplicate(true)
			rest.count = int(stack.count) - added
			from.add_stack(rest, true)
	return moved


## Moves `amount` (-1 = whole stack) from grid slot `index`. Returns how many were moved.
static func transfer_slot(from: Inventory, index: int, to: Inventory, amount: int = -1) -> int:
	var s := from.get_slot(index)
	if s.is_empty():
		return 0
	var n := int(s.count) if amount < 0 else mini(amount, int(s.count))
	var props := {}
	for k in ["cond", "q", "data"]:
		if s.has(k):
			props[k] = s[k]
	n = mini(n, to.can_fit(str(s.id), n, props))
	if n <= 0:
		return 0
	var stack := from.take_at(index, n)
	var added := to.add_stack(stack)
	if added < n:
		var rest := stack.duplicate(true)
		rest.count = n - added
		from.add_stack(rest, true)
	return added


## Moves everything that fits. Returns the number of items moved.
static func transfer_all(from: Inventory, to: Inventory) -> int:
	var moved := 0
	for i in range(from.get_slots().size() - 1, -1, -1):
		moved += transfer_slot(from, i, to)
	return moved
