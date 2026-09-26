class_name EndingDirector
extends RefCounted
## EndingDirector — picks and describes prototype endings (data/world/endings.json).
##
## Purpose: endings are states, not good/bad. HOME / SIGNAL / DEPARTURE (+ a quiet fallback).
##   SIGNAL and DEPARTURE are reached through actions (transmitter, north road) whose
##   dialogues check hidden conditions. On the final morning, evaluate() picks the first
##   "final_morning" ending whose conditions pass, else the fallback.
##   The player never sees the conditions; the epilogue reflects their decisions.
## Public API: get_ending(id), evaluate(), epilogue_lines()


static func _table() -> Dictionary:
	var t = Data.get_world_table("endings")
	return t if t is Dictionary else {}


static func get_ending(ending_id: String) -> Dictionary:
	for e in _table().get("endings", []):
		if str(e.get("id", "")) == ending_id:
			return e
	return {"id": ending_id, "title": ending_id.to_upper(), "text": ""}


static func evaluate() -> String:
	var fallback := "long_winter"
	for e in _table().get("endings", []):
		if str(e.get("trigger", "")) == "fallback":
			fallback = str(e.id)
		elif str(e.get("trigger", "")) == "final_morning" and Conditions.check_all(e.get("conditions", [])):
			return str(e.id)
	return fallback


static func epilogue_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for line in _table().get("epilogue", []):
		if Conditions.check_all(line.get("if", [])):
			out.append("• " + GameState.format_text(str(line.get("text", ""))))
	return out
