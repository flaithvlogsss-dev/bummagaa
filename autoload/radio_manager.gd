extends Node
## RadioManager — frequencies, signals and broadcasts (res://data/radio/*.json).
##
## Purpose: a signal is {"id", "frequency", "title", "text", "stations": [...],
##   "conditions", "info", "consequences", "voice_pitch"}. The tuning mini-game asks probe()
##   how clear the current frequency is; holding a clear signal locks it: the message is saved
##   as Information, and its consequences can reveal coordinates or start story events.
## Stations: "shelter_basic" (plays one preset broadcast), "radio_point" and
##   "shelter_station" (full scanners; the latter needs shelter level 3).
## Dependencies: Data, GameState, Conditions, Consequences.
## Public API: probe(freq, station), lock(signal_id), is_found(id), available_signals(station),
##   found_signals()
## Signals: radio_signal_found(signal_id)
## Save Data: {"found": [ids]}

signal radio_signal_found(signal_id: String)

const FREQ_MIN := 87.5
const FREQ_MAX := 108.0
## MHz within which a signal is audible at all.
const TOLERANCE := 0.8
const LOCK_CLARITY := 0.9

var _found: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Conditions.register("radio_found", func(v, _c): return is_found(str(v)))
	Conditions.register("radio_count_min", func(v, _c): return _found.size() >= int(v))
	Consequences.register("radio_lock", func(v, _c): lock(str(v)))


func reset() -> void:
	_found.clear()


func is_found(signal_id: String) -> bool:
	return _found.has(signal_id)


func found_signals() -> Array[String]:
	return _found.duplicate()


func available_signals(station: String) -> Array:
	var out: Array = []
	for id in Data.radio_signals.keys():
		var s: Dictionary = Data.radio_signals[id]
		if station in s.get("stations", []) and Conditions.check_all(s.get("conditions", [])):
			out.append(s)
	return out


## Returns {"id", "clarity" 0..1, "signal"} for the strongest signal near `freq`.
func probe(freq: float, station: String) -> Dictionary:
	var best := {"id": "", "clarity": 0.0, "signal": {}}
	for s in available_signals(station):
		var d := absf(freq - float(s.get("frequency", 0.0)))
		var clarity := clampf(1.0 - d / TOLERANCE, 0.0, 1.0)
		clarity = clarity * clarity * (3.0 - 2.0 * clarity)
		if clarity > best.clarity:
			best = {"id": str(s.id), "clarity": clarity, "signal": s}
	return best


## Records a signal as heard. Returns true the first time.
func lock(signal_id: String) -> bool:
	var s := Data.get_radio_signal(signal_id)
	if s.is_empty() or is_found(signal_id):
		return false
	_found.append(signal_id)
	if s.has("info"):
		GameState.add_information(str(s.info))
	Consequences.apply_all(s.get("consequences", []), {"radio": signal_id})
	AudioManager.play_ui("tune_lock")
	radio_signal_found.emit(signal_id)
	return true


func serialize() -> Dictionary:
	return {"found": _found.duplicate()}


func deserialize(d: Dictionary) -> void:
	reset()
	for id in d.get("found", []):
		if Data.radio_signals.has(str(id)):
			_found.append(str(id))
