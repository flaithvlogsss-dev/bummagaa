class_name HUD
extends Control
## HUD — always-on information: health (top-left), temperature (bottom), day/time/weather
##   (top-right), needs, equipped weapon, interaction prompt, quest tracker, notifications,
##   hints, title cards and quest banners. Reacts to critical states by pulsing.
## Dependencies: GameState, TimeManager, WeatherManager, QuestManager, Main (player).

const NOTIFY_COLORS := {
	"item": Color(0.6, 0.92, 0.65), "warning": Color(1.0, 0.72, 0.35), "danger": Color(1.0, 0.4, 0.35),
	"quest": Color(1.0, 0.8, 0.45), "location": Color(0.6, 0.8, 1.0), "event": Color(0.85, 0.7, 1.0),
	"info": Color(0.88, 0.9, 0.93),
}

var _health: ProgressBar
var _health_label: Label
var _status_label: Label
var _temp: ProgressBar
var _temp_label: Label
var _needs: Dictionary = {}
var _clock: Label
var _day: Label
var _weather: Label
var _area: Label
var _prompt: Label
var _prompt_panel: PanelContainer
var _quest_title: Label
var _quest_objectives: Label
var _notify_box: VBoxContainer
var _hint_panel: PanelContainer
var _hint_label: Label
var _card: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_text: Label
var _weapon_label: Label
var _battery: ProgressBar
var _autosave: Label
var _debug: Label

var _player: Player
var _stats_dirty: bool = true
var _pulse_t: float = 0.0
var _hint_t: float = 0.0
var _debug_visible: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	GameState.stats.changed.connect(func(_s, _v): _stats_dirty = true)
	GameState.presentation_requested.connect(_on_presentation)
	TimeManager.minute_passed.connect(func(_d, _h, _m): _refresh_time())
	TimeManager.time_set.connect(_refresh_time)
	WeatherManager.weather_changed.connect(func(_s): _refresh_time())
	QuestManager.quest_started.connect(func(_q): _refresh_quest())
	QuestManager.quest_updated.connect(func(_q): _refresh_quest())
	QuestManager.objective_completed.connect(func(_q, _o): _refresh_quest())
	QuestManager.quest_completed.connect(func(_q): _refresh_quest())
	GameState.inventory.changed.connect(func(): _stats_dirty = true)


func set_debug_overlay(on: bool) -> void:
	_debug_visible = on
	_debug.visible = on


# --- Layout ---------------------------------------------------------------------------------

func _corner(preset: int, offset: Vector2, grow_left: bool = false, grow_up: bool = false) -> VBoxContainer:
	var v := UIKit.vbox(4)
	v.set_anchors_preset(preset)
	v.position = offset
	if grow_left:
		v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if grow_up:
		v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	return v


