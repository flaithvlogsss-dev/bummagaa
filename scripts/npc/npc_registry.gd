class_name NPCRegistry
extends RefCounted
## NPCRegistry — runtime state of every character (alive, location, memory...).
##
## Purpose: levels spawn NPC nodes from this data; dialogues read NPC memory flags
##   like player_saved_me / player_refused_help.
## Dependencies: Data (CharacterData).
## Public API: reset_from_data, has_npc, get_state, is_alive, get_location, set_location,
##   kill, set_memory, get_memory, modify_stat, list_at, alive_ids, dead_ids, in_shelter
## Signals: npc_died(npc_id, cause), npc_moved(npc_id, location), npc_changed(npc_id)
## Save Data: {npc_id: state_dict}

signal npc_died(npc_id: String, cause: String)
signal npc_moved(npc_id: String, location: String)
signal npc_changed(npc_id: String)

const SHELTER := "shelter"

var _states: Dictionary = {}


func reset_from_data(characters: Dictionary) -> void:
	_states.clear()
	for id in characters.keys():
		var c: CharacterData = characters[id]
		if c == null or not c.is_npc:
			continue
		_states[id] = _default_state(c)


func _default_state(c: CharacterData) -> Dictionary:
	return {
		"health": c.max_health,
		"stress": 30.0,
		"hope": 50.0,
		"alive": true,
		"location": c.start_location,
		"spawn": c.start_spawn,
		"injured": c.start_injured,
		"met": false,
		"memory": {},
		"death": {},
	}


func has_npc(npc_id: String) -> bool:
	return _states.has(npc_id)


func get_state(npc_id: String) -> Dictionary:
	return _states.get(npc_id, {})


func is_alive(npc_id: String) -> bool:
	return bool(get_state(npc_id).get("alive", false))


func get_location(npc_id: String) -> String:
	return str(get_state(npc_id).get("location", ""))


func get_spawn(npc_id: String) -> String:
	return str(get_state(npc_id).get("spawn", ""))


func set_location(npc_id: String, location: String, spawn: String = "") -> void:
	if not _states.has(npc_id):
		push_warning("NPCRegistry: unknown npc '%s'" % npc_id)
		return
	_states[npc_id]["location"] = location
	_states[npc_id]["spawn"] = spawn
	npc_moved.emit(npc_id, location)
	npc_changed.emit(npc_id)


func set_value(npc_id: String, key: String, value: Variant) -> void:
	if not _states.has(npc_id):
		push_warning("NPCRegistry: unknown npc '%s'" % npc_id)
		return
	_states[npc_id][key] = value
	npc_changed.emit(npc_id)


func kill(npc_id: String, cause: String = "", position: Vector3 = Vector3.INF) -> void:
	if not is_alive(npc_id):
		return
	var st: Dictionary = _states[npc_id]
	st["alive"] = false
	st["health"] = 0.0
	st["death"] = {
		"cause": cause,
		"location": st.get("location", ""),
		"spawn": st.get("spawn", ""),
		"position": [position.x, position.y, position.z] if position != Vector3.INF else [],
		"looted": false,
	}
	npc_died.emit(npc_id, cause)
	npc_changed.emit(npc_id)


func set_memory(npc_id: String, key: String, value: Variant) -> void:
	if not _states.has(npc_id):
		push_warning("NPCRegistry: unknown npc '%s'" % npc_id)
		return
	_states[npc_id]["memory"][key] = value
	npc_changed.emit(npc_id)


func get_memory(npc_id: String, key: String, default: Variant = false) -> Variant:
	var mem: Dictionary = get_state(npc_id).get("memory", {})
	return mem.get(key, default)


func modify_stat(npc_id: String, stat: String, delta: float) -> void:
	if not _states.has(npc_id):
		return
	var st: Dictionary = _states[npc_id]
	st[stat] = clampf(float(st.get(stat, 0.0)) + delta, 0.0, 100.0)
	npc_changed.emit(npc_id)
	if stat == "health" and st[stat] <= 0.0:
		kill(npc_id, "wounds")


func list_at(location: String, include_dead: bool = false) -> Array[String]:
	var out: Array[String] = []
	for id in _states.keys():
		var st: Dictionary = _states[id]
		var alive: bool = st.get("alive", false)
		if alive and st.get("location", "") == location:
			out.append(id)
		elif include_dead and not alive and st.get("death", {}).get("location", "") == location:
			out.append(id)
	return out


func alive_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _states.keys():
		if is_alive(id):
			out.append(id)
	return out


func dead_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _states.keys():
		if not is_alive(id):
			out.append(id)
	return out


func in_shelter() -> Array[String]:
	return list_at(SHELTER)


func all_ids() -> Array:
	return _states.keys()


func serialize() -> Dictionary:
	return _states.duplicate(true)


## Merges saved states over fresh defaults, so NPCs added after the save still exist.
func deserialize(d: Dictionary) -> void:
	for id in d.keys():
		if not _states.has(id):
			push_warning("NPCRegistry: save references unknown npc '%s' (skipped)" % id)
			continue
		var saved: Dictionary = d[id] if d[id] is Dictionary else {}
		for key in saved.keys():
			_states[id][key] = saved[key]
		if not (_states[id].get("memory") is Dictionary):
			_states[id]["memory"] = {}
