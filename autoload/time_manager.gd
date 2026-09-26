extends Node
## TimeManager — the game clock.
##
## Purpose: day 07:00–24:00, night 00:00–07:00. The day counter advances at 07:00, so the
##   night belongs to the day before it ("Day 1, 02:15" is still the first night).
## Dependencies: none (registers condition/consequence keys).
## Public API: start_clock(), stop_clock(), set_time(), advance_minutes(), skip_to_hour(),
##   format_clock(), format_day(), get_phase(), is_night(), is_dark(), day_fraction()
## Signals: minute_passed, hour_passed, day_changed, morning_started, evening_started,
##   night_started, time_set
## Save Data: {"day", "minute", "total", "speed"}

signal minute_passed(day: int, hour: int, minute: int)
signal hour_passed(day: int, hour: int)
signal day_changed(day: int)
signal morning_started(day: int)
signal evening_started(day: int)
signal night_started(day: int)
signal time_set

const DAY_START_HOUR := 7
const EVENING_HOUR := 18
const MINUTES_PER_DAY := 1440
const START_DAY := 1
const START_MINUTE := 19 * 60 + 32

var current_day: int = START_DAY
## Minute of the day, 0..1439.
var minute_of_day: int = START_MINUTE
## Monotonic minutes since the start of the game (used for scheduling).
var total_minutes: int = 0
## Game minutes per real second (0.25: an hour takes four real minutes).
const DEFAULT_SPEED := 0.25
var time_speed: float = DEFAULT_SPEED
var running: bool = false
var is_skipping: bool = false

var current_hour: int:
	get:
		return minute_of_day / 60
var current_minute: int:
	get:
		return minute_of_day % 60

var _accum: float = 0.0


func _ready() -> void:
	Conditions.register("day", func(v, _c): return current_day == int(v))
	Conditions.register("day_min", func(v, _c): return current_day >= int(v))
	Conditions.register("day_max", func(v, _c): return current_day <= int(v))
	Conditions.register("hour_between", func(v, _c): return is_hour_between(int(v[0]), int(v[1])))
	Conditions.register("is_night", func(v, _c): return is_night() == bool(v))
	Conditions.register("is_dark", func(v, _c): return is_dark() == bool(v))
	Consequences.register("advance_time", func(v, _c): advance_minutes(int(v)))
	Consequences.register("start_time", func(v, _c):
		if bool(v):
			start_clock()
		else:
			stop_clock())


func _process(delta: float) -> void:
	if not running:
		return
	_accum += delta * time_speed
	var guard := 0
	while _accum >= 1.0 and guard < 120:
		_accum -= 1.0
		_tick_minute()
		guard += 1


func reset() -> void:
	current_day = START_DAY
	minute_of_day = START_MINUTE
	total_minutes = 0
	time_speed = DEFAULT_SPEED
	running = false
	_accum = 0.0
	time_set.emit()


func start_clock() -> void:
	running = true


func stop_clock() -> void:
	running = false


func set_time(day: int, hour: int, minute: int = 0) -> void:
	current_day = maxi(1, day)
	minute_of_day = clampi(hour, 0, 23) * 60 + clampi(minute, 0, 59)
	time_set.emit()


func advance_minutes(minutes: int, skipping: bool = true) -> void:
	is_skipping = skipping
	for i in maxi(0, minutes):
		_tick_minute()
	is_skipping = false
	time_set.emit()


## Advances to the next occurrence of hour:00 (used by sleeping).
func skip_to_hour(hour: int) -> int:
	var target := hour * 60
	var delta := target - minute_of_day
	if delta <= 0:
		delta += MINUTES_PER_DAY
	advance_minutes(delta)
	return delta


func _tick_minute() -> void:
	minute_of_day += 1
	total_minutes += 1
	if minute_of_day >= MINUTES_PER_DAY:
		minute_of_day = 0
	if not is_skipping:
		minute_passed.emit(current_day, current_hour, current_minute)
	if current_minute != 0:
		return
	var hour := current_hour
	if hour == DAY_START_HOUR:
		current_day += 1
		day_changed.emit(current_day)
		morning_started.emit(current_day)
	elif hour == 0:
		night_started.emit(current_day)
	elif hour == EVENING_HOUR:
		evening_started.emit(current_day)
	hour_passed.emit(current_day, hour)


# --- Queries -------------------------------------------------------------------

func is_hour_between(from_hour: int, to_hour: int) -> bool:
	var h := current_hour
	if from_hour <= to_hour:
		return h >= from_hour and h < to_hour
	return h >= from_hour or h < to_hour


## Night proper (00:00–07:00).
func is_night() -> bool:
	return current_hour < DAY_START_HOUR


## Visually dark outside (20:00–06:00).
func is_dark() -> bool:
	return current_hour >= 20 or current_hour < 6


## 0..1 through the 24 h cycle, 0 = midnight.
func day_fraction() -> float:
	return (float(minute_of_day) + _accum) / float(MINUTES_PER_DAY)


func get_phase() -> String:
	var h := current_hour
	if h < DAY_START_HOUR:
		return "night"
	if h < 12:
		return "morning"
	if h < 17:
		return "day"
	if h < 21:
		return "evening"
	return "late"


func format_clock() -> String:
	return "%02d:%02d" % [current_hour, current_minute]


func format_day() -> String:
	return "DAY %d — %s" % [current_day, format_clock()]


func serialize() -> Dictionary:
	return {"day": current_day, "minute": minute_of_day, "total": total_minutes, "speed": time_speed}


func deserialize(d: Dictionary) -> void:
	current_day = maxi(1, int(d.get("day", START_DAY)))
	minute_of_day = clampi(int(d.get("minute", START_MINUTE)), 0, MINUTES_PER_DAY - 1)
	total_minutes = maxi(0, int(d.get("total", 0)))
	time_speed = float(d.get("speed", DEFAULT_SPEED))
	_accum = 0.0
	time_set.emit()
