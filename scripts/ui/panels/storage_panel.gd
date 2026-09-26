class_name StoragePanel
extends UIPanel
## StoragePanel — move items between the backpack and shelter storage (StorageSystem).

var _bag: ItemListView
var _box: ItemListView
var _info: Label


func _build() -> void:
	add_backdrop()
	var p := UIKit.centered(self, Vector2(820, 470))
	var col := UIKit.vbox(8)
	p.add_child(col)
	var head := UIKit.hbox(8)
	col.add_child(head)
	var t := UIKit.title("СКЛАД УБЕЖИЩА")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Закрыть [Esc]", close))
	var row := UIKit.hbox(10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var left := UIKit.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UIKit.label("Рюкзак", 14, UIKit.TEXT_DIM))
	_bag = ItemListView.new()
	_bag.inventory = GameState.inventory
	_bag.item_activated.connect(func(_i): _move(true, 1))
	left.add_child(_bag)
	row.add_child(left)
	var mid := UIKit.vbox(8)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(UIKit.button("Положить →", func(): _move(true, 1), 150))
	mid.add_child(UIKit.button("Положить всё →", func(): _move(true, -1), 150))
	mid.add_child(UIKit.spacer(16))
	mid.add_child(UIKit.button("← Взять", func(): _move(false, 1), 150))
	mid.add_child(UIKit.button("← Взять всё", func(): _move(false, -1), 150))
	row.add_child(mid)
	var right := UIKit.vbox(4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UIKit.label("Хранилище", 14, UIKit.TEXT_DIM))
	_box = ItemListView.new()
	_box.inventory = GameState.storage
	_box.item_activated.connect(func(_i): _move(false, 1))
	right.add_child(_box)
	row.add_child(right)
	_info = UIKit.label("", 13, UIKit.TEXT_DIM)
	col.add_child(_info)


func _on_open(_data: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	_bag.refresh()
	_box.refresh()
	_info.text = "Рюкзак: %.1f / %.0f кг. Еды в убежище: %d. Выжившие едят из хранилища каждое утро." % [GameState.inventory.get_total_weight(), GameState.inventory.max_weight, GameState.storage.count_category("Food")]


## amount -1 = whole stack.
func _move(to_storage: bool, amount: int) -> void:
	var list := _bag if to_storage else _box
	var id := list.get_selected_id()
	if id.is_empty():
		return
	var from := GameState.inventory if to_storage else GameState.storage
	var to := GameState.storage if to_storage else GameState.inventory
	if StorageSystem.transfer(from, to, id, amount) > 0:
		AudioManager.play_ui("pickup")
	_refresh()
