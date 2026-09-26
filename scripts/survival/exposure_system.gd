class_name ExposureSystem
extends Node
## ExposureSystem — poisoned air, the gas mask and its filter.
##
## Purpose: outside, the snow-laden air is contaminated. Exposure (GameState.stats.exposure,
##   0..100) rises fast without a mask, slowly through a working filter and very slowly inside
##   closed buildings; the shelter's filtered air is clean and lets it fall. Weather multiplies
##   both the contamination and how fast a filter is spent (WeatherManager.contamination /
##   filter_drain). The mask only protects the lungs: it does nothing against cold or hunger.
##   The worn mask's filter is spent in game minutes; its condition wears outdoors and when hit.
## States: SAFE < 10 <= LOW < 30 <= MEDIUM < 55 <= HIGH < 80 <= CRITICAL.
## Effects (read by SurvivalSystem): stamina cap, health loss, coughing (a noise enemies hear).
## Dependencies: GameState (stats, inventory), WeatherManager, TimeManager, Stealth, AudioManager.
## Public API: tick(dt), get_state(), get_state_name(), zone(), is_wearing(), has_filter(),
##   filter_fraction(), get_protection(), gain_rate(), toggle_mask(), set_mask_on(),
##   stamina_factor(), damage_rate()
## Signals: state_changed(state), mask_toggled(on), filter_low, filter_empty, coughed
## Save Data: exposure and mask_on live in GameState.stats; the filter in the mask stack.

signal state_changed(state: int)
signal mask_toggled(on: bool)
signal filter_low
signal filter_empty
signal coughed

enum State { SAFE, LOW, MEDIUM, HIGH, CRITICAL }

const THRESHOLDS: Array[float] = [10.0, 30.0, 55.0, 80.0]
const STATE_NAMES: Array[String] = ["БЕЗОПАСНО", "НИЗКОЕ", "СРЕДНЕЕ", "ВЫСОКОЕ", "КРИТИЧЕСКОЕ"]
const STATE_COLORS: Array[Color] = [Color(0.55, 0.9, 0.6), Color(0.8, 0.9, 0.5), Color(1.0, 0.8, 0.35), Color(1.0, 0.5, 0.25), Color(1.0, 0.25, 0.2)]
## Exposure per real second outdoors with no protection, in light snow.
const BASE_RATE := 0.8
## Closed buildings in the city: the air still seeps in, but slowly.
const INDOOR_FACTOR := 0.08
## Exposure lost per real second in the shelter's filtered air.
const SHELTER_RECOVERY := 0.1
## A mask with no filter (or a spent one) still stops a little.
const MASK_WITHOUT_FILTER := 0.15
## A cracked mask (condition 0) leaks.
const BROKEN_MASK_FACTOR := 0.35
const MASK_WEAR_PER_SECOND := 0.01
const FILTER_LOW := 0.2
## Seconds it takes to pull the mask on (no sprinting meanwhile).
const MASK_ON_TIME := 0.9

var enabled: bool = true
## Set by the player: sprinting breathes harder through the filter.
var sprinting: bool = false
var survival: SurvivalSystem

var _state: int = State.SAFE
var _cough_t: float = 8.0
var _low_warned: bool = false
var _empty_warned: bool = false
var _mask_busy: float = 0.0


func _ready() -> void:
	_state = _state_for(GameState.stats.exposure)


# --- Queries ------------------------------------------------------------------------------------

func get_state() -> int:
	return _state


func get_state_name() -> String:
	return STATE_NAMES[_state]


static func state_for_value(v: float) -> int:
	var st := 0
	for i in THRESHOLDS.size():
		if v >= THRESHOLDS[i]:
			st = i + 1
	return st


func _state_for(v: float) -> int:
	return ExposureSystem.state_for_value(v)


## "shelter" (clean air), "indoor" (closed building in the city) or "outdoor".
func zone() -> String:
	if GameState.current_location == "shelter":
		return "shelter"
	if survival and survival.is_indoors():
		return "indoor"
	return "outdoor"


func is_wearing() -> bool:
	return GameState.stats.mask_on and not GameState.inventory.get_equipped("mask").is_empty()


