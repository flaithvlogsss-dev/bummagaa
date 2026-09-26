class_name SettingsView
extends VBoxContainer
## SettingsView — accessibility / audio / video options, embedded in the pause and title menus.

const BUS_NAMES := {"Master": "Общая громкость", "Music": "Музыка", "Ambient": "Окружение", "SFX": "Эффекты", "Dialogue": "Диалоги", "Radio": "Радио"}
const SPEEDS := ["slow", "normal", "fast", "instant"]
const SPEED_NAMES := ["Медленно", "Обычно", "Быстро", "Мгновенно"]


func _ready() -> void:
	add_theme_constant_override("separation", 5)
	for bus in BUS_NAMES.keys():
		_slider_row(BUS_NAMES[bus], 0.0, 1.0, 0.05, Settings.volumes.get(bus, 0.8), func(v): Settings.set_volume(bus, v))
	var speed := OptionButton.new()
	for i in SPEEDS.size():
		speed.add_item(SPEED_NAMES[i], i)
	speed.selected = maxi(0, SPEEDS.find(Settings.text_speed))
	speed.item_selected.connect(func(i): Settings.set_option("text_speed", SPEEDS[i]))
	_row("Скорость текста", speed)
	var shake := CheckBox.new()
	shake.button_pressed = Settings.screen_shake
	shake.toggled.connect(func(on): Settings.set_option("screen_shake", on))
	_row("Тряска экрана", shake)
	_slider_row("Яркость", 0.6, 1.5, 0.05, Settings.brightness, func(v): Settings.set_option("brightness", v))
	_slider_row("Масштаб интерфейса", 0.75, 1.5, 0.05, Settings.ui_scale, func(v): Settings.set_option("ui_scale", v))
	var pix := OptionButton.new()
	for i in 4:
		pix.add_item(["Нет (1×)", "Мягкая (2×)", "Крупная (3×)", "Очень крупная (4×)"][i], i + 1)
	pix.selected = clampi(Settings.pixel_scale - 1, 0, 3)
	pix.item_selected.connect(func(i): Settings.set_option("pixel_scale", i + 1))
	_row("Пикселизация 3D", pix)
	var controls := UIKit.label("Управление: WASD — ходьба, Shift — бег, Ctrl — тихий шаг, E — действие, I — рюкзак, M — карта, Q — журнал, F — фонарь, ПКМ/ЛКМ — прицел/выстрел, R — перезарядка, Esc — меню, F1 — отладка.", 12, UIKit.TEXT_DIM)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.custom_minimum_size.x = 440
	add_child(controls)


func _row(title_text: String, control: Control) -> void:
	var h := UIKit.hbox(10)
	var l := UIKit.label(title_text, 14)
	l.custom_minimum_size.x = 190
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	add_child(h)


func _slider_row(title_text: String, lo: float, hi: float, step: float, value: float, cb: Callable) -> void:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size.x = 220
	s.value_changed.connect(cb)
	_row(title_text, s)
