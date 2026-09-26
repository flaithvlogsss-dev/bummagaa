extends Node
## WeatherManager — current weather, transitions and derived modifiers.
##
## Purpose: owns weather state (LIGHT / HEAVY / BLIZZARD), blends every parameter smoothly,
##   follows the per-day schedule in data/world/days.json and supports forced weather from
##   events (the first squall). Visuals (particles, fog, audio) only *read* from here;
##   no weather logic lives in the player.
## Dependencies: Data (WeatherPreset resources + days table), TimeManager, GameState.world.
## Public API: set_weather(), force_weather(), get_state(), get_display_name(), is_severe(),
##   intensity / wind / visibility / temperature / cold_rate / stamina_cost / noise_mask ...
## Signals: weather_changed(state), weather_updated
## Save Data: state, forced state + expiry, blended values.

signal weather_changed(state: String)
signal weather_updated

const STATES: Array[String] = ["LIGHT", "HEAVY", "BLIZZARD"]
const FIELDS: Array[String] = ["intensity", "wind", "visibility", "temperature", "cold_rate", "stamina_cost", "footprint_fade", "noise_mask", "stress_rate"]

var state: String = "LIGHT"
var intensity: float = 0.2
var wind: float = 0.1
var visibility: float = 60.0
var temperature: float = -8.0
var cold_rate: float = 1.0
var stamina_cost: float = 1.0
var footprint_fade: float = 1.0
var noise_mask: float = 0.0
var stress_rate: float = 0.0
## Direction the wind blows towards (XZ).
var wind_direction: Vector2 = Vector2(0.8, 0.35).normalized()

var _from: Dictionary = {}
var _to: Dictionary = {}
var _blend: float = 1.0
var _blend_minutes: float = 20.0
var _forced_state: String = ""
var _forced_until: int = -1
var _emit_timer: float = 0.0


func _ready() -> void:
	TimeManager.minute_passed.connect(func(_d, _h, _m): _update_schedule())
	TimeManager.time_set.connect(_on_time_set)
	TimeManager.day_changed.connect(_on_day_changed)
	Conditions.register("weather", func(v, _c):
		if v is Array:
			return state in v
		return state == str(v))
	Conditions.register("not_weather", func(v, _c): return state != str(v))
	Conditions.register("severe_weather", func(v, _c): return is_severe() == bool(v))
	Consequences.register("weather", func(v, _c):
		if v is Array:
			force_weather(str(v[0]), int(v[1]) if v.size() > 1 else 60, float(v[2]) if v.size() > 2 else 3.0)
		else:
			force_weather(str(v), 60))
	Consequences.register("clear_forced_weather", func(_v, _c): clear_forced())
	reset()


func reset() -> void:
	_forced_state = ""
	_forced_until = -1
	_snap_to(scheduled_state())


func _process(delta: float) -> void:
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta * maxf(TimeManager.time_speed, 0.5) / maxf(_blend_minutes, 0.01))
		_apply_blend()
	_emit_timer -= delta
	if _emit_timer <= 0.0:
		_emit_timer = 0.25
		RenderingServer.global_shader_parameter_set("snow_amount", clampf(GameState.world.get_snow_level() + intensity * 0.08, 0.0, 1.0))
		weather_updated.emit()


# --- Queries --------------------------------------------------------------------------------

func get_state() -> String:
	return state


func get_display_name() -> String:
	var p := Data.get_weather_preset(state)
	return p.display_name if p else state


func is_severe() -> bool:
	var p := Data.get_weather_preset(state)
	return p != null and p.severe


func is_blizzard() -> bool:
	return state == "BLIZZARD"


## 0..1: how much the storm hides things (used by fog, stealth and visuals).
func get_whiteout() -> float:
	return clampf(1.0 - (visibility - 12.0) / 60.0, 0.0, 1.0)


# --- Control --------------------------------------------------------------------------------

