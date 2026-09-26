class_name TitleScreen
extends UIPanel
## TitleScreen — new game, continue, load, settings, quit. Snow falls behind the menu.

var _pages: Dictionary = {}
var _slots: SaveSlotsView
var _continue: Button


func _init() -> void:
	closable = false


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.04, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var snow := CPUParticles2D.new()
	snow.amount = 220
	snow.lifetime = 9.0
	snow.preprocess = 9.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(900, 10)
	snow.position = Vector2(640, -20)
	snow.direction = Vector2(0.2, 1)
	snow.spread = 12.0
	snow.gravity = Vector2(8, 30)
	snow.initial_velocity_min = 25.0
	snow.initial_velocity_max = 60.0
	snow.scale_amount_min = 1.0
	snow.scale_amount_max = 3.0
	snow.color = Color(0.85, 0.9, 1.0, 0.7)
	add_child(snow)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := UIKit.vbox(10)
	col.custom_minimum_size.x = 520
	center.add_child(col)
	var title := UIKit.label("LAST SNOW", 64, Color(0.92, 0.95, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UIKit.label("снег забирает тепло. люди — всё остальное.", 15, UIKit.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(UIKit.spacer(20))
	var menu := UIKit.vbox(8)
	_continue = UIKit.button("Продолжить", func(): Main.instance.continue_game())
	menu.add_child(_continue)
	menu.add_child(UIKit.button("Новая игра", func(): Main.instance.new_game()))
	menu.add_child(UIKit.button("Загрузить", func():
		_slots.saving = false
		_slots.refresh()
		_show("slots")))
	menu.add_child(UIKit.button("Настройки", func(): _show("settings")))
	menu.add_child(UIKit.button("Выход", _quit))
	col.add_child(menu)
	_pages["menu"] = menu
	var slots_panel := UIKit.panel()
	var sbox := UIKit.vbox(6)
	slots_panel.add_child(sbox)
	_slots = SaveSlotsView.new()
	sbox.add_child(_slots)
	sbox.add_child(UIKit.button("Назад", func(): _show("menu")))
	col.add_child(slots_panel)
	_pages["slots"] = slots_panel
	var settings_panel := UIKit.panel()
	var setbox := UIKit.vbox(6)
	settings_panel.add_child(setbox)
	setbox.add_child(SettingsView.new())
	setbox.add_child(UIKit.button("Назад", func():
		Settings.save_settings()
		_show("menu")))
	col.add_child(settings_panel)
	_pages["settings"] = settings_panel
	var foot := UIKit.label("Прототип (vertical slice) • Godot 4 • весь арт и звук — процедурные заглушки", 11, UIKit.TEXT_DIM)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -28
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)


func _quit() -> void:
	Settings.save_settings()
	AudioManager.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _on_open(_data: Dictionary) -> void:
	_continue.visible = not SaveManager.latest_slot().is_empty()
	_show("menu")
	AudioManager.set_layer("music", "music_drone", 0.6, "Music")
	AudioManager.set_layer("wind", "wind", 0.35)


func _show(page: String) -> void:
	for k in _pages.keys():
		_pages[k].visible = k == page
