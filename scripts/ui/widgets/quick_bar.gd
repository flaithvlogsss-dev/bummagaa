class_name QuickBar
extends HBoxContainer
## QuickBar — the five quick slots (keys 1-5) on the HUD: item icon, count, key number.

var _slots: Array[ItemSlot] = []


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in Inventory.QUICK_SLOTS:
		var s := ItemSlot.new()
		s.custom_minimum_size = Vector2(40, 40)
		s.quick_key = i + 1
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(s)
		_slots.append(s)
	GameState.inventory.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var inv := GameState.inventory
	var any := false
	for i in _slots.size():
		var id := inv.get_quick(i)
		var n := inv.count(id) if not id.is_empty() else 0
		_slots[i].set_stack({"id": id, "count": n} if not id.is_empty() and Data.has_item(id) else {})
		_slots[i].modulate = Color(1, 1, 1, 1.0 if n > 0 or id.is_empty() else 0.35)
		any = any or not id.is_empty()
	visible = any