func is_putting_on() -> bool:
	return _mask_busy > 0.0


func has_filter() -> bool:
	return GameState.inventory.get_mask_filter_left() > 0.0


## Remaining filter charge 0..1 (0 when there is no mask or filter).
func filter_fraction() -> float:
	var mask := GameState.inventory.get_equipped_stack("mask")
	var d: Dictionary = mask.get("data", {})
	var f := Data.get_item(str(d.get("filter", ""))) if not str(d.get("filter", "")).is_empty() else null
	if f == null:
		return 0.0
	return clampf(float(d.get("filter_left", 0.0)) / maxf(f.filter_capacity, 1.0), 0.0, 1.0)


## Share of contamination blocked right now, 0..~0.98.
func get_protection() -> float:
	if not is_wearing() or is_putting_on():
		return 0.0
	var mask := GameState.inventory.get_equipped_stack("mask")
	var item := Data.get_item(str(mask.id))
	if item == null:
		return 0.0
	# Quality: a poor mask seals worse, a good one a touch better.
	var q_mult: float = [0.9, 1.0, 1.02, 1.04][clampi(int(mask.get("q", 1)), 0, 3)]
	var eff := minf(item.mask_efficiency * q_mult, 0.99)
	if float(mask.get("cond", 100.0)) <= 0.0:
		eff *= BROKEN_MASK_FACTOR
	var d: Dictionary = mask.get("data", {})
	var f := Data.get_item(str(d.get("filter", ""))) if not str(d.get("filter", "")).is_empty() else null
	if f == null or float(d.get("filter_left", 0.0)) <= 0.0:
		return MASK_WITHOUT_FILTER * eff
	return clampf(eff * f.filter_efficiency, 0.0, 0.99)


## Exposure gained per real second in the current place (negative = recovering).
func gain_rate() -> float:
	match zone():
		"shelter":
			return -SHELTER_RECOVERY
		"indoor":
			return BASE_RATE * INDOOR_FACTOR * WeatherManager.contamination * (1.0 - get_protection())
	return BASE_RATE * WeatherManager.contamination * (1.0 - get_protection())


## Multiplier for max stamina: contamination in the lungs plus the mask's breathing resistance.
func stamina_factor() -> float:
	var f: float = [1.0, 1.0, 0.9, 0.75, 0.55][_state]
	if is_wearing():
		var item := GameState.inventory.get_equipped_item("mask")
		if item:
			f *= 1.0 - item.mask_visibility * 0.3
		if has_filter() and filter_fraction() < FILTER_LOW:
			f *= 0.85
	return f


## Health lost per real second from exposure.
func damage_rate() -> float:
	var v := GameState.stats.exposure
	if v >= 100.0:
		return 1.0
	match _state:
		State.CRITICAL:
			return 0.35
		State.HIGH:
			return 0.06
	return 0.0


# --- Mask control ------------------------------------------------------------------------------

## [G]: pulls the worn mask on or off. With no mask worn it puts on the first one carried.
func toggle_mask() -> bool:
	var inv := GameState.inventory
	if inv.get_equipped("mask").is_empty():
		for s in inv.get_slots():
			var item := Data.get_item(str(s.get("id", ""))) if not s.is_empty() else null
			if item and item.equip_slot == "mask":
				inv.equip(item.id)
				return set_mask_on(true)
		GameState.notify("Маски нет. Противогазы бывают в аптеках, шкафчиках ГО и у мёртвых.", "warning")
		return false
	return set_mask_on(not GameState.stats.mask_on)


func set_mask_on(on: bool) -> bool:
	var s := GameState.stats
	if s.mask_on == on:
		return false
	if on and GameState.inventory.get_equipped("mask").is_empty():
		return false
	s.mask_on = on
	_mask_busy = MASK_ON_TIME if on else 0.0
	AudioManager.play_sfx("mask_on" if on else "mask_off", null, -2.0, 1.0, "Body")
	if on and not has_filter():
		GameState.notify("В маске нет фильтра — она почти не защищает. Вставь фильтр в рюкзаке.", "warning")
	s.changed.emit("status", 0.0)
	mask_toggled.emit(on)
	return true


