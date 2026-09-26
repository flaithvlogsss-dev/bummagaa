class_name ItemListView
extends ItemList
## ItemList bound to an Inventory; shows pixel icons, counts and equipped marks.

var inventory: Inventory


func _init() -> void:
	fixed_icon_size = Vector2i(32, 32)
	icon_mode = ItemList.ICON_MODE_LEFT
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(260, 300)


func refresh() -> void:
	var keep := get_selected_id()
	clear()
	if inventory == null:
		return
	for e in inventory.get_entries():
		var item: ItemData = e.item
		if item == null:
			continue
		var label := "%s ×%d" % [item.name, e.count]
		if inventory.is_equipped(e.id):
			label += "  [надето]"
		var idx := add_item(label, PixelArt.item_icon(item))
		set_item_metadata(idx, e.id)
		if item.rarity in ["rare", "unique"]:
			set_item_custom_fg_color(idx, UIKit.ACCENT)
	if not keep.is_empty():
		select_id(keep)


func get_selected_id() -> String:
	var sel := get_selected_items()
	return str(get_item_metadata(sel[0])) if not sel.is_empty() else ""


func select_id(id: String) -> void:
	for i in item_count:
		if str(get_item_metadata(i)) == id:
			select(i)
			return
