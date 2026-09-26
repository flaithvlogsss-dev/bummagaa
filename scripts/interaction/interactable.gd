class_name Interactable
extends Area3D
## Interactable — the single interaction contract for every usable object.
##
## Purpose: doors, containers, cars, beds, radios, workbenches, NPCs and generators all
##   extend this class. The player's InteractionSensor only talks to this API.
## Dependencies: GameState, Conditions, Consequences, AudioManager.
## Public API: interact(actor), is_available(), check_requirements(), get_prompt(),
##   is_used(), mark_used()
## Override: _on_interact(actor) -> bool (true = success, consequences are applied),
##   get_interaction_text(), _is_available()
## Signals: interacted(actor)
## Save Data: GameState.world_objects[persistent_id] ("used", "looted", custom keys)

signal interacted(actor: Node)

@export var display_name: String = "Объект"
@export var interaction_text: String = "Осмотреть"
## AudioManager sound id played on successful use.
@export var interaction_sound: String = "click"
@export var cooldown: float = 0.4
@export var one_time_use: bool = false
## Hide this node (and its visuals) when it is no longer available.
@export var hide_when_unavailable: bool = false

@export_group("Requirements")
@export var required_item: String = ""
@export var required_item_count: int = 1
@export var consume_required_item: bool = false
@export var required_flag: String = ""
@export var required_shelter_level: int = 0
## Extra data-driven requirements (Conditions). Failing shows requirement_text.
@export var conditions: Array = []
@export_multiline var requirement_text: String = ""
## Conditions for the object to exist at all (e.g. only after a story beat).
@export var available_if: Array = []

@export_group("Effects")
## Consequences applied after a successful interaction.
@export var consequences: Array = []
## Stable id for saving; derived from the level and node path when empty.
@export var persistent_id: String = ""

var _last_used: float = -1000.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")
	if persistent_id.is_empty():
		persistent_id = _compute_persistent_id()
	GameState.story_flag_changed.connect(_on_flag_changed)
	_update_visibility()


func _compute_persistent_id() -> String:
	var node: Node = get_parent()
	while node and not (node is Level):
		node = node.get_parent()
	if node is Level:
		return "%s:%s" % [node.level_id, node.get_path_to(self)]
	return str(get_path())


func _ctx() -> Dictionary:
	return {"source": self}


# --- Availability ------------------------------------------------------------------------

func is_available() -> bool:
	if one_time_use and is_used():
		return false
	if not available_if.is_empty() and not Conditions.check_all(available_if, _ctx()):
		return false
	return _is_available()


## Override for custom availability.
func _is_available() -> bool:
	return true


func is_used() -> bool:
	return bool(GameState.get_object_state(persistent_id).get("used", false))


func mark_used() -> void:
	GameState.set_object_state(persistent_id, "used", true)
	_update_visibility()


func get_state(key: String, default: Variant = null) -> Variant:
	return GameState.get_object_state(persistent_id).get(key, default)


func set_state(key: String, value: Variant) -> void:
	GameState.set_object_state(persistent_id, key, value)


func _on_flag_changed(_flag: String, _value: Variant) -> void:
	_update_visibility()


func _update_visibility() -> void:
	if hide_when_unavailable:
		visible = is_available()


# --- Prompt ------------------------------------------------------------------------------------

func get_interaction_text() -> String:
	return interaction_text


func get_prompt() -> String:
	var t := get_interaction_text()
	return t if display_name.is_empty() else "%s — %s" % [t, display_name]


## Returns "" when all requirements pass, otherwise the text to show.
func check_requirements() -> String:
	var missing := ""
	if not required_flag.is_empty() and not GameState.has_flag(required_flag):
		missing = "locked"
	elif not required_item.is_empty() and not GameState.inventory.has_item(required_item, required_item_count):
		missing = "Нужно: %s ×%d" % [Data.get_item_name(required_item), required_item_count]
	elif required_shelter_level > GameState.shelter_level:
		missing = "Нужна мастерская уровня %d" % required_shelter_level
	elif not conditions.is_empty() and not Conditions.check_all(conditions, _ctx()):
		missing = "locked"
	if missing.is_empty():
		return ""
	if not requirement_text.is_empty():
		return GameState.format_text(requirement_text)
	return "Пока ничего не выйдет." if missing == "locked" else missing


# --- Use -------------------------------------------------------------------------------------------

func interact(actor: Node) -> void:
	if not is_available():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_used < cooldown:
		return
	_last_used = now
	var fail := check_requirements()
	if not fail.is_empty():
		GameState.notify(fail, "warning")
		AudioManager.play_ui("deny")
		return
	if not _on_interact(actor):
		return
	if consume_required_item and not required_item.is_empty():
		GameState.inventory.remove(required_item, required_item_count)
	if not interaction_sound.is_empty():
		AudioManager.play_sfx(interaction_sound)
	Consequences.apply_all(consequences, _ctx())
	if one_time_use:
		mark_used()
	interacted.emit(actor)


## Override. Return false to cancel (no sound, no consequences).
func _on_interact(_actor: Node) -> bool:
	return true
