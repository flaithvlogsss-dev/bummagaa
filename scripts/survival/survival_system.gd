class_name SurvivalSystem
extends Node
## SurvivalSystem — simulates the player's body against the environment.
##
## Purpose: temperature depends on outside temperature, wind, snow intensity (WeatherManager),
##   clothing insulation, being indoors, heat sources and the body state. Hunger and hydration
##   drain with game time; stamina drains while sprinting; contaminated air is handled by the
##   ExposureSystem (ticked from here). Critical states hurt slowly so the player has time to
##   understand what is happening.
## Dependencies: GameState.stats (PlayerStats), WeatherManager, TimeManager, current Level.
## Public API: enter_indoor/exit_indoor, enter_heat/exit_heat, reset_zones, set_level,
##   use_stamina, can_sprint, get_speed_multiplier, is_indoors, is_heated, apply_sleep,
##   apply_rest, get_statuses, get_temperature_trend
## Signals: status_changed(statuses), went_outdoors, warmed_up
## Save Data: values live in GameState.stats.

signal status_changed(statuses: PackedStringArray)
signal went_outdoors
signal warmed_up

const TICK := 0.2
## Body heat lost per second outdoors in LIGHT snow before modifiers.
const BASE_COLD_LOSS := 0.2
## Full to empty in 24 / 16 game hours (with time_speed 0.25: ~96 / ~64 real minutes).
const HUNGER_PER_GAME_MINUTE := 100.0 / (24.0 * 60.0)
const HYDRATION_PER_GAME_MINUTE := 100.0 / (16.0 * 60.0)
const STAMINA_REGEN := 16.0
const FLASHLIGHT_DRAIN := 100.0 / 600.0

var enabled: bool = true
var sprinting: bool = false
var moving: bool = false
var temperature_trend: float = 0.0
## Contaminated air + gas mask (set by the Player; optional in tests).
var exposure: ExposureSystem

var _level: Level
var _indoor_zones: Array = []
var _heat_zones: Array = []
var _acc: float = 0.0
var _since_stamina_use: float = 10.0
var _statuses: PackedStringArray = PackedStringArray()
var _was_outdoors: bool = false


func _physics_process(delta: float) -> void:
	_since_stamina_use += delta
	_acc += delta
	if _acc >= TICK:
		tick(_acc)
		_acc = 0.0


func set_level(level: Level) -> void:
	_level = level
	reset_zones()


func reset_zones() -> void:
	_indoor_zones.clear()
	_heat_zones.clear()


func enter_indoor(zone: Node) -> void:
	if not _indoor_zones.has(zone):
		_indoor_zones.append(zone)


func exit_indoor(zone: Node) -> void:
	_indoor_zones.erase(zone)


func enter_heat(zone: Node) -> void:
	if not _heat_zones.has(zone):
		_heat_zones.append(zone)


func exit_heat(zone: Node) -> void:
	_heat_zones.erase(zone)


func is_indoors() -> bool:
	return (_level != null and _level.is_interior) or not _indoor_zones.is_empty()


func is_heated() -> bool:
	if _level != null and _level.is_interior:
		return _level.is_heated()
	for z in _indoor_zones:
		if is_instance_valid(z) and z.is_heated():
			return true
	return false


func heat_strength() -> float:
	var total := 0.0
	for z in _heat_zones:
		if is_instance_valid(z) and z.is_active():
			total += z.strength
	return total


# --- Simulation ------------------------------------------------------------------------------

