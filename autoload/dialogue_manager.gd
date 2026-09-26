extends Node
## DialogueManager — runs data-driven dialogue graphs (res://data/dialogues/*.json).
##
## Purpose: dialogue text lives in data, not code. A dialogue is
##   {"id", "start", "nodes": {node_id: node}} where a node is one of:
##     text node   {"speaker", "text", "consequences", "choices": [...] | "next"}
##     branch node {"branch": [{"if": conditions, "next": id}, ..., {"next": default}]}
##     action node {"consequences": [...], "next": id}
##   A choice is {"text", "if" (hidden when false), "requires" (shown disabled when false),
##   "requires_text", "consequences", "next", "once"}.
## Dependencies: Data, Conditions, Consequences, GameState.
## Public API: start(id, ctx), start_data(dict, ctx), show_text(title, text), advance(),
##   choose(index), is_active()
## Signals: dialogue_started(id), line_shown(line), dialogue_ended(id)
## Save Data: none (seen dialogues / once-choices are stored as GameState flags).

signal dialogue_started(dialogue_id: String)
signal line_shown(line: Dictionary)
signal dialogue_ended(dialogue_id: String)

const MAX_STEPS := 64

var active: bool = false
var current_id: String = ""

var _dialogue: Dictionary = {}
var _ctx: Dictionary = {}
var _node: Dictionary = {}
var _node_id: String = ""
var _choices: Array = []
var _queue: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Consequences.register("start_dialogue", func(v, ctx): start(str(v), ctx if ctx is Dictionary else {}))
	Consequences.register("show_text", func(v, _c): show_text(str(v[0]), str(v[1])))
	Conditions.register("dialogue_seen", func(v, _c): return GameState.has_flag("seen:" + str(v)))


func is_active() -> bool:
	return active


func start(dialogue_id: String, ctx: Dictionary = {}) -> bool:
	var data := Data.get_dialogue(dialogue_id)
	if data.is_empty():
		return false
	return start_data(data, ctx)


func start_data(data: Dictionary, ctx: Dictionary = {}) -> bool:
	if active:
		_queue.append([data, ctx])
		return true
	var clean_ctx := {}
	for k in ctx.keys():
		if k != "source":
			clean_ctx[k] = ctx[k]
	active = true
	_dialogue = data
	_ctx = clean_ctx
	current_id = str(data.get("id", "__text"))
	if not current_id.begins_with("__"):
		GameState.set_flag("seen:" + current_id, true)
	if _ctx.has("npc"):
		GameState.npcs.set_value(_ctx.npc, "met", true)
	dialogue_started.emit(current_id)
	_goto(str(data.get("start", "start")))
	return true


## Single page of text (notes, examine descriptions).
func show_text(title: String, text: String) -> void:
	start_data({
		"id": "__text",
		"start": "page",
		"nodes": {"page": {"speaker_name": title, "text": text}},
	})


func advance() -> void:
	if not active or not _choices.is_empty():
		return
	_goto(str(_node.get("next", "end")))


func choose(index: int) -> void:
	if not active or index < 0 or index >= _choices.size():
		return
	var entry: Dictionary = _choices[index]
	if not entry.enabled:
		AudioManager.play_ui("deny")
		return
	var choice: Dictionary = entry.data
	if choice.get("once", false):
		GameState.set_flag(entry.once_key, true)
	Consequences.apply_all(choice.get("consequences", []), _ctx)
	_goto(str(choice.get("next", "end")))


func _goto(node_id: String) -> void:
	var nodes: Dictionary = _dialogue.get("nodes", {})
	for step in MAX_STEPS:
		if node_id.is_empty() or node_id == "end":
			_end()
			return
		if not nodes.has(node_id):
			push_warning("Dialogue %s: missing node '%s'" % [current_id, node_id])
			_end()
			return
		var node: Dictionary = nodes[node_id]
		_node_id = node_id
		Consequences.apply_all(node.get("consequences", []), _ctx)
		if node.has("branch"):
			node_id = "end"
			for b in node.branch:
				if Conditions.check_all(b.get("if", []), _ctx):
					node_id = str(b.get("next", "end"))
					break
			continue
		if not node.has("text"):
			node_id = str(node.get("next", "end"))
			continue
		_show(node)
		return
	push_warning("Dialogue %s: too many steps (loop?)" % current_id)
	_end()


func _show(node: Dictionary) -> void:
	_node = node
	_choices.clear()
	var ui_choices: Array = []
	var list: Array = node.get("choices", [])
	for i in list.size():
		var c: Dictionary = list[i]
		var once_key := "once:%s:%s:%d" % [current_id, _node_id, i]
		if c.get("once", false) and GameState.has_flag(once_key):
			continue
		if c.has("if") and not Conditions.check_all(c["if"], _ctx):
			continue
		var enabled := not c.has("requires") or Conditions.check_all(c["requires"], _ctx)
		var text := _format(str(c.get("text", "...")))
		if not enabled and c.has("requires_text"):
			text += "  (%s)" % c.requires_text
		_choices.append({"data": c, "enabled": enabled, "once_key": once_key})
		ui_choices.append({"text": text, "enabled": enabled})
	var speaker_id := str(node.get("speaker", ""))
	if speaker_id == "self" and _ctx.has("npc"):
		speaker_id = str(_ctx.npc)
	line_shown.emit({
		"speaker_id": speaker_id,
		"speaker_name": str(node.get("speaker_name", _speaker_name(speaker_id))),
		"text": _format(str(node.get("text", ""))),
		"choices": ui_choices,
		"portrait": speaker_id if Data.characters.has(speaker_id) else "",
	})


func _end() -> void:
	var ended := current_id
	active = false
	_node = {}
	_choices.clear()
	current_id = ""
	dialogue_ended.emit(ended)
	if not _queue.is_empty():
		var next: Array = _queue.pop_front()
		start_data.call_deferred(next[0], next[1])


func _speaker_name(speaker_id: String) -> String:
	match speaker_id:
		"", "narrator":
			return ""
		"player":
			return GameState.player_name
		"radio":
			return "Радио"
	if speaker_id == "self" and _ctx.has("npc"):
		speaker_id = _ctx.npc
	return Data.get_character_name(speaker_id)


func _format(text: String) -> String:
	text = GameState.format_text(text)
	if _ctx.has("npc"):
		text = text.replace("{npc}", Data.get_character_name(_ctx.npc))
	return text