func _soft_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG_SOFT, Color(0.4, 0.46, 0.55, 0.6), 1, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build() -> void:
	# Top-left: health + statuses + quest tracker
	var tl := VBoxContainer.new()
	tl.position = Vector2(16, 14)
	tl.add_theme_constant_override("separation", 6)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tl)
	var hp_panel := _soft_panel()
	tl.add_child(hp_panel)
	var hp_box := UIKit.vbox(3)
	hp_panel.add_child(hp_box)
	_health_label = UIKit.label("ЗДОРОВЬЕ", 12, UIKit.TEXT_DIM)
	hp_box.add_child(_health_label)
	_health = UIKit.bar(Color(0.85, 0.25, 0.25), 12)
	_health.custom_minimum_size.x = 210
	hp_box.add_child(_health)
	_status_label = UIKit.label("", 12, UIKit.ACCENT)
	hp_box.add_child(_status_label)
	var q_panel := _soft_panel()
	q_panel.custom_minimum_size.x = 260
	tl.add_child(q_panel)
	var q_box := UIKit.vbox(2)
	q_panel.add_child(q_box)
	_quest_title = UIKit.label("", 14, UIKit.ACCENT)
	_quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_title.custom_minimum_size.x = 250
	q_box.add_child(_quest_title)
	_quest_objectives = UIKit.label("", 13)
	_quest_objectives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_objectives.custom_minimum_size.x = 250
	q_box.add_child(_quest_objectives)
	_debug = UIKit.label("", 12, Color(0.7, 1.0, 0.7))
	_debug.visible = false
	tl.add_child(_debug)

	# Top-right: day / time / weather / area
	var tr := _corner(Control.PRESET_TOP_RIGHT, Vector2(-16, 14), true)
	var tr_panel := _soft_panel()
	tr.add_child(tr_panel)
	var tr_box := UIKit.vbox(2)
	tr_panel.add_child(tr_box)
	_day = UIKit.label("", 13, UIKit.TEXT_DIM)
	_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr_box.add_child(_day)
	_clock = UIKit.label("", 26, UIKit.TEXT)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr_box.add_child(_clock)
	_weather = UIKit.label("", 13, UIKit.COLD)
	_weather.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr_box.add_child(_weather)
	_area = UIKit.label("", 12, UIKit.TEXT_DIM)
	_area.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr_box.add_child(_area)
	_notify_box = UIKit.vbox(4)
	_notify_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr.add_child(_notify_box)

	# Bottom-centre: temperature + needs
	var bottom := CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -118
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var bc := UIKit.vbox(6)
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bc)
	_prompt_panel = _soft_panel()
	_prompt_panel.visible = false
	bc.add_child(_prompt_panel)
	_prompt = UIKit.label("", 15, UIKit.TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt)
	var tp := _soft_panel()
	bc.add_child(tp)
	var tbox := UIKit.vbox(3)
	tp.add_child(tbox)
	_temp_label = UIKit.label("", 13, UIKit.COLD)
	_temp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tbox.add_child(_temp_label)
	_temp = UIKit.bar(UIKit.COLD, 12)
	_temp.custom_minimum_size.x = 380
	tbox.add_child(_temp)
	var needs := UIKit.hbox(10)
	tbox.add_child(needs)
	for n in [["hunger", "ЕДА", Color(0.85, 0.65, 0.3)], ["hydration", "ВОДА", Color(0.4, 0.7, 0.95)], ["stamina", "СИЛЫ", Color(0.6, 0.85, 0.5)], ["stress", "СТРЕСС", Color(0.75, 0.5, 0.85)]]:
		var col := UIKit.vbox(1)
		col.add_child(UIKit.label(n[1], 10, UIKit.TEXT_DIM))
		var b := UIKit.bar(n[2], 6)
		b.custom_minimum_size.x = 86
		col.add_child(b)
		needs.add_child(col)
		_needs[n[0]] = b

	# Bottom-right: weapon + flashlight
	var br := _corner(Control.PRESET_BOTTOM_RIGHT, Vector2(-16, -16), true, true)
	var br_panel := _soft_panel()
	br.add_child(br_panel)
	var br_box := UIKit.vbox(3)
	br_panel.add_child(br_box)
	_weapon_label = UIKit.label("", 13)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br_box.add_child(_weapon_label)
	br_box.add_child(UIKit.label("ФОНАРЬ [F]", 10, UIKit.TEXT_DIM))
	_battery = UIKit.bar(Color(1.0, 0.9, 0.5), 6)
	_battery.custom_minimum_size.x = 120
	br_box.add_child(_battery)
	_autosave = UIKit.label("", 11, UIKit.TEXT_DIM)
	_autosave.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_autosave)

	# Top-centre: hint
	var top := CenterContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 70
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var top_box := UIKit.vbox(10)
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_box)
	_banner = UIKit.vbox(0)
	_banner.visible = false
	top_box.add_child(_banner)
	_banner_title = UIKit.label("", 13, UIKit.ACCENT)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_text = UIKit.label("", 22)
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_text)
	_hint_panel = _soft_panel()
	_hint_panel.visible = false
	top_box.add_child(_hint_panel)
	_hint_label = UIKit.label("", 14)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size.x = 460
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint_label)

	# Centre: title card
	_card = UIKit.label("", 34, UIKit.TEXT)
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.modulate.a = 0.0
	add_child(_card)


# --- Updates -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var playing := Main.instance != null and Main.instance.mode == Main.Mode.PLAYING
	visible = playing
	if not playing:
		return
	if _player == null:
		_player = Main.get_player()
		if _player:
			_player.interaction_focus_changed.connect(_on_focus)
			_refresh_time()
			_refresh_quest()
	_pulse_t += delta
	if _stats_dirty:
		_stats_dirty = false
		_refresh_stats()
	_pulse_critical()
	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			_hint_panel.visible = false
	if _player:
		_area.text = _player.current_area if GameState.current_location == "district" else "Убежище"
		_weapon_label.text = _weapon_text()
		_battery.value = GameState.stats.flashlight_battery
		if _player.hiding_spot:
			_status_label.text = "Скрыт. " + _status_label.text.replace("Скрыт. ", "")
	if _debug_visible:
		_debug.text = DebugMenu.debug_text()


func _weapon_text() -> String:
	var w: WeaponData = _player.combat.get_weapon() if _player else null
	if w == null:
		return "Без оружия" if not GameState.inventory.has_item("pistol") else "Пистолет: [ПКМ] прицелиться"
	return "%s  %d / %d   [R]" % [w.name, GameState.stats.magazine, GameState.inventory.count(w.ammo_type)]


