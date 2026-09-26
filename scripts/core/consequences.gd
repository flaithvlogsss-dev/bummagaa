class_name Consequences
extends RefCounted
## Consequences — the shared, data-driven "effect language".
##
## Purpose: choices, quest rewards, events, radio signals, items and interactables describe
##   what happens as dictionaries, e.g. {"set_flag": ["helped_mara", true]},
##   {"relationship": {"npc": "mara", "trust": 15}}, {"schedule_event": ["mara_fate", 60]}.
##   Immediate, delayed (schedule_event) and long-term (flags read by endings) consequences
##   are all expressed this way — there are no good/evil points.
## Dependencies: none. Systems register their own keys in _ready.
## Public API: register(key, handler), apply_all(list, ctx), apply(dict, ctx), describe_keys()
## Signals: none. Save Data: none.
##
## Handler signature: func(value: Variant, ctx: Dictionary) -> void

static var _handlers: Dictionary = {}
static var _warned: Dictionary = {}


static func register(key: String, handler: Callable) -> void:
	_handlers[key] = handler


static func has_handler(key: String) -> bool:
	return _handlers.has(key)


static func describe_keys() -> PackedStringArray:
	var keys := PackedStringArray(_handlers.keys())
	keys.sort()
	return keys


static func clear_handlers() -> void:
	_handlers.clear()


static func apply_all(list: Variant, ctx: Dictionary = {}) -> void:
	if list == null:
		return
	if list is Dictionary:
		apply(list, ctx)
		return
	if list is Array:
		for entry in list:
			if entry is Dictionary:
				apply(entry, ctx)


static func apply(entry: Dictionary, ctx: Dictionary = {}) -> void:
	# Optional guard: {"if": {...conditions...}, "give_item": [...]}
	if entry.has("if") and not Conditions.check_all(entry["if"], ctx):
		return
	for key in entry.keys():
		if key == "if":
			continue
		var handler: Callable = _handlers.get(key, Callable())
		if not handler.is_valid():
			if not _warned.has(key):
				_warned[key] = true
				push_warning("Consequences: unknown key '%s' ignored" % key)
			continue
		handler.call(entry[key], ctx)
