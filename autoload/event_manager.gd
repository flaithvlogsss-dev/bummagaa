extends Node
## EventManager — scripted, scheduled and random world events (res://data/events/*.json).
##
## Purpose: picks events by time, weather, day, flags and shelter state. Event record:
##   {"id", "trigger": "hourly"|"night"|"morning"|"time"|"scheduled"|"enter",
##    "conditions", "chance", "weight", "once", "cooldown_hours", "location", "wait_for_location",
##    "at": {"day", "hour", "minute"}, "consequences", "notify", "dialogue", "npc", "priority"}
##   Delayed consequences use {"schedule_event": [id, minutes]} from any data file.
## Dependencies: TimeManager, GameState, Conditions, Consequences, DialogueManager.
## Public API: trigger(id, force), schedule(id, minutes), cancel(id), pick_night_event(),
##   on_location_entered(level_id), has_fired(id)
## Signals: event_fired(id)
## Save Data: fired counts, last fire time, scheduled + pending queues.

signal event_fired(event_id: String)

var _fired: Dictionary = {}
var _last_fired: Dictionary = {}
var _scheduled: Array = []
var _pending: Array = []


func _ready() -> void:
	TimeManager.minute_passed.connect(_on_minute)
	TimeManager.hour_passed.connect(_on_hour)
	TimeManager.morning_started.connect(_on_morning)
	TimeManager.time_set.connect(_check_timed)
	Consequences.register("schedule_event", func(v, _c):
		if v is Array:
			schedule(str(v[0]), int(v[1]) if v.size() > 1 else 0)
		else:
			schedule(str(v), 0))
	Consequences.register("trigger_event", func(v, _c): trigger(str(v)))
	Consequences.register("cancel_event", func(v, _c): cancel(str(v)))
	Conditions.register("event_fired", func(v, _c): return has_fired(str(v)))


func reset() -> void:
	_fired.clear()
	_last_fired.clear()
	_scheduled.clear()
	_pending.clear()


func has_fired(event_id: String) -> bool:
	return int(_fired.get(event_id, 0)) > 0


func schedule(event_id: String, delay_minutes: int) -> void:
	if Data.get_event(event_id).is_empty():
		return
	cancel(event_id)
	_scheduled.append({"id": event_id, "at": TimeManager.total_minutes + maxi(0, delay_minutes)})
	if delay_minutes <= 0:
		_check_timed()


func cancel(event_id: String) -> void:
	_scheduled = _scheduled.filter(func(s): return s.id != event_id)
	_pending.erase(event_id)


func is_scheduled(event_id: String) -> bool:
	for s in _scheduled:
		if s.id == event_id:
			return true
	return _pending.has(event_id)


func can_fire(e: Dictionary) -> bool:
	var id := str(e.get("id", ""))
	if e.get("once", false) and has_fired(id):
		return false
	var cooldown := float(e.get("cooldown_hours", 0.0)) * 60.0
	if cooldown > 0.0 and _last_fired.has(id) and TimeManager.total_minutes - int(_last_fired[id]) < cooldown:
		return false
	return Conditions.check_all(e.get("conditions", []), {"event": id})


func _location_ok(e: Dictionary) -> bool:
	var loc := str(e.get("location", "any"))
	match loc:
		"any", "":
			return true
		"outdoors":
			return GameState.current_location != "shelter"
	return GameState.current_location == loc


## Fires an event if its rules allow it (force skips once/cooldown/conditions).
func trigger(event_id: String, force: bool = false) -> bool:
	var e := Data.get_event(event_id)
	if e.is_empty():
		return false
	if not force and not can_fire(e):
		return false
	if not _location_ok(e):
		if e.get("wait_for_location", false) and not _pending.has(event_id):
			_pending.append(event_id)
		return false
	_fire(e)
	return true


