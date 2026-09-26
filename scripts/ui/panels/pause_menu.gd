class_name PauseMenu
extends UIPanel
## PauseMenu (Esc) — resume, save (3 slots), load, settings, return to title.

var _pages: Dictionary = {}
var _slots: SaveSlotsView


func _build() -> void:
	add_backdrop(0.65)
	var p := UIKit.centered(self, Vector2(560, 420))
	var col := UIKit.vbox(8)
	p.add_child(col)
	col.add_child(UIKit.title("ПАУЗА"))
	var menu := UIKit.vbox(6)
	menu.add_child(UIKit.button("Продолжить", close))
	menu.add_child(UIKit.button("Сохранить", func(): _show_slots(true)))
	menu.add_child(UIKit.button("Загрузить", func(): _show_slots(false)))
	menu.add_child(UIKit.button("Настройки", func(): _show("settings")))
	menu.add_child(UIKit.button("В главное меню", func(): Main.instance.return_to_title()))
	col.add_child(menu)
	_pages["menu"] = menu
	var slots_box := UIKit.vbox(6)
	_slots = SaveSlotsView.new()
	slots_box.add_child(_slots)
	slots_box.add_child(UIKit.button("Назад", func(): _show("menu")))
	col.add_child(slots_box)
	_pages["slots"] = slots_box
	var settings_box := UIKit.vbox(6)
	settings_box.add_child(SettingsView.new())
	settings_box.add_child(UIKit.button("Назад", func():
		Settings.save_settings()
		_show("menu")))
	col.add_child(settings_box)
	_pages["settings"] = settings_box


func _on_open(_data: Dictionary) -> void:
	_show("menu")


func _on_close() -> void:
	Settings.save_settings()


func _show(page: String) -> void:
	for k in _pages.keys():
		_pages[k].visible = k == page


func _show_slots(saving: bool) -> void:
	_slots.saving = saving
	_slots.refresh()
	_show("slots")
