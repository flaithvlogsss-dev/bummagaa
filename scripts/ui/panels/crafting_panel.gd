class_name CraftingPanel
extends UIPanel
## CraftingPanel — workshop UI. Left: recipe list. Right: name, description, materials,
## CREATE button. Missing materials are listed explicitly.

var _list: ItemList
var _name: Label
var _desc: Label
var _materials: RichTextLabel
var _status: Label
var _create: Button
var _progress: ProgressBar
var _station: String = "workbench"
var _recipes: Array[RecipeData] = []
var _busy: bool = false


func _build() -> void:
	add_backdrop()
	var p := UIKit.centered(self, Vector2(780, 460))
	var col := UIKit.vbox(8)
	p.add_child(col)
	var head := UIKit.hbox(8)
	col.add_child(head)
	var t := UIKit.title("МАСТЕРСКАЯ")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Закрыть [Esc]", close))
	var row := UIKit.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(260, 340)
	_list.fixed_icon_size = Vector2i(32, 32)
	_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_list.item_selected.connect(func(_i): _show())
	row.add_child(_list)
	var right := UIKit.vbox(8)
	right.custom_minimum_size.x = 440
	row.add_child(right)
	_name = UIKit.label("", 18, UIKit.ACCENT)
	right.add_child(_name)
	_desc = UIKit.label("", 14)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(430, 60)
	right.add_child(_desc)
	right.add_child(UIKit.label("Материалы:", 13, UIKit.TEXT_DIM))
	_materials = UIKit.rich("", 15)
	right.add_child(_materials)
	_status = UIKit.label("", 13, UIKit.DANGER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status)
	_progress = UIKit.bar(UIKit.ACCENT, 8)
	_progress.visible = false
	right.add_child(_progress)
	_create = UIKit.button("СОЗДАТЬ", _craft, 200)
	right.add_child(_create)
	right.add_child(UIKit.label("Материалы берутся из рюкзака, затем со склада убежища.", 12, UIKit.TEXT_DIM))


func _on_open(data: Dictionary) -> void:
	_station = str(data.get("station", "workbench"))
	_recipes = CraftingSystem.get_recipes(_station)
	_list.clear()
	for r in _recipes:
		var idx := _list.add_item(r.name, PixelArt.item_icon(Data.get_item(r.result_item)))
		if not CraftingSystem.is_unlocked(r):
			_list.set_item_custom_fg_color(idx, UIKit.TEXT_DIM)
	if _list.item_count > 0:
		_list.select(0)
	_show()


func _selected() -> RecipeData:
	var sel := _list.get_selected_items()
	return _recipes[sel[0]] if not sel.is_empty() and sel[0] < _recipes.size() else null


func _show() -> void:
	var r := _selected()
	if r == null:
		_name.text = "Нет рецептов"
		_create.disabled = true
		return
	_name.text = r.name
	var result := Data.get_item(r.result_item)
	_desc.text = r.description if not r.description.is_empty() else (result.description if result else "")
	var lines: PackedStringArray = []
	for id in r.ingredients.keys():
		var need := int(r.ingredients[id])
		var have := CraftingSystem.available_count(str(id))
		var color := "#8fe39a" if have >= need else "#ff7a6e"
		lines.append("[color=%s]%s  %d / %d[/color]" % [color, Data.get_item_name(str(id)), have, need])
	lines.append("[color=#9aa3ae]Результат: %s ×%d • %d мин[/color]" % [Data.get_item_name(r.result_item), r.result_count, r.crafting_time])
	_materials.text = "\n".join(lines)
	var reason := CraftingSystem.lock_reason(r)
	var missing := CraftingSystem.missing(r)
	if not reason.is_empty():
		_status.text = reason
	elif not missing.is_empty():
		var parts: PackedStringArray = []
		for id in missing.keys():
			parts.append("%s ×%d" % [Data.get_item_name(id), missing[id]])
		_status.text = "Не хватает: " + ", ".join(parts)
	else:
		_status.text = ""
	_create.disabled = _busy or not CraftingSystem.can_craft(r)


func _craft() -> void:
	var r := _selected()
	if r == null or _busy or not CraftingSystem.can_craft(r):
		return
	_busy = true
	_create.disabled = true
	_progress.visible = true
	_progress.value = 0.0
	AudioManager.play_ui("craft")
	var t := create_tween()
	t.tween_property(_progress, "value", 100.0, 0.9)
	await t.finished
	if CraftingSystem.craft(r):
		GameState.notify("Создано: %s ×%d" % [Data.get_item_name(r.result_item), r.result_count], "item")
		AudioManager.play_ui("pickup")
	_progress.visible = false
	_busy = false
	_show()
