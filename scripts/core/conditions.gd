class_name Conditions
extends RefCounted
## Conditions — the shared, data-driven "requirement language".
##
## Purpose: dialogues, quests, events, radio signals, interactables and endings all describe
##   requirements as dictionaries, e.g. {"flag": "radio_found"} or {"item": ["cloth", 2]}.
##   Every key inside one dictionary must pass (AND); a list of dictionaries is also AND.
##   Use {"any": [...]} for OR and {"not": {...}} for negation.
## Dependencies: none. Systems register their own keys in _ready (see GameState, QuestManager...).
## Public API: register(key, handler), check_all(conds, ctx), check(cond, ctx), describe_keys()
## Signals: none. Save Data: none.
##
## Handler signature: func(value: Variant, ctx: Dictionary) -> bool
## ctx carries optional context such as {"npc": "mara"} so data can say "self".

static var _handlers: Dictionary = {}
static var _warned: Dictionary = {}


static func register(key: String, handler: Callable) -> void:
	_handlers[key] = handler


static func has_handler(key: String) -> bool:
	_ensure_builtins()
	return _handlers.has(key)


static func describe_keys() -> PackedStringArray:
	_ensure_builtins()
	var keys := PackedStringArray(_handlers.keys())
	keys.sort()
	return keys


## Accepts null, a Dictionary or an Array of Dictionaries.
static func check_all(conds: Variant, ctx: Dictionary = {}) -> bool:
	if conds == null:
		return true
	if conds is Dictionary:
		return check(conds, ctx)
	if conds is Array:
		for c in conds:
			if c is Dictionary and not check(c, ctx):
				return false
		return true
	return true


static func check(cond: Dictionary, ctx: Dictionary = {}) -> bool:
	_ensure_builtins()
	for key in cond.keys():
		var handler: Callable = _handlers.get(key, Callable())
		if not handler.is_valid():
			if not _warned.has(key):
				_warned[key] = true
				push_warning("Conditions: unknown key '%s' (treated as false)" % key)
			return false
		if not handler.call(cond[key], ctx):
			return false
	return true


## Type-tolerant equality (JSON numbers are floats, flags may be bool/int/string).
static func values_equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if ta in numeric and tb in numeric:
		return is_equal_approx(float(a), float(b))
	if ta == TYPE_BOOL and tb in numeric:
		return a == (float(b) != 0.0)
	if tb == TYPE_BOOL and ta in numeric:
		return b == (float(a) != 0.0)
	if ta != tb:
		if (ta == TYPE_STRING or ta == TYPE_STRING_NAME) and (tb == TYPE_STRING or tb == TYPE_STRING_NAME):
			return str(a) == str(b)
		return false
	return a == b


static func truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return not str(v).is_empty()
	return true


## Drops every registered handler (called on shutdown so no callable outlives its owner).
static func clear_handlers() -> void:
	_handlers.clear()


## Resolves "self" to the npc in context.
static func resolve_npc(value: Variant, ctx: Dictionary) -> String:
	var id := str(value)
	if id == "self":
		return str(ctx.get("npc", ""))
	return id


static func _ensure_builtins() -> void:
	if _handlers.has("any"):
		return
	_handlers["any"] = func(v, ctx):
		if v is Array:
			for c in v:
				if check_all(c, ctx):
					return true
		return false
	_handlers["all"] = func(v, ctx): return check_all(v, ctx)
	_handlers["not"] = func(v, ctx): return not check_all(v, ctx)
	_handlers["chance"] = func(v, _ctx): return randf() < float(v)
	_handlers["always"] = func(v, _ctx): return bool(v)