## One simulation step of `dt` real seconds (public so tests can drive it).
func tick(dt: float) -> void:
	if not enabled:
		return
	var s := GameState.stats
	if s.dead:
		return
	var game_minutes := dt * TimeManager.time_speed if TimeManager.running else 0.0
	var outdoors := not is_indoors()
	if outdoors and not _was_outdoors:
		went_outdoors.emit()
	_was_outdoors = outdoors

	# Temperature
	var rate := _temperature_rate(outdoors)
	temperature_trend = rate
	var before := s.temperature
	s.modify("temperature", rate * dt)
	if before < 40.0 and s.temperature >= 40.0 and rate > 0.0:
		warmed_up.emit()

	# Food and water (game time)
	s.modify("hunger", -HUNGER_PER_GAME_MINUTE * game_minutes)
	s.modify("hydration", -HYDRATION_PER_GAME_MINUTE * game_minutes * (1.15 if sprinting else 1.0))

	# Air
	if exposure:
		exposure.sprinting = sprinting
		exposure.tick(dt)

	# Stamina
	var starving := s.hunger < 15.0 or s.hydration < 15.0
	s.max_stamina = 100.0 * (0.7 if starving else 1.0) * (0.8 if s.illness else 1.0)
	if exposure:
		s.max_stamina *= exposure.stamina_factor()
	if _since_stamina_use > 0.9:
		var regen := STAMINA_REGEN
		if s.temperature < 30.0:
			regen *= 0.5
		if s.stress > 75.0:
			regen *= 0.7
		if s.illness:
			regen *= 0.6
		if exposure and exposure.is_wearing():
			regen *= 0.8
		s.modify("stamina", regen * dt)
	if s.stamina > s.max_stamina:
		s.set_value("stamina", s.max_stamina)

	# Health from critical states (slow on purpose)
	var damage := 0.0
	if s.temperature < 15.0:
		damage += 0.35 if s.temperature >= 5.0 else 0.8
	if s.hunger <= 0.0:
		damage += 0.08
	if s.hydration <= 0.0:
		damage += 0.12
	if s.bleeding > 0.0:
		damage += 0.5
		s.bleeding = maxf(0.0, s.bleeding - dt)
	if exposure:
		damage += exposure.damage_rate()
	if damage > 0.0:
		s.modify("health", -damage * dt)
	elif s.temperature > 50.0 and s.hunger > 30.0 and s.hydration > 30.0 and s.health < 100.0:
		s.modify("health", 0.05 * dt)

	# Stress
	var stress_rate := 0.0
	if outdoors:
		if TimeManager.is_dark() and not s.flashlight_on:
			stress_rate += 0.15
		stress_rate += WeatherManager.stress_rate * 2.0
	elif is_heated():
		stress_rate -= 0.25 + 0.05 * GameState.survivors_in_shelter().size()
	else:
		stress_rate -= 0.05
	if s.temperature < 30.0:
		stress_rate += 0.1
	if s.exposure >= 55.0:
		stress_rate += 0.12
	if s.vitamins > 0.0:
		s.vitamins = maxf(0.0, s.vitamins - game_minutes)
	s.modify("stress", stress_rate * dt)

	# Timed statuses
	if s.warm_pack_time > 0.0:
		s.warm_pack_time = maxf(0.0, s.warm_pack_time - dt)
	if s.flashlight_on:
		s.flashlight_battery = maxf(0.0, s.flashlight_battery - FLASHLIGHT_DRAIN * dt)
		if s.flashlight_battery <= 0.0:
			s.flashlight_on = false
			GameState.notify("Фонарь сел.", "warning")
	elif is_indoors() and GameState.has_flag("power_on") and GameState.current_location == "shelter":
		s.flashlight_battery = minf(100.0, s.flashlight_battery + 0.5 * dt)
	_update_statuses()


func _temperature_rate(outdoors: bool) -> float:
	var s := GameState.stats
	var rate := 0.0
	if outdoors:
		var loss := BASE_COLD_LOSS * WeatherManager.cold_rate * (1.0 + WeatherManager.wind * 0.35)
		if TimeManager.is_dark():
			loss *= 1.25
		loss *= 1.0 - GameState.inventory.get_insulation()
		if s.warm_pack_time > 0.0:
			loss *= 0.4
		if sprinting:
			loss *= 0.8
		if s.illness:
			loss *= 1.2
		rate = -loss
	elif is_heated():
		rate = 1.1
	else:
		# Unheated rooms stop the bleeding of heat and settle around 65.
		rate = 0.35 if s.temperature < 65.0 else -0.02
		if WeatherManager.is_severe():
			rate *= 0.5
	rate += heat_strength()
	return rate