# --- Simulation ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_mask_busy = maxf(0.0, _mask_busy - delta)


var _visor_on: bool = false


## Breathing through the filter and the muffled world outside the visor.
func _process(_delta: float) -> void:
	var wearing := is_wearing() and not GameState.stats.dead
	if wearing:
		var strained := not has_filter() or filter_fraction() < FILTER_LOW
		var pitch := 1.0 + (0.3 if sprinting else 0.0) + (1.0 - GameState.stats.stamina / 100.0) * 0.25
		AudioManager.set_layer("mask_breath", "mask_breath_strained" if strained else "mask_breath", 0.5, "Body", pitch)
	else:
		AudioManager.stop_layer("mask_breath")
	var visor := wearing and zone() != "shelter"
	if visor != _visor_on:
		_visor_on = visor
		AudioManager.set_visor(visor)


func _exit_tree() -> void:
	AudioManager.stop_layer("mask_breath")
	if _visor_on:
		AudioManager.set_visor(false)


## One step of `dt` real seconds (driven by SurvivalSystem.tick).
func tick(dt: float) -> void:
	if not enabled:
		return
	var s := GameState.stats
	if s.dead:
		return
	s.modify("exposure", gain_rate() * dt)
	var where := zone()
	var game_minutes := dt * TimeManager.time_speed if TimeManager.running else 0.0
	if is_wearing() and where != "shelter":
		_spend_filter(game_minutes * WeatherManager.filter_drain * (0.3 if where == "indoor" else 1.0) * (1.4 if sprinting else 1.0))
		if where == "outdoor":
			GameState.inventory.damage_equipped("mask", MASK_WEAR_PER_SECOND * dt * (1.0 + WeatherManager.wind))
	var st := _state_for(s.exposure)
	if st != _state:
		var worse := st > _state
		_state = st
		state_changed.emit(st)
		if worse and st >= State.MEDIUM:
			GameState.notify("Заражение: %s" % STATE_NAMES[st].to_lower(), "danger" if st >= State.HIGH else "warning")
	_update_cough(dt)


func _spend_filter(minutes: float) -> void:
	if minutes <= 0.0:
		return
	var mask := GameState.inventory.get_equipped_stack("mask")
	var d: Dictionary = mask.get("data", {})
	if str(d.get("filter", "")).is_empty():
		return
	var left := float(d.get("filter_left", 0.0))
	if left <= 0.0:
		return
	left = maxf(0.0, left - minutes)
	d["filter_left"] = left
	var frac := filter_fraction()
	if frac < FILTER_LOW and not _low_warned:
		_low_warned = true
		GameState.notify("Фильтр на исходе — дышать всё тяжелее.", "warning")
		filter_low.emit()
	elif frac >= FILTER_LOW:
		_low_warned = false
	if left <= 0.0 and not _empty_warned:
		_empty_warned = true
		GameState.notify("Фильтр забит. Нужен новый — или назад, в убежище.", "danger")
		AudioManager.play_sfx("filter_clog", null, 0.0, 1.0, "Body")
		filter_empty.emit()
	elif left > 0.0:
		_empty_warned = false


func _update_cough(dt: float) -> void:
	if _state < State.MEDIUM:
		_cough_t = randf_range(8.0, 16.0)
		return
	_cough_t -= dt
	if _cough_t > 0.0:
		return
	match _state:
		State.MEDIUM:
			_cough_t = randf_range(14.0, 26.0)
		State.HIGH:
			_cough_t = randf_range(7.0, 13.0)
		_:
			_cough_t = randf_range(3.0, 6.0)
	cough()


func cough() -> void:
	var s := GameState.stats
	s.modify("stamina", -6.0)
	AudioManager.play_sfx("cough", null, -6.0 if is_wearing() else 0.0, randf_range(0.9, 1.1), "Body")
	GameState.present("shake", {"amount": 0.08})
	var player := get_parent() as Node3D
	if player and player.is_inside_tree():
		# Coughing gives you away; a mask muffles it a little.
		Stealth.emit_noise(player.get_tree(), player.global_position, 0.45 if is_wearing() else 0.6, "player")
	coughed.emit()
