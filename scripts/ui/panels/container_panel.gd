class_name ContainerPanel
extends UIPanel
## ContainerPanel — two grids side by side: a container (cabinet, car trunk, body, the shelter
## storage) and the backpack. Take what you need, leave the rest; the container remembers.
##
## Open data: {"title": String, "inventory": Inventory, "hint": String, "on_close": Callable}
## Mouse: double LMB / RMB moves a stack to the other side, drag moves it too.
## Keys: E / Space take all, Esc close.

var _box: Inventory
var _bag: Inventory
var _title: Label
var _hint: Label
var _box_grid: GridContainer
var _bag_grid: GridContainer
var _box_cells: Array[ItemSlot] = []
var _bag_cells: Array[ItemSlot] = []
var _weight: Label
var _weight_bar: ProgressBar
var _info_icon: TextureRect
var _info_name: Label
var _info_text: Label
var _sel: ItemSlot


func _build() -> void:
	_bag = GameState.inventory
	add_backdrop(0.6)
	var p := UIKit.centered(self, Vector2(940, 500))
	var col := UIKit.vbox(10)
	p.add_child(col)
	var head := UIKit.hbox(10)
	col.add_child(head)
	_title = UIKit.title("")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	head.add_child(UIKit.button("Взять всё [E]", _take_all, 150))
	head.add_child(UIKit.button("Закрыть [Esc]", close))
	var row := UIKit.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var left := UIKit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint = UIKit.label("", 12, UIKit.TEXT_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_hint)
	_box_grid = _make_grid(left, 7)
	row.add_child(left)
	var right := UIKit.vbox(6)
	var wrow := UIKit.hbox(8)
	var bl := UIKit.label("РЮКЗАК", 12, UIKit.TEXT_DIM)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrow.add_child(bl)
	_weight = UIKit.label("", 12)
	wrow.add_child(_weight)
	right.add_child(wrow)
	_weight_bar = UIKit.bar(UIKit.ACCENT, 5)
	right.add_child(_weight_bar)
	_bag_grid = _make_grid(right, 5)
	row.add_child(right)
	col.add_child(UIKit.separator())
	var info := UIKit.hbox(10)
	info.custom_minimum_size.y = 56
	_info_icon = TextureRect.new()
	_info_icon.custom_minimum_size = Vector2(48, 48)
	_info_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_info_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info.add_child(_info_icon)
	var tv := UIKit.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_name = UIKit.label("", 15, UIKit.ACCENT)
	tv.add_child(_info_name)
	_info_text = UIKit.label("", 12, UIKit.TEXT_DIM)
	_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(_info_text)
	info.add_child(tv)
	col.add_child(info)
	col.add_child(UIKit.label("2×ЛКМ или ПКМ — переложить стопку   Перетащить — переложить   E — взять всё   Esc — закрыть", 12, UIKit.TEXT_DIM))
	_bag.changed.connect(func():
		if is_open:
			_refresh())


func _make_grid(parent: Control, columns: int) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(columns * (ItemSlot.SIZE + 6) + 12, 5 * (ItemSlot.SIZE + 6))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	scroll.add_child(g)
	return g


func _on_open(data: Dictionary) -> void:
	_box = data.get("inventory")
	if _box == null:
		_box = GameState.storage
		_title.text = "СКЛАД УБЕЖИЩА"
		_hint.text = "Выжившие берут еду отсюда каждое утро. Готовой еды на складе: %d." % _storage_meals()
	else:
		_title.text = str(data.get("title", "Хранилище")).to_upper()
		_hint.text = str(data.get("hint", ""))
	if not _box.changed.is_connected(_on_box_changed):
		_box.changed.connect(_on_box_changed)
	_sel = null
	AudioManager.play_ui("rustle")
	_refresh()
	if not _box_cells.is_empty() and not _box_cells[0].stack.is_empty():
		_sel = _box_cells[0]
		_refresh()


func _storage_meals() -> int:
	var n := 0
	for e in GameState.storage.get_entries():
		if GameState.is_meal(e.item):
			n += int(e.count)
	return n


