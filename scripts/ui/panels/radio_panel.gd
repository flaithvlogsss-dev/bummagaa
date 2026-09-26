class_name RadioPanel
extends UIPanel
## RadioPanel — tuning mini-game. Move the frequency slider (or A/D, arrows); static fades
## and the voice becomes clear near a signal. Hold a clear signal to record it.
## The basic shelter receiver just plays its preset broadcast.

const GARBLE := "▒░#%*~·"
const LOCK_TIME := 1.2

var _station: String = ""
var _freq_label: Label
var _slider: HSlider
var _strength: ProgressBar
var _wave: Control
var _text: Label
var _found: ItemList
var _status: Label
var _clarity: float = 0.0
var _probe: Dictionary = {}
var _hold: float = 0.0
var _garble_t: float = 0.0
var _broadcast: Dictionary = {}
var _broadcast_t: float = 0.0
var _showing_found: String = ""
var _levels: PackedFloat32Array = PackedFloat32Array()


func _build() -> void:
	add_backdrop()
	var p := UIKit.centered(self, Vector2(820, 460))
	var col := UIKit.vbox(8)
	p.add_child(col)
	var head := UIKit.hbox(8)
	col.add_child(head)
	var t := UIKit.title("РАДИО")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Закрыть [Esc]", close))
	var row := UIKit.hbox(14)
	col.add_child(row)
	var left := UIKit.vbox(8)
	left.custom_minimum_size.x = 520
	row.add_child(left)
	_freq_label = UIKit.label("FM 94.0 MHz", 30, UIKit.ACCENT)
	_freq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_freq_label)
	_slider = HSlider.new()
	_slider.min_value = RadioManager.FREQ_MIN
	_slider.max_value = RadioManager.FREQ_MAX
	_slider.step = 0.05
	_slider.value = 94.0
	_slider.custom_minimum_size = Vector2(500, 24)
	left.add_child(_slider)
	var scale := UIKit.hbox(0)
	for f in [88, 92, 96, 100, 104, 108]:
		var l := UIKit.label(str(f), 11, UIKit.TEXT_DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scale.add_child(l)
	left.add_child(scale)
	var sig := UIKit.hbox(8)
	sig.add_child(UIKit.label("Сигнал", 12, UIKit.TEXT_DIM))
	_strength = UIKit.bar(UIKit.GOOD, 10)
	_strength.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sig.add_child(_strength)
	left.add_child(sig)
	_wave = Control.new()
	_wave.custom_minimum_size = Vector2(500, 56)
	_wave.draw.connect(_draw_wave)
	left.add_child(_wave)
	var text_panel := PanelContainer.new()
	text_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.02, 0.03, 0.03, 0.95), Color(0.2, 0.35, 0.3), 1, 10))
	text_panel.custom_minimum_size = Vector2(500, 120)
	left.add_child(text_panel)
	_text = UIKit.label("", 15, Color(0.7, 1.0, 0.8))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 480
	text_panel.add_child(_text)
	_status = UIKit.label("", 12, UIKit.TEXT_DIM)
	left.add_child(_status)
	var right := UIKit.vbox(6)
	right.custom_minimum_size.x = 240
	row.add_child(right)
	right.add_child(UIKit.label("Записанные сигналы", 13, UIKit.TEXT_DIM))
	_found = ItemList.new()
	_found.custom_minimum_size = Vector2(240, 300)
	_found.item_selected.connect(_on_found_selected)
	right.add_child(_found)
	_levels.resize(48)


func _on_open(data: Dictionary) -> void:
	_station = str(data.get("station", "radio_point"))
	_hold = 0.0
	_showing_found = ""
	_broadcast = {}
	_refresh_found()
	var basic := _station == "shelter_basic"
	_slider.visible = not basic
	_slider.editable = not basic
	if basic:
		var sig := Data.get_radio_signal(str(data.get("signal", "rs_warning")))
		_broadcast = sig
		_broadcast_t = 0.0
		if not sig.is_empty():
			_slider.value = float(sig.get("frequency", 94.0))
		_status.text = "Старый приёмник ловит только одну станцию."
	else:
		_status.text = "A/D или ←/→ — точная настройка. Удерживайте чистый сигнал, чтобы записать его."
	AudioManager.set_layer("radio_static", "static", 0.8, "Radio")
	AudioManager.set_layer("radio_voice", "radio_voice", 0.0, "Radio")


func _on_close() -> void:
	AudioManager.stop_layer("radio_static")
	AudioManager.stop_layer("radio_voice")