func set_weather(new_state: String, transition_minutes: float = 20.0) -> void:
	if not STATES.has(new_state):
		push_warning("WeatherManager: unknown state '%s'" % new_state)
		return
	var preset := Data.get_weather_preset(new_state)
	if preset == null:
		return
	_from = _current_values()
	_to = _preset_values(preset)
	_blend_minutes = maxf(transition_minutes, 0.01)
	_blend = 0.0
	if new_state != state:
		state = new_state
		weather_changed.emit(state)


## Event-driven weather (e.g. the first squall) for `minutes` game minutes.
func force_weather(new_state: String, minutes: int, transition_minutes: float = 3.0) -> void:
	_forced_state = new_state
	_forced_until = TimeManager.total_minutes + maxi(1, minutes)
	set_weather(new_state, transition_minutes)


func clear_forced() -> void:
	_forced_state = ""
	_forced_until = -1
	_update_schedule()


func is_forced() -> bool:
	return not _forced_state.is_empty()


func scheduled_state() -> String:
	var days: Dictionary = Data.get_world_table("days")
	if days.is_empty():
		return "LIGHT"
	var key := str(TimeManager.current_day)
	if not days.has(key):
		var keys := days.keys()
		keys.sort_custom(func(a, b): return int(a) < int(b))
		key = str(keys[-1])
	var schedule: Array = days[key].get("weather", [])
	var now := TimeManager.minute_of_day
	if now < TimeManager.DAY_START_HOUR * 60:
		now += TimeManager.MINUTES_PER_DAY
	var result := "LIGHT"
	var best := -1
	for entry in schedule:
		var h := int(entry.get("hour", 0))
		var m := h * 60 + int(entry.get("minute", 0))
		if h < TimeManager.DAY_START_HOUR:
			m += TimeManager.MINUTES_PER_DAY
		if m <= now and m > best:
			best = m
			result = str(entry.get("state", "LIGHT"))
	if best < 0 and not schedule.is_empty():
		result = str(schedule[0].get("state", "LIGHT"))
	return result


func _update_schedule() -> void:
	if is_forced() and TimeManager.total_minutes >= _forced_until:
		_forced_state = ""
		_forced_until = -1
	var desired := _forced_state if is_forced() else scheduled_state()
	if desired != state:
		set_weather(desired, 3.0 if is_forced() else 25.0)


func _on_time_set() -> void:
	if not TimeManager.is_skipping:
		_update_schedule()


func _on_day_changed(day: int) -> void:
	var days: Dictionary = Data.get_world_table("days")
	var entry: Dictionary = days.get(str(day), {})
	if entry.has("snow_level"):
		GameState.world.set_value("snow_level", maxf(GameState.world.get_snow_level(), float(entry.snow_level)))
	for route in entry.get("close_routes", []):
		GameState.world.set_route(str(route), false)
	for route in entry.get("open_routes", []):
		GameState.world.set_route(str(route), true)


# --- Blending -------------------------------------------------------------------------------

func _preset_values(p: WeatherPreset) -> Dictionary:
	var d := {}
	for f in FIELDS:
		d[f] = float(p.get(f))
	return d


func _current_values() -> Dictionary:
	var d := {}
	for f in FIELDS:
		d[f] = float(get(f))
	return d


func _apply_blend() -> void:
	var t := smoothstep(0.0, 1.0, _blend)
	for f in FIELDS:
		set(f, lerpf(float(_from.get(f, get(f))), float(_to.get(f, get(f))), t))


func _snap_to(new_state: String) -> void:
	var preset := Data.get_weather_preset(new_state)
	state = new_state
	if preset:
		_to = _preset_values(preset)
		_from = _to.duplicate()
		_blend = 1.0
		for f in FIELDS:
			set(f, _to[f])
	weather_changed.emit(state)


func serialize() -> Dictionary:
	return {"state": state, "forced_state": _forced_state, "forced_until": _forced_until, "values": _current_values()}


func deserialize(d: Dictionary) -> void:
	_forced_state = str(d.get("forced_state", ""))
	_forced_until = int(d.get("forced_until", -1))
	var s := str(d.get("state", "LIGHT"))
	_snap_to(s if STATES.has(s) else "LIGHT")
	_update_schedule()