func _on_close() -> void:
	if _box and _box.changed.is_connected(_on_box_changed):
		_box.changed.disconnect(_on_box_changed)
	var cb: Callable = open_data.get("on_close", Callable())
	if cb.is_valid():
		cb.call(_box)


func _on_box_changed() -> void:
	if is_open:
		_refresh()


func _refresh() -> void:
	_fill(_box_grid, _box_cells, _box, maxi(21, int(ceil((_box.get_slots().size() + 1) / 7.0)) * 7))
	_fill(_bag_grid, _bag_cells, _bag, maxi(_bag.slot_count(), _bag.get_slots().size()))
	var w := _bag.get_total_weight()
	var mw := _bag.get_max_weight()
	_weight.text = "%.1f / %.1f кг   %d/%d" % [w, mw, _bag.used_slots(), _bag.slot_count()]
	_weight_bar.max_value = maxf(mw, 0.1)
	_weight_bar.value = minf(w, mw)
	_weight_bar.modulate = Color(1, 0.5, 0.5) if _bag.is_overweight() else Color.WHITE
	_show_info(_sel if is_instance_valid(_sel) else null)


func _fill(grid: GridContainer, cells: Array[ItemSlot], inv: Inventory, count: int) -> void:
	while cells.size() < count:
		var c := ItemSlot.new()
		c.clicked.connect(_on_clicked)
		c.dropped_on.connect(_on_dropped)
		c.hovered.connect(func(cell): _show_info(cell))
		grid.add_child(c)
		cells.append(c)
	while cells.size() > count:
		var c: ItemSlot = cells.pop_back()
		if c == _sel:
			_sel = null
		c.queue_free()
	var list := inv.get_slots()
	for i in cells.size():
		cells[i].inventory = inv
		cells[i].index = i
		cells[i].set_stack(list[i] if i < list.size() else {})
		cells[i].selected = cells[i] == _sel


func _show_info(cell: ItemSlot) -> void:
	var item := cell.get_item() if cell else null
	if item == null:
		_info_icon.texture = null
		_info_name.text = "" if not _box.is_empty() else "Пусто"
		_info_text.text = ""
		return
	_info_icon.texture = IconArt.item_icon(item)
	_info_name.text = ItemTooltip.title(item, cell.stack)
	_info_name.add_theme_color_override("font_color", ItemTooltip.rarity_color(item))
	var lines: PackedStringArray = [ItemTooltip.meta_line(item, cell.stack)]
	if not item.effect_text.is_empty():
		lines.append(item.effect_text)
	lines.append_array(ItemTooltip.state_lines(item, cell.stack))
	_info_text.text = "   ".join(lines)


func _on_clicked(cell: ItemSlot, button: int, double: bool) -> void:
	_sel = cell
	if button == MOUSE_BUTTON_RIGHT or double:
		_move(cell)
	_refresh()


func _move(cell: ItemSlot) -> void:
	if cell.stack.is_empty():
		return
	var to := _bag if cell.inventory == _box else _box
	var n := StorageSystem.transfer_slot(cell.inventory, cell.index, to)
	if n > 0:
		AudioManager.play_ui("pickup" if to == _bag else "drop")
	else:
		AudioManager.play_ui("deny")
		GameState.notify("Не влезает: нужен рюкзак побольше." if to == _bag else "Сюда не положить.", "warning")


func _on_dropped(target: ItemSlot, data: Dictionary) -> void:
	var src: ItemSlot = data.get("source")
	if src == null or src.stack.is_empty() or not str(data.get("equip", "")).is_empty():
		return
	if src.inventory == target.inventory:
		target.inventory.move_slot(src.index, target.index)
	else:
		_move(src)
	_refresh()


func _take_all() -> void:
	var before := _box.used_slots()
	StorageSystem.transfer_all(_box, _bag)
	if _box.used_slots() > 0:
		GameState.notify("Всё не унести — часть осталась." if _box.used_slots() < before else "Рюкзак полон.", "warning")
		AudioManager.play_ui("deny" if _box.used_slots() == before else "pickup")
	else:
		AudioManager.play_ui("pickup")
	_refresh()


func _panel_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_E, KEY_SPACE]:
			_take_all()
			return true
	return false
