class_name InventoryPanel
extends UIPanel
## InventoryPanel (I / Tab) — equipment on the left, the backpack grid in the middle, item
## details on the right, controls at the bottom.
##
## Mouse: LMB select, double LMB use / equip, RMB quick use / unequip, drag to move, drag onto
##   an equipment slot to wear, drag out of the window to drop on the ground.
## Keys: 1-5 bind the hovered / selected item to a quick slot, R sort, Del drop one.

const GRID_COLUMNS := 5
const MIN_CELLS := 20

var _inv: Inventory
var _equip_slots: Dictionary = {}
var _equip_labels: Dictionary = {}
var _grid: GridContainer
var _cells: Array[ItemSlot] = []
var _quick: Array[ItemSlot] = []
var _weight: Label
var _weight_bar: ProgressBar
var _slots_label: Label
var _icon: TextureRect
var _name: Label
var _meta: Label
var _desc: Label
var _effect: Label
var _state: Label
var _btn_use: Button
var _btn_unequip: Button
var _btn_drop: Button
var _btn_drop_all: Button
var _btn_split: Button
## {"kind": "grid"|"equip", "index": int, "slot": String}
var _sel: Dictionary = {}
var _hover: ItemSlot


func _build() -> void:
	_inv = GameState.inventory
	var bg := DropZone.new()
	bg.color = Color(0.0, 0.01, 0.02, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.dropped.connect(_on_drop_outside)
	add_child(bg)
	var p := UIKit.centered(self, Vector2(1100, 610))
	var col := UIKit.vbox(10)
	p.add_child(col)
	# Header: title, weight, close.
	var head := UIKit.hbox(12)
	col.add_child(head)
	var t := UIKit.title("СНАРЯЖЕНИЕ И РЮКЗАК")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var wbox := UIKit.vbox(2)
	wbox.custom_minimum_size.x = 260
	_weight = UIKit.label("", 13)
	wbox.add_child(_weight)
	_weight_bar = UIKit.bar(UIKit.ACCENT, 6)
	wbox.add_child(_weight_bar)
	head.add_child(wbox)
	head.add_child(UIKit.button("Закрыть [I]", close))
	var row := UIKit.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	row.add_child(_build_equipment())
	row.add_child(_build_grid())
	row.add_child(_build_details())
	col.add_child(UIKit.separator())
	var hint := UIKit.label("ЛКМ — выбрать   2×ЛКМ — использовать / надеть   ПКМ — быстро надеть / снять   Перетащить — переложить, надеть или выбросить за окно   1–5 — назначить быстрый слот   R — сортировать   Del — выбросить", 12, UIKit.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	_inv.changed.connect(func():
		if is_open:
			_refresh())


func _build_equipment() -> Control:
	var v := UIKit.vbox(6)
	v.custom_minimum_size.x = 250
	v.add_child(UIKit.label("НАДЕТО", 13, UIKit.TEXT_DIM))
	for slot in Inventory.EQUIP_SLOTS:
		var h := UIKit.hbox(8)
		var cell := ItemSlot.new()
		cell.inventory = _inv
		cell.equip_slot = slot
		cell.placeholder = IconArt.template_icon(_placeholder_shape(slot), PackedColorArray([Color(0.7, 0.72, 0.76), Color(0.6, 0.62, 0.66)]))
		cell.clicked.connect(_on_slot_clicked)
		cell.dropped_on.connect(_on_slot_drop)
		cell.hovered.connect(func(c): _hover = c)
		h.add_child(cell)
		var l := UIKit.label("", 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 180
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		v.add_child(h)
		_equip_slots[slot] = cell
		_equip_labels[slot] = l
	return v


static func _placeholder_shape(slot: String) -> String:
	return {"head": "beanie", "mask": "gasmask", "body": "jacket", "backpack": "backpack",
		"weapon": "pistol", "secondary": "knife", "utility": "flashlight"}.get(slot, "can")


func _build_grid() -> Control:
	var v := UIKit.vbox(8)
	var top := UIKit.hbox(8)
	var l := UIKit.label("РЮКЗАК", 13, UIKit.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(l)
	_slots_label = UIKit.label("", 12, UIKit.TEXT_DIM)
	top.add_child(_slots_label)
	v.add_child(top)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(GRID_COLUMNS * (ItemSlot.SIZE + 6) + 8, 4 * (ItemSlot.SIZE + 6) + 4)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)
	v.add_child(UIKit.spacer(4))
	v.add_child(UIKit.label("БЫСТРЫЕ СЛОТЫ (клавиши 1–5)", 12, UIKit.TEXT_DIM))
	var qrow := UIKit.hbox(6)
	for i in Inventory.QUICK_SLOTS:
		var q := ItemSlot.new()
		q.quick_key = i + 1
		q.index = i
		q.tooltip_text = "Слот %d" % (i + 1)
		q.clicked.connect(func(_c, button, _d):
			if button == MOUSE_BUTTON_RIGHT:
				_inv.set_quick(i, ""))
		q.dropped_on.connect(func(_c, data):
			var s := _stack_from_drag(data)
			if not s.is_empty():
				_inv.set_quick(i, str(s.id)))
		qrow.add_child(q)
		_quick.append(q)
	v.add_child(qrow)
	var btns := UIKit.hbox(6)
	btns.add_child(UIKit.button("Сортировать [R]", func(): _inv.sort(), 150))
	v.add_child(btns)
	return v


func _build_details() -> Control:
	var v := UIKit.vbox(6)
	v.custom_minimum_size.x = 330
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox(10)
	v.add_child(top)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(64, 64)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top.add_child(_icon)
	var names := UIKit.vbox(2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	_name = UIKit.label("", 18, UIKit.ACCENT)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(_name)
	_meta = UIKit.label("", 12, UIKit.TEXT_DIM)
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(_meta)
	_desc = UIKit.label("", 14)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(320, 60)
	v.add_child(_desc)
	_effect = UIKit.label("", 13, UIKit.GOOD)
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_effect)
	_state = UIKit.label("", 13, UIKit.COLD)
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_state)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var b1 := UIKit.hbox(6)
	_btn_use = UIKit.button("Использовать", _use_selected, 160)
	b1.add_child(_btn_use)
	_btn_unequip = UIKit.button("Снять", _unequip_selected, 100)
	b1.add_child(_btn_unequip)
	v.add_child(b1)
	var b2 := UIKit.hbox(6)
	_btn_drop = UIKit.button("Выбросить", func(): _drop_selected(1), 110)
	b2.add_child(_btn_drop)
	_btn_drop_all = UIKit.button("Выбросить всё", func(): _drop_selected(-1), 130)
	b2.add_child(_btn_drop_all)
	_btn_split = UIKit.button("Разделить", _split_selected, 100)
	b2.add_child(_btn_split)
	v.add_child(b2)
	return v


# --- Refresh -------------------------------------------------------------------------------------

func _on_open(_data: Dictionary) -> void:
	AudioManager.play_ui("zipper")
	_sel = {}
	_refresh()
	for i in _inv.get_slots().size():
		if not _inv.get_slots()[i].is_empty():
			_sel = {"kind": "grid", "index": i}
			break
	_refresh()


func _refresh() -> void:
	var w := _inv.get_total_weight()
	var mw := _inv.get_max_weight()
	_weight.text = "Вес: %.1f / %.1f кг%s" % [w, mw, "  — ПЕРЕГРУЗ" if _inv.is_overweight() else ""]
	_weight.add_theme_color_override("font_color", UIKit.DANGER if _inv.is_overweight() else UIKit.TEXT)
	_weight_bar.max_value = maxf(mw, 0.1)
	_weight_bar.value = minf(w, mw)
	_weight_bar.modulate = Color(1, 0.5, 0.5) if _inv.is_overweight() else Color.WHITE
	_slots_label.text = "%d / %d ячеек" % [_inv.used_slots(), _inv.slot_count()]
	for slot in Inventory.EQUIP_SLOTS:
		var cell: ItemSlot = _equip_slots[slot]
		var s := _inv.get_equipped_stack(slot)
		cell.set_stack(s)
		cell.selected = _sel.get("kind") == "equip" and _sel.get("slot") == slot
		var item := Data.get_item(str(s.id)) if not s.is_empty() else null
		(_equip_labels[slot] as Label).text = "%s\n%s" % [Inventory.SLOT_NAMES[slot], item.name if item else "—"]
		(_equip_labels[slot] as Label).add_theme_color_override("font_color", UIKit.TEXT if item else UIKit.TEXT_DIM)
	_rebuild_cells()
	var list := _inv.get_slots()
	for i in _cells.size():
		var cell := _cells[i]
		cell.index = i
		cell.locked = i >= _inv.slot_count() and i >= list.size()
		cell.set_stack(list[i] if i < list.size() else {})
		cell.selected = _sel.get("kind") == "grid" and int(_sel.get("index", -1)) == i
		cell.quick_key = _quick_key_for(cell.stack)
	for i in _quick.size():
		var id := _inv.get_quick(i)
		_quick[i].set_stack({"id": id, "count": _inv.count(id)} if not id.is_empty() and Data.has_item(id) else {})
		_quick[i].modulate = Color(1, 1, 1, 1.0 if id.is_empty() or _inv.has_item(id) else 0.4)
	_show_details()


func _rebuild_cells() -> void:
	var need := maxi(MIN_CELLS, maxi(_inv.slot_count(), _inv.get_slots().size()))
	need = int(ceil(need / float(GRID_COLUMNS))) * GRID_COLUMNS
	while _cells.size() < need:
		var cell := ItemSlot.new()
		cell.inventory = _inv
		cell.clicked.connect(_on_slot_clicked)
		cell.dropped_on.connect(_on_slot_drop)
		cell.hovered.connect(func(c): _hover = c)
		_grid.add_child(cell)
		_cells.append(cell)
	while _cells.size() > need:
		var c: ItemSlot = _cells.pop_back()
		c.queue_free()


func _quick_key_for(s: Dictionary) -> int:
	if s.is_empty():
		return 0
	for i in Inventory.QUICK_SLOTS:
		if _inv.get_quick(i) == str(s.id):
			return i + 1
	return 0


func _selected_stack() -> Dictionary:
	match _sel.get("kind", ""):
		"grid":
			return _inv.get_slot(int(_sel.index))
		"equip":
			return _inv.get_equipped_stack(str(_sel.slot))
	return {}


func _show_details() -> void:
	var s := _selected_stack()
	var item := Data.get_item(str(s.id)) if not s.is_empty() else null
	for b in [_btn_use, _btn_unequip, _btn_drop, _btn_drop_all, _btn_split]:
		b.disabled = true
	if item == null:
		_icon.texture = null
		_name.text = "Пусто" if _inv.is_empty() else ""
		_meta.text = ""
		_desc.text = "Ищи припасы в квартирах, машинах и магазинах. Тяжёлое замедляет, а рюкзак побольше даёт место." if _inv.is_empty() else "Выбери предмет."
		_effect.text = ""
		_state.text = ""
		return
	_icon.texture = IconArt.item_icon(item)
	_name.text = ItemTooltip.title(item, s)
	_name.add_theme_color_override("font_color", ItemTooltip.rarity_color(item))
	_meta.text = ItemTooltip.meta_line(item, s)
	_desc.text = item.description
	_effect.text = item.effect_text
	_state.text = "\n".join(ItemTooltip.state_lines(item, s))
	var in_grid: bool = _sel.get("kind") == "grid"
	if in_grid:
		if item.is_filter():
			_btn_use.text = "Вставить в маску"
			_btn_use.disabled = false
		elif item.is_usable():
			_btn_use.text = item.use_text
			_btn_use.disabled = false
		elif item.is_equippable():
			_btn_use.text = "Надеть" if item.is_worn() else "Взять в руки" if item.equip_slot == "weapon" else "Экипировать"
			_btn_use.disabled = false
		else:
			_btn_use.text = "—"
		_btn_drop.disabled = item.quest
		_btn_drop_all.disabled = item.quest or int(s.count) <= 1
		_btn_split.disabled = int(s.count) <= 1
	else:
		_btn_use.text = "—"
		_btn_unequip.disabled = false
		_btn_drop.disabled = item.quest


# --- Actions --------------------------------------------------------------------------------------

func _on_slot_clicked(cell: ItemSlot, button: int, double: bool) -> void:
	if cell.equip_slot.is_empty():
		_sel = {"kind": "grid", "index": cell.index}
	else:
		_sel = {"kind": "equip", "slot": cell.equip_slot}
	if button == MOUSE_BUTTON_RIGHT:
		if cell.equip_slot.is_empty():
			_quick_use(cell.index)
		else:
			_unequip_selected()
	elif double:
		if cell.equip_slot.is_empty():
			_use_selected()
		else:
			_unequip_selected()
	_refresh()


func _quick_use(index: int) -> void:
	var s := _inv.get_slot(index)
	var item := Data.get_item(str(s.id)) if not s.is_empty() else null
	if item == null:
		return
	if item.is_equippable() or item.is_filter():
		_use_selected()


func _use_selected() -> void:
	if _sel.get("kind") != "grid":
		return
	var index := int(_sel.index)
	var s := _inv.get_slot(index)
	var item := Data.get_item(str(s.id)) if not s.is_empty() else null
	if item == null:
		return
	if _inv.use_at(index):
		if item.is_equippable():
			AudioManager.play_ui("equip")
		elif item.is_filter():
			AudioManager.play_ui("clunk")
		else:
			AudioManager.play_ui("eat" if item.category in ["Food", "Water"] else "rustle")
			if not item.keep_on_use:
				GameState.notify("%s: %s" % [item.use_text, item.name], "item")
		if _inv.get_slot(index).is_empty():
			_sel = {}
	_refresh()


func _unequip_selected() -> void:
	if _sel.get("kind") != "equip":
		return
	if _inv.unequip(str(_sel.slot)):
		AudioManager.play_ui("equip")
		_sel = {}
	_refresh()


func _drop_selected(amount: int) -> void:
	var s := _selected_stack()
	var item := Data.get_item(str(s.id)) if not s.is_empty() else null
	if item == null or item.quest:
		if item:
			GameState.notify("Это нельзя выбросить.", "warning")
		return
	var dropped: Dictionary = {}
	if _sel.kind == "grid":
		dropped = _inv.take_at(int(_sel.index), amount)
	else:
		var slot := str(_sel.slot)
		if slot == "backpack" and _inv.used_slots() > Inventory.BASE_SLOTS:
			GameState.notify("Сначала выложи вещи из рюкзака.", "warning")
			return
		dropped = s.duplicate(true)
		_inv.destroy_equipped(slot)
		_sel = {}
	if dropped.is_empty():
		return
	GameState.drop_stack(dropped)
	AudioManager.play_ui("drop")
	GameState.notify("Выброшено: %s%s" % [item.name, " ×%d" % int(dropped.count) if int(dropped.count) > 1 else ""])
	_refresh()


func _split_selected() -> void:
	if _sel.get("kind") != "grid":
		return
	var s := _inv.get_slot(int(_sel.index))
	if s.is_empty() or int(s.count) <= 1:
		return
	var idx := _inv.split_at(int(_sel.index), int(s.count) / 2)
	if idx < 0:
		GameState.notify("Нет свободной ячейки.", "warning")
	else:
		_sel = {"kind": "grid", "index": idx}
	_refresh()


func _stack_from_drag(data: Dictionary) -> Dictionary:
	if data.get("inventory") != _inv:
		return {}
	if not str(data.get("equip", "")).is_empty():
		return _inv.get_equipped_stack(str(data.equip))
	return _inv.get_slot(int(data.get("index", -1)))


func _on_slot_drop(target: ItemSlot, data: Dictionary) -> void:
	if data.get("inventory") != _inv:
		return
	var from_equip := str(data.get("equip", ""))
	if not target.equip_slot.is_empty():
		# Grid -> equipment slot.
		if from_equip.is_empty():
			var s := _inv.get_slot(int(data.index))
			var item := Data.get_item(str(s.id)) if not s.is_empty() else null
			if item == null:
				return
			var ok_slot := item.equip_slot == target.equip_slot or (target.equip_slot == "secondary" and item.equip_slot == "weapon")
			if item.is_filter() and target.equip_slot == "mask":
				_inv.use_at(int(data.index))
			elif ok_slot and _inv.equip_at(int(data.index), target.equip_slot):
				AudioManager.play_ui("equip")
				_sel = {"kind": "equip", "slot": target.equip_slot}
			else:
				AudioManager.play_ui("deny")
		elif from_equip in ["weapon", "secondary"] and target.equip_slot in ["weapon", "secondary"]:
			_inv.swap_weapons()
		_refresh()
		return
	if not from_equip.is_empty():
		if _inv.unequip(from_equip):
			AudioManager.play_ui("equip")
		_refresh()
		return
	_inv.move_slot(int(data.index), target.index)
	_sel = {"kind": "grid", "index": target.index}
	_refresh()


func _on_drop_outside(data: Dictionary) -> void:
	if data.get("inventory") != _inv:
		return
	if not str(data.get("equip", "")).is_empty():
		_sel = {"kind": "equip", "slot": str(data.equip)}
	else:
		_sel = {"kind": "grid", "index": int(data.index)}
	_drop_selected(-1)


func _panel_input(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	var key: int = event.physical_keycode
	if key >= KEY_1 and key <= KEY_5:
		var target := _selected_stack()
		if is_instance_valid(_hover) and _hover.inventory == _inv and not _hover.stack.is_empty():
			target = _hover.stack
		if not target.is_empty():
			_inv.set_quick(key - KEY_1, str(target.id))
			AudioManager.play_ui("click")
		return true
	match key:
		KEY_R:
			_inv.sort()
			return true
		KEY_DELETE, KEY_BACKSPACE:
			_drop_selected(1)
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if _sel.get("kind") == "grid":
				_use_selected()
			else:
				_unequip_selected()
			return true
	return false


## Full-screen backdrop that accepts items dragged out of the panel.
class DropZone:
	extends ColorRect

	signal dropped(data: Dictionary)

	func _can_drop_data(_p: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("source")

	func _drop_data(_p: Vector2, data: Variant) -> void:
		dropped.emit(data)