func _refresh_stats() -> void:
	var s := GameState.stats
	_health.value = s.health
	_temp.value = s.temperature
	for k in _needs.keys():
		_needs[k].value = s.get_value(k)
	_needs["stamina"].max_value = 100.0
	var trend := ""
	if _player:
		var r := _player.survival.get_temperature_trend()
		trend = "  ▲" if r > 0.05 else ("  ▼" if r < -0.05 else "")
	_temp_label.text = "%s  •  на улице %d°C%s" % [warmth_word(s.temperature), int(round(WeatherManager.temperature)), trend]
	var st: PackedStringArray = _player.survival.get_statuses() if _player else PackedStringArray()
	var words: PackedStringArray = []
	for key in st:
		words.append({"freezing": "Замерзание", "cold": "Холод", "hungry": "Голод", "thirsty": "Жажда", "bleeding": "Кровотечение", "ill": "Болезнь", "overweight": "Перегруз", "stressed": "Паника", "warm_pack": "Грелка", "warming": "Греется"}.get(key, key))
	_status_label.text = ", ".join(words)


static func warmth_word(t: float) -> String:
	if t > 70.0:
		return "Тепло"
	if t > 45.0:
		return "Прохладно"
	if t > 30.0:
		return "Холодно"
	if t > 15.0:
		return "Очень холодно"
	return "ПЕРЕОХЛАЖДЕНИЕ"


func _pulse_critical() -> void:
	var s := GameState.stats
	var pulse := 0.6 + 0.4 * sin(_pulse_t * 6.0)
	_health.modulate = Color(1, pulse, pulse) if s.health < 30.0 else Color.WHITE
	_temp.modulate = Color(pulse, pulse, 1) if s.temperature < 30.0 else Color.WHITE
	_temp_label.modulate = _temp.modulate
	for k in ["hunger", "hydration"]:
		_needs[k].modulate = Color(1, pulse, pulse) if s.get_value(k) < 15.0 else Color.WHITE


func _refresh_time() -> void:
	_day.text = "ДЕНЬ %d%s" % [TimeManager.current_day, "  •  НОЧЬ" if TimeManager.is_night() else ""]
	_clock.text = TimeManager.format_clock()
	_weather.text = "%s  %d°C" % [WeatherManager.get_display_name(), int(round(WeatherManager.temperature))]


func _refresh_quest() -> void:
	var id := QuestManager.get_tracked()
	if id.is_empty():
		_quest_title.get_parent().get_parent().visible = false
		return
	_quest_title.get_parent().get_parent().visible = true
	var q := Data.get_quest(id)
	_quest_title.text = str(q.get("title", id))
	var lines: PackedStringArray = []
	for o in QuestManager.get_objectives(id):
		lines.append(("✓ " if o.done else "• ") + o.text)
	_quest_objectives.text = "\n".join(lines)


func _on_focus(target: Interactable) -> void:
	if target == null or not is_instance_valid(target):
		_prompt_panel.visible = false
		return
	_prompt.text = "[%s]  %s" % [InputBindings.describe("interact"), target.get_prompt()]
	_prompt_panel.visible = true


func _on_presentation(kind: String, data: Dictionary) -> void:
	match kind:
		"notify":
			_add_notification(str(data.get("text", "")), str(data.get("kind", "info")))
		"hint":
			_hint_label.text = str(data.get("text", ""))
			_hint_panel.visible = true
			_hint_t = float(data.get("duration", 7.0))
		"title_card":
			_show_card(str(data.get("text", "")))
		"quest_banner":
			_show_banner(str(data.get("title", "")), str(data.get("text", "")))
			_refresh_quest()
		"autosave":
			_autosave.text = "Автосохранение…"
			var t := create_tween()
			t.tween_interval(2.0)
			t.tween_callback(func(): _autosave.text = "")


func _add_notification(text: String, kind: String) -> void:
	if text.is_empty():
		return
	var l := UIKit.label(text, 14, NOTIFY_COLORS.get(kind, UIKit.TEXT))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300
	_notify_box.add_child(l)
	while _notify_box.get_child_count() > 6:
		var old := _notify_box.get_child(0)
		_notify_box.remove_child(old)
		old.queue_free()
	var t := l.create_tween()
	t.tween_interval(4.5)
	t.tween_property(l, "modulate:a", 0.0, 0.8)
	t.tween_callback(l.queue_free)


func _show_card(text: String) -> void:
	_card.text = text
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 1.0, 0.8)
	t.tween_interval(2.4)
	t.tween_property(_card, "modulate:a", 0.0, 1.2)


func _show_banner(title_text: String, text: String) -> void:
	_banner_title.text = title_text
	_banner_text.text = text
	_banner.visible = true
	_banner.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_banner, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.8)
	t.tween_property(_banner, "modulate:a", 0.0, 0.8)
	t.tween_callback(func(): _banner.visible = false)