func _refresh_found() -> void:
	_found.clear()
	for id in RadioManager.found_signals():
		var s := Data.get_radio_signal(id)
		var idx := _found.add_item("%.1f — %s" % [float(s.get("frequency", 0.0)), s.get("title", id)])
		_found.set_item_metadata(idx, id)


func _on_found_selected(index: int) -> void:
	_showing_found = str(_found.get_item_metadata(index))
	var s := Data.get_radio_signal(_showing_found)
	_text.text = GameState.format_text(str(s.get("text", "")))


func _panel_input(event: InputEvent) -> bool:
	if not _slider.editable:
		return false
	if event.is_action_pressed("move_left") or (event is InputEventKey and event.pressed and event.keycode == KEY_LEFT):
		_slider.value -= 0.1
		return true
	if event.is_action_pressed("move_right") or (event is InputEventKey and event.pressed and event.keycode == KEY_RIGHT):
		_slider.value += 0.1
		return true
	return false


func _process(delta: float) -> void:
	if not is_open:
		return
	_freq_label.text = "FM %.1f MHz" % _slider.value
	if not _broadcast.is_empty():
		_process_broadcast(delta)
	else:
		_process_scan(delta)
	var pitch := float(_probe.get("signal", {}).get("voice_pitch", 1.0)) if not _probe.is_empty() else 1.0
	AudioManager.set_layer("radio_static", "static", 0.15 + 0.75 * (1.0 - _clarity), "Radio")
	AudioManager.set_layer("radio_voice", "radio_voice", _clarity * 0.9, "Radio", pitch)
	_strength.value = _clarity * 100.0
	for i in _levels.size():
		_levels[i] = lerpf(_levels[i], randf() * (1.0 - _clarity * 0.7) + _clarity * (0.4 + 0.6 * absf(sin(Time.get_ticks_msec() * 0.004 + i * 0.5))), 0.35)
	_wave.queue_redraw()


func _process_broadcast(delta: float) -> void:
	_broadcast_t += delta
	_clarity = clampf(_broadcast_t / 2.5, 0.0, 1.0)
	_probe = {"id": _broadcast.get("id", ""), "clarity": _clarity, "signal": _broadcast}
	_garble_t -= delta
	if _garble_t <= 0.0:
		_garble_t = 0.12
		_text.text = _garbled(GameState.format_text(str(_broadcast.get("text", ""))), _clarity)
	if _clarity >= 1.0 and not RadioManager.is_found(str(_broadcast.get("id", ""))):
		RadioManager.lock(str(_broadcast.id))
		_refresh_found()
		_status.text = "Сообщение записано в журнал."


func _process_scan(delta: float) -> void:
	_probe = RadioManager.probe(_slider.value, _station)
	_clarity = float(_probe.get("clarity", 0.0))
	var id := str(_probe.get("id", ""))
	_garble_t -= delta
	if _garble_t <= 0.0:
		_garble_t = 0.12
		if id.is_empty() or _clarity <= 0.02:
			if _showing_found.is_empty():
				_text.text = _garbled("                                        ", 0.0)
		else:
			_showing_found = ""
			_text.text = _garbled(GameState.format_text(str(_probe.signal.get("text", ""))), _clarity)
	if not id.is_empty() and _clarity >= RadioManager.LOCK_CLARITY and not RadioManager.is_found(id):
		_hold += delta
		_status.text = "Удерживайте… %d%%" % int(_hold / LOCK_TIME * 100.0)
		if _hold >= LOCK_TIME:
			_hold = 0.0
			if RadioManager.lock(id):
				_status.text = "Сигнал записан: %s" % _probe.signal.get("title", id)
				_refresh_found()
	else:
		_hold = 0.0
		if not id.is_empty() and RadioManager.is_found(id) and _clarity > 0.9:
			_status.text = "Сигнал уже записан."


func _garbled(text: String, clarity: float) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		if ch == " " or ch == "\n" or randf() < clarity * clarity:
			out += ch
		else:
			out += GARBLE[randi() % GARBLE.length()]
	return out


func _draw_wave() -> void:
	var w := _wave.size.x
	var h := _wave.size.y
	_wave.draw_rect(Rect2(Vector2.ZERO, _wave.size), Color(0.02, 0.03, 0.03, 0.9))
	var n := _levels.size()
	var bw := w / n
	for i in n:
		var bh := maxf(2.0, _levels[i] * h * 0.9)
		var c := Color(0.35, 0.9, 0.6).lerp(Color(0.5, 0.55, 0.6), 1.0 - _clarity)
		_wave.draw_rect(Rect2(i * bw + 1, (h - bh) * 0.5, bw - 2, bh), c)
