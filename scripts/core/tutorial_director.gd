class_name TutorialDirector
extends Node
## TutorialDirector — one-time contextual hints (cold, heat, inventory, flashlight, danger).
## Each hint is remembered as a "tut_*" flag, so it is shown once per playthrough.

var _t: float = 0.0


func _ready() -> void:
	GameState.inventory.item_added.connect(func(_id, _n): _once("tut_inventory", "Предмет в рюкзаке. [I] — открыть рюкзак, использовать или надеть вещи."))
	QuestManager.quest_started.connect(func(_q): _once("tut_journal", "[Q] — журнал заданий, записей и людей. [M] — карта с метками."))
	RadioManager.radio_signal_found.connect(func(_s): _once("tut_radio", "Сигнал сохранён в журнале [Q] → Записи."))


func _once(flag: String, text: String, duration: float = 8.0) -> void:
	if GameState.has_flag(flag) or not GameState.has_flag("intro_done") and flag != "tut_intro":
		return
	GameState.set_flag(flag, true)
	GameState.hint(text, duration)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	if Main.instance == null or Main.instance.mode != Main.Mode.PLAYING:
		return
	var player := Main.get_player()
	if player == null:
		return
	var s := GameState.stats
	var outdoors := not player.survival.is_indoors()
	if outdoors:
		_once("tut_cold", "Снег вытягивает тепло. Следите за термометром внизу экрана. Греться можно в помещениях и у огня. Бег [Shift] немного согревает, но тратит силы.", 10.0)
	if outdoors and s.temperature < 55.0:
		_once("tut_cold2", "Вы замерзаете. Найдите огонь или зайдите в здание. Тёплая одежда из рюкзака сильно замедляет охлаждение.")
	if player.survival.heat_strength() > 0.0:
		_once("tut_heat", "Огонь быстро согревает. Запомните это место — отметьте его на карте [M].")
	if outdoors and TimeManager.is_dark() and not s.flashlight_on and GameState.inventory.has_item("flashlight"):
		_once("tut_flashlight", "[F] — фонарь. Со светом вы видите больше, но и вас видно издалека.")
	if GameState.has_flag("stalker_encountered"):
		_once("tut_stalker", "Не обязательно драться. Бегите [Shift], прячьтесь за мусорными баками [E] или идите тихо [Ctrl]. Выстрел слышно далеко.", 10.0)
	if s.bleeding > 0.0:
		_once("tut_bleeding", "Кровотечение. Используйте бинт из рюкзака [I].")
	if s.hunger < 35.0 or s.hydration < 35.0:
		_once("tut_needs", "Голод и жажда растут со временем. Ешьте и пейте из рюкзака [I].")
	if GameState.current_location == "shelter" and GameState.has_flag("first_squall_done"):
		_once("tut_shelter", "В убежище: склад хранит припасы, в мастерской можно создавать вещи и улучшать убежище. Ночью можно лечь спать.", 10.0)
	if TimeManager.current_hour >= 22 or TimeManager.is_night():
		_once("tut_sleep", "Уже поздно. Кровать в убежище пропустит ночь до утра — но ночь не всегда спокойна.")
