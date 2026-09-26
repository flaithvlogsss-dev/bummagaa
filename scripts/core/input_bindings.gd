class_name InputBindings
extends RefCounted
## InputBindings — default controls, registered at runtime so they can be remapped.
##
## Purpose: keeps every binding in one table. Settings saves user overrides as the same
##   "key:W" / "mouse:1" strings. Keys use physical keycodes, so WASD also works on
##   non-QWERTY layouts (e.g. Russian).
## Public API: apply(overrides), rebind(action, spec), serialize_overrides(), describe(action)

const DEFAULTS := {
	"move_forward": ["key:W", "key:Up"],
	"move_back": ["key:S", "key:Down"],
	"move_left": ["key:A", "key:Left"],
	"move_right": ["key:D", "key:Right"],
	"sprint": ["key:Shift"],
	"sneak": ["key:Ctrl"],
	"interact": ["key:E"],
	"inventory": ["key:I", "key:Tab"],
	"map": ["key:M"],
	"journal": ["key:Q"],
	"flashlight": ["key:F"],
	"reload": ["key:R"],
	"menu": ["key:Escape"],
	"debug": ["key:F1"],
	"fire": ["mouse:1"],
	"aim": ["mouse:2"],
	"heal_quick": ["key:H"],
}

static var overrides: Dictionary = {}


static func apply(p_overrides: Dictionary = {}) -> void:
	overrides = p_overrides.duplicate()
	for action in DEFAULTS.keys():
		var specs: Array = overrides.get(action, DEFAULTS[action])
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		for spec in specs:
			var ev := _event_from_spec(str(spec))
			if ev:
				InputMap.action_add_event(action, ev)


static func rebind(action: String, spec: String) -> void:
	if not DEFAULTS.has(action):
		return
	overrides[action] = [spec]
	apply(overrides)


static func describe(action: String) -> String:
	var specs: Array = overrides.get(action, DEFAULTS.get(action, []))
	if specs.is_empty():
		return "?"
	var s := str(specs[0])
	if s.begins_with("mouse:"):
		return {"1": "ЛКМ", "2": "ПКМ", "3": "СКМ"}.get(s.substr(6), s)
	return s.substr(4)


static func _event_from_spec(spec: String) -> InputEvent:
	if spec.begins_with("key:"):
		var code := OS.find_keycode_from_string(spec.substr(4))
		if code == KEY_NONE:
			push_warning("InputBindings: unknown key '%s'" % spec)
			return null
		var k := InputEventKey.new()
		k.physical_keycode = code
		return k
	if spec.begins_with("mouse:"):
		var m := InputEventMouseButton.new()
		m.button_index = int(spec.substr(6)) as MouseButton
		return m
	return null
