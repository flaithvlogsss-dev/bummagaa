extends Node
## QuestManager — quest progress driven by data (res://data/quests/*.json).
##
## Purpose: a quest is {"id", "title", "description", "category": "main"|"side",
##   "auto_start": conditions, "stages": [{"id", "description", "objectives": [
##   {"id", "text", "condition": conditions, "optional", "hidden"}], "on_complete"}],
##   "rewards", "consequences", "completion_flags"}.
##   Objectives complete by themselves when their condition becomes true (checked whenever
##   flags, items, information, locations, relationships or the shelter change) and stay
##   completed afterwards.
## Dependencies: Data, GameState, Conditions, Consequences.
## Public API: start_quest, complete_objective, complete_quest, fail_quest, is_active,
##   is_completed, get_status, get_active_quests, get_tracked, get_current_stage,
##   is_objective_done, evaluate
## Signals: quest_started, quest_updated, objective_completed, quest_completed, quest_failed
## Save Data: {"quests": {id: {status, stage, done}}, "tracked": id}

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal objective_completed(quest_id: String, objective_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

var tracked: String = ""
var _state: Dictionary = {}
var _dirty: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.story_flag_changed.connect(func(_f, _v): mark_dirty())
	GameState.information_discovered.connect(func(_i): mark_dirty())
	GameState.location_discovered.connect(func(_l): mark_dirty())
	GameState.location_changed.connect(func(_l): mark_dirty())
	GameState.shelter_upgraded.connect(func(_l): mark_dirty())
	GameState.decision_made.connect(func(_k, _v): mark_dirty())
	GameState.inventory.item_added.connect(func(_i, _n): mark_dirty())
	GameState.storage.item_added.connect(func(_i, _n): mark_dirty())
	GameState.relationships.relationship_changed.connect(func(_n, _s, _v): mark_dirty())
	GameState.npcs.npc_changed.connect(func(_n): mark_dirty())
	Conditions.register("quest_active", func(v, _c): return is_active(str(v)))
	Conditions.register("quest_completed", func(v, _c): return is_completed(str(v)))
	Conditions.register("quest_not_started", func(v, _c): return get_status(str(v)) == "")
	Conditions.register("quest_stage", func(v, _c): return is_active(str(v[0])) and int(_state[str(v[0])].stage) >= int(v[1]))
	Conditions.register("objective_done", func(v, _c): return is_objective_done(str(v[0]), str(v[1])))
	Consequences.register("start_quest", func(v, _c): start_quest(str(v)))
	Consequences.register("complete_quest", func(v, _c): complete_quest(str(v)))
	Consequences.register("fail_quest", func(v, _c): fail_quest(str(v)))
	Consequences.register("complete_objective", func(v, _c): complete_objective(str(v[0]), str(v[1])))
	Consequences.register("track_quest", func(v, _c): tracked = str(v))


func reset() -> void:
	_state.clear()
	tracked = ""


func mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		evaluate()


# --- Queries ----------------------------------------------------------------------------------

func get_status(quest_id: String) -> String:
	return str(_state.get(quest_id, {}).get("status", ""))


func is_active(quest_id: String) -> bool:
	return get_status(quest_id) == "active"


func is_completed(quest_id: String) -> bool:
	return get_status(quest_id) == "completed"


func is_objective_done(quest_id: String, objective_id: String) -> bool:
	return bool(_state.get(quest_id, {}).get("done", {}).get(objective_id, false))


func get_active_quests() -> Array[String]:
	var out: Array[String] = []
	for id in _state.keys():
		if is_active(id):
			out.append(id)
	out.sort_custom(func(a, b): return _sort_key(a) < _sort_key(b))
	return out


func get_finished_quests() -> Array[String]:
	var out: Array[String] = []
	for id in _state.keys():
		if not is_active(id):
			out.append(id)
	return out


func _sort_key(id: String) -> String:
	var q := Data.get_quest(id)
	return ("0" if q.get("category", "side") == "main" else "1") + id


func get_tracked() -> String:
	if is_active(tracked):
		return tracked
	var active := get_active_quests()
	tracked = active[0] if not active.is_empty() else ""
	return tracked


func get_current_stage(quest_id: String) -> Dictionary:
	var q := Data.get_quest(quest_id)
	var stages: Array = q.get("stages", [])
	var idx := int(_state.get(quest_id, {}).get("stage", 0))
	if idx < 0 or idx >= stages.size():
		return {}
	return stages[idx]


## Objectives of the current stage as [{id, text, done, optional}] (hidden ones only when done).
func get_objectives(quest_id: String) -> Array:
	var out: Array = []
	for o in get_current_stage(quest_id).get("objectives", []):
		var done := is_objective_done(quest_id, str(o.id))
		if o.get("hidden", false) and not done:
			continue
		out.append({"id": o.id, "text": GameState.format_text(str(o.get("text", ""))), "done": done, "optional": o.get("optional", false)})
	return out


# --- Control ----------------------------------------------------------------------------------

func start_quest(quest_id: String) -> void:
	var q := Data.get_quest(quest_id)
	if q.is_empty() or _state.has(quest_id):
		return
	_state[quest_id] = {"status": "active", "stage": 0, "done": {}}
	if q.get("category", "side") == "main" or tracked.is_empty() or not is_active(tracked):
		tracked = quest_id
	AudioManager.play_ui("quest")
	GameState.present("quest_banner", {"title": "НОВОЕ ЗАДАНИЕ", "text": str(q.get("title", quest_id))})
	quest_started.emit(quest_id)
	mark_dirty()


func complete_objective(quest_id: String, objective_id: String) -> void:
	if not is_active(quest_id):
		return
	_mark_done(quest_id, objective_id)
	mark_dirty()


func complete_quest(quest_id: String) -> void:
	var q := Data.get_quest(quest_id)
	if q.is_empty():
		return
	if not _state.has(quest_id):
		_state[quest_id] = {"status": "active", "stage": 0, "done": {}}
	if is_completed(quest_id):
		return
	_state[quest_id].status = "completed"
	for f in q.get("completion_flags", []):
		GameState.set_flag(str(f), true)
	Consequences.apply_all(q.get("rewards", []))
	Consequences.apply_all(q.get("consequences", []))
	AudioManager.play_ui("quest")
	GameState.present("quest_banner", {"title": "ЗАДАНИЕ ВЫПОЛНЕНО", "text": str(q.get("title", quest_id))})
	quest_completed.emit(quest_id)
	if tracked == quest_id:
		tracked = ""
	SaveManager.autosave("quest")
	mark_dirty()


func fail_quest(quest_id: String) -> void:
	if not is_active(quest_id):
		return
	_state[quest_id].status = "failed"
	var q := Data.get_quest(quest_id)
	GameState.present("quest_banner", {"title": "ЗАДАНИЕ ПРОВАЛЕНО", "text": str(q.get("title", quest_id))})
	quest_failed.emit(quest_id)


func _mark_done(quest_id: String, objective_id: String) -> bool:
	var done: Dictionary = _state[quest_id].done
	if done.get(objective_id, false):
		return false
	done[objective_id] = true
	objective_completed.emit(quest_id, objective_id)
	for o in get_current_stage(quest_id).get("objectives", []):
		if str(o.id) == objective_id:
			GameState.notify("✓ " + GameState.format_text(str(o.get("text", ""))), "quest")
	return true


## Re-checks every active quest; also auto-starts quests whose auto_start passes.
func evaluate() -> void:
	for id in Data.quests.keys():
		var q: Dictionary = Data.quests[id]
		if not _state.has(id) and q.has("auto_start") and Conditions.check_all(q.auto_start):
			start_quest(id)
	for id in _state.keys():
		if not is_active(id):
			continue
		var guard := 0
		while is_active(id) and guard < 10:
			guard += 1
			if not _evaluate_stage(id):
				break


## Returns true when the stage advanced (so the next stage is checked too).
func _evaluate_stage(quest_id: String) -> bool:
	var q := Data.get_quest(quest_id)
	var stages: Array = q.get("stages", [])
	var st: Dictionary = _state[quest_id]
	if int(st.stage) >= stages.size():
		complete_quest(quest_id)
		return false
	var stage: Dictionary = stages[int(st.stage)]
	var all_done := true
	for o in stage.get("objectives", []):
		var oid := str(o.id)
		if not is_objective_done(quest_id, oid) and o.has("condition") and Conditions.check_all(o.condition):
			_mark_done(quest_id, oid)
		if not o.get("optional", false) and not is_objective_done(quest_id, oid):
			all_done = false
	if not all_done:
		return false
	Consequences.apply_all(stage.get("on_complete", []))
	st.stage = int(st.stage) + 1
	if int(st.stage) >= stages.size():
		complete_quest(quest_id)
		return false
	AudioManager.play_ui("quest")
	GameState.present("quest_banner", {"title": "QUEST UPDATED", "text": str(q.get("title", quest_id))})
	quest_updated.emit(quest_id)
	return true


func serialize() -> Dictionary:
	return {"quests": _state.duplicate(true), "tracked": tracked}


func deserialize(d: Dictionary) -> void:
	reset()
	var saved: Dictionary = d.get("quests", {})
	for id in saved.keys():
		if not Data.quests.has(id):
			push_warning("QuestManager: save references unknown quest '%s' (skipped)" % id)
			continue
		var s: Dictionary = saved[id]
		_state[id] = {"status": str(s.get("status", "active")), "stage": int(s.get("stage", 0)), "done": (s.get("done", {}) as Dictionary).duplicate()}
	tracked = str(d.get("tracked", ""))