func _fire(e: Dictionary) -> void:
	var id := str(e.id)
	_fired[id] = int(_fired.get(id, 0)) + 1
	_last_fired[id] = TimeManager.total_minutes
	var ctx := {"event": id}
	if e.has("npc"):
		ctx["npc"] = str(e.npc)
	Consequences.apply_all(e.get("consequences", []), ctx)
	if e.has("notify"):
		GameState.notify(GameState.format_text(str(e.notify)), "event")
	if e.has("dialogue"):
		DialogueManager.start(str(e.dialogue), ctx)
	event_fired.emit(id)


## Called by Main after a level change.
func on_location_entered(level_id: String) -> void:
	for id in _pending.duplicate():
		var e := Data.get_event(id)
		if _location_ok(e):
			_pending.erase(id)
			if Conditions.check_all(e.get("conditions", []), {"event": id}):
				_fire(e)
	for id in Data.events.keys():
		var e: Dictionary = Data.events[id]
		if str(e.get("trigger", "")) == "enter" and str(e.get("location", "")) == level_id and can_fire(e):
			_fire(e)


## Chooses one "night" event while the player sleeps (fired after waking up).
func pick_night_event() -> String:
	return _pick_weighted("night")


func _pick_weighted(trigger_kind: String) -> String:
	var candidates: Array = []
	var total := 0.0
	for id in Data.events.keys():
		var e: Dictionary = Data.events[id]
		if str(e.get("trigger", "")) != trigger_kind or not can_fire(e) or not _location_ok(e):
			continue
		if randf() > float(e.get("chance", 1.0)):
			continue
		var w := float(e.get("weight", 1.0))
		candidates.append([id, w])
		total += w
	if candidates.is_empty():
		return ""
	var roll := randf() * total
	for c in candidates:
		roll -= c[1]
		if roll <= 0.0:
			return c[0]
	return candidates[-1][0]


func _on_minute(_day: int, _hour: int, _minute: int) -> void:
	_check_timed()


func _check_timed() -> void:
	var now := TimeManager.total_minutes
	var due: Array = []
	for s in _scheduled:
		if now >= int(s.at):
			due.append(s)
	for s in due:
		_scheduled.erase(s)
		trigger(str(s.id))
	for id in Data.events.keys():
		var e: Dictionary = Data.events[id]
		if str(e.get("trigger", "")) != "time" or has_fired(id):
			continue
		var at: Dictionary = e.get("at", {})
		var day := int(at.get("day", 1))
		var target := _day_relative(int(at.get("hour", 0)) * 60 + int(at.get("minute", 0)))
		var reached := TimeManager.current_day > day or (TimeManager.current_day == day and _day_relative(TimeManager.minute_of_day) >= target)
		if reached:
			trigger(id)


## Night hours (00:00–07:00) belong to the previous day, so they sort after 23:59.
static func _day_relative(minute_of_day: int) -> int:
	return minute_of_day + (TimeManager.MINUTES_PER_DAY if minute_of_day < TimeManager.DAY_START_HOUR * 60 else 0)


func _on_hour(_day: int, _hour: int) -> void:
	if TimeManager.is_skipping:
		return
	var id := _pick_weighted("hourly")
	if not id.is_empty():
		trigger(id)


func _on_morning(_day: int) -> void:
	var list: Array = []
	for id in Data.events.keys():
		var e: Dictionary = Data.events[id]
		if str(e.get("trigger", "")) == "morning":
			list.append(e)
	list.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	for e in list:
		trigger(str(e.id))


func serialize() -> Dictionary:
	return {"fired": _fired.duplicate(), "last": _last_fired.duplicate(), "scheduled": _scheduled.duplicate(true), "pending": _pending.duplicate()}


func deserialize(d: Dictionary) -> void:
	reset()
	_fired = d.get("fired", {}).duplicate()
	_last_fired = d.get("last", {}).duplicate()
	for s in d.get("scheduled", []):
		if s is Dictionary and Data.events.has(str(s.get("id", ""))):
			_scheduled.append({"id": str(s.id), "at": int(s.get("at", 0))})
	for id in d.get("pending", []):
		if Data.events.has(str(id)):
			_pending.append(str(id))
