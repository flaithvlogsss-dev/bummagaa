class_name PlayerStats
extends RefCounted
## PlayerStats — the player's survival values (0..100) plus small status data.
##
## Purpose: single source of truth for Health, Hunger, Hydration, Temperature (body warmth),
##   Stamina, Stress and Exposure (contamination; the only stat where higher is worse). SurvivalSystem changes them, HUD and saves read them.
## Signals: changed(stat, value), died
## Save Data: serialize()/deserialize()

signal changed(stat: String, value: float)
signal died

const STATS: Array[String] = ["health", "hunger", "hydration", "temperature", "stamina", "stress", "exposure"]

var health: float = 100.0
var hunger: float = 85.0
var hydration: float = 80.0
## Body warmth, 100 = warm, 0 = hypothermic.
var temperature: float = 90.0
var stamina: float = 100.0
var stress: float = 15.0
## Accumulated contamination from breathing outside air, 0 = clean, 100 = lethal.
var exposure: float = 0.0
var max_stamina: float = 100.0

## Seconds of bleeding left (0 = not bleeding).
var bleeding: float = 0.0
var illness: bool = false
## Seconds left on a warm pack.
var warm_pack_time: float = 0.0
## Game minutes of vitamin protection (halves illness chances).
var vitamins: float = 0.0
var flashlight_on: bool = false
var flashlight_battery: float = 100.0
var dead: bool = false
var god_mode: bool = false


func get_value(stat: String) -> float:
	if stat in STATS:
		return float(get(stat))
	return 0.0


func set_value(stat: String, value: float) -> void:
	if not stat in STATS:
		push_warning("PlayerStats: unknown stat '%s'" % stat)
		return
	var upper := max_stamina if stat == "stamina" else 100.0
	var v := clampf(value, 0.0, upper)
	if stat == "health" and god_mode:
		v = maxf(v, 1.0)
	if is_equal_approx(v, float(get(stat))):
		return
	set(stat, v)
	changed.emit(stat, v)
	if stat == "health" and v <= 0.0 and not dead:
		dead = true
		died.emit()


func modify(stat: String, delta: float) -> void:
	set_value(stat, get_value(stat) + delta)


func reset() -> void:
	health = 100.0
	hunger = 85.0
	hydration = 80.0
	temperature = 90.0
	stamina = 100.0
	stress = 15.0
	exposure = 0.0
	max_stamina = 100.0
	bleeding = 0.0
	illness = false
	warm_pack_time = 0.0
	vitamins = 0.0
	flashlight_on = false
	flashlight_battery = 100.0
	dead = false
	for s in STATS:
		changed.emit(s, get_value(s))


func serialize() -> Dictionary:
	var d := {}
	for s in STATS:
		d[s] = get_value(s)
	d["max_stamina"] = max_stamina
	d["bleeding"] = bleeding
	d["illness"] = illness
	d["warm_pack_time"] = warm_pack_time
	d["flashlight_on"] = flashlight_on
	d["flashlight_battery"] = flashlight_battery
	d["vitamins"] = vitamins
	return d


func deserialize(d: Dictionary) -> void:
	reset()
	for s in STATS:
		if d.has(s):
			set(s, clampf(float(d[s]), 0.0, 100.0))
	max_stamina = float(d.get("max_stamina", 100.0))
	bleeding = float(d.get("bleeding", 0.0))
	illness = bool(d.get("illness", false))
	warm_pack_time = float(d.get("warm_pack_time", 0.0))
	flashlight_on = bool(d.get("flashlight_on", false))
	flashlight_battery = float(d.get("flashlight_battery", 100.0))
	vitamins = float(d.get("vitamins", 0.0))
	dead = health <= 0.0
	if dead:
		health = 25.0
		dead = false
	for s in STATS:
		changed.emit(s, get_value(s))