func get_temperature_trend() -> float:
	return temperature_trend


# --- Actions ------------------------------------------------------------------------------------

func use_stamina(amount: float) -> void:
	GameState.stats.modify("stamina", -amount)
	_since_stamina_use = 0.0


func can_sprint() -> bool:
	var s := GameState.stats
	if exposure and exposure.is_putting_on():
		return false
	return s.stamina > 3.0 and not GameState.inventory.is_overweight()


func get_speed_multiplier() -> float:
	var s := GameState.stats
	var m := 1.0
	if GameState.inventory.is_overweight():
		m *= 0.75
	if s.temperature < 15.0:
		m *= 0.8
	elif s.temperature < 30.0:
		m *= 0.9
	if s.health < 25.0:
		m *= 0.85
	if not is_indoors():
		m *= 1.0 - 0.12 * GameState.world.get_snow_level() - 0.1 * WeatherManager.wind * WeatherManager.intensity
	return m


## Sleeping through the night.
func apply_sleep(hours: float) -> void:
	var s := GameState.stats
	var bag := GameState.inventory.has_item("sleeping_bag")
	s.modify("hunger", -1.6 * hours)
	s.modify("hydration", -2.0 * hours)
	s.set_value("stamina", s.max_stamina)
	s.modify("stress", -25.0 - (8.0 if bag else 0.0))
	if s.hunger > 20.0 and s.hydration > 20.0:
		s.modify("health", 15.0 + (5.0 if bag else 0.0))
	s.set_value("temperature", 100.0 if is_heated() else maxf(s.temperature, 70.0 if bag else 55.0))
	s.modify("exposure", -(8.0 if GameState.current_location == "shelter" else 2.0) * hours)
	s.bleeding = 0.0
	s.flashlight_battery = 100.0


## A short rest (1-3 hours) on a bed: some stamina, calm and healing, the clock moves on.
func apply_rest(hours: float) -> void:
	var s := GameState.stats
	s.modify("hunger", -HUNGER_PER_GAME_MINUTE * 60.0 * hours * 0.7)
	s.modify("hydration", -HYDRATION_PER_GAME_MINUTE * 60.0 * hours * 0.7)
	s.modify("stamina", 35.0 * hours)
	s.modify("stress", -6.0 * hours)
	if s.hunger > 20.0 and s.hydration > 20.0:
		s.modify("health", 3.0 * hours)
	if is_heated():
		s.modify("temperature", 20.0 * hours)
	s.modify("exposure", -(6.0 if GameState.current_location == "shelter" else 1.5) * hours)


func get_statuses() -> PackedStringArray:
	return _statuses


func _update_statuses() -> void:
	var s := GameState.stats
	var list := PackedStringArray()
	if s.temperature < 15.0:
		list.append("freezing")
	elif s.temperature < 30.0:
		list.append("cold")
	if s.hunger < 15.0:
		list.append("hungry")
	if s.hydration < 15.0:
		list.append("thirsty")
	if s.bleeding > 0.0:
		list.append("bleeding")
	if s.illness:
		list.append("ill")
	if GameState.inventory.is_overweight():
		list.append("overweight")
	if s.stress > 75.0:
		list.append("stressed")
	if s.warm_pack_time > 0.0:
		list.append("warm_pack")
	if heat_strength() > 0.0 or (is_indoors() and is_heated()):
		list.append("warming")
	if s.exposure >= 80.0:
		list.append("choking")
	elif s.exposure >= 55.0:
		list.append("poisoned")
	elif s.exposure >= 30.0:
		list.append("contaminated")
	if exposure and exposure.zone() == "outdoor" and not exposure.is_wearing():
		list.append("mask_off")
	elif exposure and exposure.is_wearing() and exposure.zone() != "shelter":
		if not exposure.has_filter():
			list.append("no_filter")
		elif exposure.filter_fraction() < ExposureSystem.FILTER_LOW:
			list.append("filter_low")
	if list != _statuses:
		_statuses = list
		status_changed.emit(list)
