class_name DeathScreen
extends UIPanel
## DeathScreen — "THE NIGHT CONTINUES". Offers to load the latest save.

var _cause: Label


func _init() -> void:
	closable = false


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.01, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := UIKit.vbox(12)
	center.add_child(col)
	var t := UIKit.label("THE NIGHT CONTINUES", 44, Color(0.85, 0.9, 1.0))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	_cause = UIKit.label("", 15, UIKit.TEXT_DIM)
	_cause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_cause)
	col.add_child(UIKit.spacer(10))
	col.add_child(UIKit.button("Загрузить последнее сохранение", _load_last))
	col.add_child(UIKit.button("В главное меню", func(): Main.instance.return_to_title()))


func _on_open(_data: Dictionary) -> void:
	var s := GameState.stats
	if s.temperature < 15.0:
		_cause.text = "Холод забрал последнее тепло."
	elif s.hunger <= 0.0 or s.hydration <= 0.0:
		_cause.text = "Тело больше не могло продолжать."
	else:
		_cause.text = "Город не прощает ошибок. Но ночь ещё не закончилась."


func _load_last() -> void:
	var slot := SaveManager.latest_slot()
	if slot.is_empty():
		Main.instance.new_game()
	else:
		Main.instance.load_slot(slot)
