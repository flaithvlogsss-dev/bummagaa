class_name InventoryPanel
extends UIPanel
## InventoryPanel (I) — backpack contents, item details, use / equip / drop, carry weight.

var _list: ItemListView
var _icon: TextureRect
var _name: Label
var _meta: Label
var _desc: Label
var _use: Button
var _drop: Button
var _weight: Label
var _weight_bar: ProgressBar
var _equip: Label


func _build() -> void:
	add_backdrop()
	var p := UIKit.centered(self, Vector2(760, 470))
	var col := UIKit.vbox(8)
	p.add_child(col)
	var head := UIKit.hbox(8)
	col.add_child(head)
	var t := UIKit.title("РЮКЗАК")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Закрыть [I]", close))
	var row := UIKit.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	_list = ItemListView.new()
	_list.inventory = GameState.inventory
	_list.item_selected.connect(func(_i): _show_details())
	_list.item_activated.connect(func(_i): _use_selected())
	row.add_child(_list)
	var details := UIKit.vbox(6)
	details.custom_minimum_size.x = 380
	row.add_child(details)
	var top := UIKit.hbox(10)
	details.add_child(top)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(64, 64)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top.add_child(_icon)
	var names := UIKit.vbox(2)
	top.add_child(names)
	_name = UIKit.label("", 18, UIKit.ACCENT)
	names.add_child(_name)
	_meta = UIKit.label("", 12, UIKit.TEXT_DIM)
	names.add_child(_meta)
	_desc = UIKit.label("", 14)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(370, 120)
	details.add_child(_desc)
	var buttons := UIKit.hbox(8)
	details.add_child(buttons)
	_use = UIKit.button("Использовать", _use_selected, 150)
	buttons.add_child(_use)
	_drop = UIKit.button("Выбросить", _drop_selected, 120)
	buttons.add_child(_drop)
	details.add_child(UIKit.separator())
	_equip = UIKit.label("", 13, UIKit.TEXT_DIM)
	_equip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_equip)
	_weight = UIKit.label("", 13)
	details.add_child(_weight)
	_weight_bar = UIKit.bar(UIKit.ACCENT, 8)
	details.add_child(_weight_bar)
	GameState.inventory.changed.connect(func():
		if is_open:
			_refresh())


func _on_open(_data: Dictionary) -> void:
	_refresh()
	if _list.item_count > 0 and _list.get_selected_items().is_empty():
		_list.select(0)
	_show_details()
	_list.grab_focus()


func _refresh() -> void:
	_list.refresh()
	var inv := GameState.inventory
	var w := inv.get_total_weight()
	_weight.text = "Вес: %.1f / %.0f кг%s" % [w, inv.max_weight, "  — перегруз!" if inv.is_overweight() else ""]
	_weight_bar.max_value = inv.max_weight
	_weight_bar.value = minf(w, inv.max_weight)
	_weight_bar.modulate = Color(1, 0.5, 0.5) if inv.is_overweight() else Color.WHITE
	var slots := {"body": "Тело", "face": "Лицо", "hand": "Руки"}
	var parts: PackedStringArray = []
	for slot in slots.keys():
		var id := inv.get_equipped(slot)
		parts.append("%s: %s" % [slots[slot], Data.get_item_name(id) if not id.is_empty() else "—"])
	_equip.text = "   ".join(parts)
	_show_details()


func _show_details() -> void:
	var id := _list.get_selected_id()
	var item := Data.get_item(id) if not id.is_empty() else null
	_use.disabled = item == null
	_drop.disabled = item == null
	if item == null:
		_icon.texture = null
		_name.text = "Пусто" if GameState.inventory.is_empty() else ""
		_meta.text = ""
		_desc.text = "Ищите припасы в домах, машинах и магазинах." if GameState.inventory.is_empty() else ""
		return
	_icon.texture = PixelArt.item_icon(item)
	_name.text = item.name
	_meta.text = "%s • %.1f кг • ×%d" % [_category_ru(item.category), item.weight, GameState.inventory.count(id)]
	_desc.text = item.description
	if item.is_equippable():
		_use.text = "Снять" if GameState.inventory.is_equipped(id) else "Надеть"
	else:
		_use.text = item.use_text if item.usable else "—"
		_use.disabled = not item.usable
	_drop.disabled = item.category == "Quest"


static func _category_ru(c: String) -> String:
	return {"Food": "Еда", "Water": "Вода", "Medical": "Медицина", "Material": "Материал", "Tool": "Инструмент",
		"Weapon": "Оружие", "Ammunition": "Боеприпасы", "Quest": "Сюжетный", "Equipment": "Снаряжение",
		"Electronics": "Электроника"}.get(c, c)


func _use_selected() -> void:
	var id := _list.get_selected_id()
	if id.is_empty():
		return
	var item := Data.get_item(id)
	if GameState.inventory.consume(id):
		if item and not item.is_equippable():
			AudioManager.play_ui("eat" if item.category in ["Food", "Water"] else "pickup")
			GameState.notify("%s: %s" % [item.use_text, item.name])
	_refresh()


func _drop_selected() -> void:
	var id := _list.get_selected_id()
	if id.is_empty():
		return
	if GameState.inventory.remove(id, 1):
		GameState.notify("Выброшено: %s" % Data.get_item_name(id))
	_refresh()
