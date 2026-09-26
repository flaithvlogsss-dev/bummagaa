class_name Door
extends Interactable
## Door — a physical door that blocks the way until it is opened (walk-in interiors, garages,
## back rooms, the secret room behind a wardrobe).
##
## Ways in: unlocked doors just open; `key_item` opens silently; a lockpick opens quietly but
## wears (and can break); a crowbar forces it open loudly (a noise the things outside hear);
## `open_flag` opens it from the story. Opened state is saved per door.
## Children: "Blocker" (StaticBody3D collider) and "Visual" (Node3D swung or slid when open).
## open_mode: "swing" (hinged, 90°), "slide" (moves along its local X by slide_distance) or
## "hide" (the visual disappears — a snowdrift dug through, boards torn off).

@export var locked: bool = false
@export var key_item: String = ""
@export var allow_lockpick: bool = true
@export var allow_crowbar: bool = true
## Opens the door when this flag becomes true (story).
@export var open_flag: String = ""
@export_enum("swing", "slide", "hide") var open_mode: String = "swing"
@export var slide_distance: float = 1.3
@export_multiline var locked_text: String = "Заперто."
@export_multiline var open_text: String = ""

var _blocker: CollisionShape3D
var _visual: Node3D
var _closed_transform: Transform3D


func _init() -> void:
	interaction_text = "Открыть"
	interaction_sound = "door"


func _ready() -> void:
	super._ready()
	var body := get_node_or_null("Blocker") as StaticBody3D
	if body:
		body.collision_layer = 1
		_blocker = body.get_node_or_null("Shape") as CollisionShape3D
	_visual = get_node_or_null("Visual") as Node3D
	if _visual:
		_closed_transform = _visual.transform
	if is_open() or (not open_flag.is_empty() and GameState.has_flag(open_flag)):
		_apply_open(false)


func is_open() -> bool:
	return bool(get_state("open", false))


func _is_available() -> bool:
	return not is_open()


func get_interaction_text() -> String:
	if not locked or (not open_flag.is_empty() and GameState.has_flag(open_flag)):
		return interaction_text
	var inv := GameState.inventory
	if not key_item.is_empty() and inv.has_item(key_item):
		return "Открыть ключом"
	if allow_lockpick and inv.has_item("lockpick"):
		return "Вскрыть отмычкой"
	if allow_crowbar and inv.has_item("crowbar"):
		return "Выломать монтировкой"
	return "Заперто"


func _on_flag_changed(flag: String, value: Variant) -> void:
	super._on_flag_changed(flag, value)
	if flag == open_flag and Conditions.truthy(value) and not is_open():
		_open()


func _on_interact(_actor: Node) -> bool:
	if not locked or (not open_flag.is_empty() and GameState.has_flag(open_flag)):
		_open()
		return true
	var inv := GameState.inventory
	if not key_item.is_empty() and inv.has_item(key_item):
		GameState.notify("Ключ подошёл.", "info")
		_open()
		return true
	if allow_lockpick and inv.has_item("lockpick"):
		var broke := _wear_lockpick()
		if randf() < 0.75:
			GameState.notify("Замок щёлкнул." + (" Отмычки сломались." if broke else ""), "info")
			_open()
			return true
		GameState.notify("Не поддаётся. Ещё раз?" + (" Отмычки сломались." if broke else ""), "warning")
		AudioManager.play_sfx("clunk", global_position, -6.0)
		return false
	if allow_crowbar and inv.has_item("crowbar"):
		AudioManager.play_sfx("metal_distant", global_position, 2.0, 1.4)
		Stealth.emit_noise(get_tree(), global_position, 0.9, "player")
		GameState.notify("Дверь с треском поддаётся — это было громко.", "warning")
		_open()
		return true
	GameState.notify(GameState.format_text(locked_text), "warning")
	AudioManager.play_ui("deny")
	return false


## Lockpicks wear with every try; returns true when they break.
func _wear_lockpick() -> bool:
	var inv := GameState.inventory
	for i in inv.get_slots().size():
		var s: Dictionary = inv.get_slots()[i]
		if s.is_empty() or s.id != "lockpick":
			continue
		s["cond"] = float(s.get("cond", 100.0)) - randf_range(15.0, 35.0)
		if float(s.cond) <= 0.0:
			inv.take_at(i, 1)
			return true
		inv.changed.emit()
		return false
	return false


func _open() -> void:
	set_state("open", true)
	if not open_text.is_empty():
		GameState.notify(GameState.format_text(open_text))
	_apply_open(true)
	_update_visibility()


func _apply_open(animated: bool) -> void:
	if _blocker:
		_blocker.set_deferred("disabled", true)
	if _visual == null:
		return
	if open_mode == "hide":
		if animated and is_inside_tree():
			var h := create_tween()
			h.tween_property(_visual, "scale", Vector3(1.0, 0.05, 1.0), 0.8)
			h.tween_callback(_visual.hide)
		else:
			_visual.hide()
		return
	var target := _closed_transform
	if open_mode == "slide":
		target.origin += _closed_transform.basis.x.normalized() * slide_distance
	else:
		target.basis = _closed_transform.basis.rotated(Vector3.UP, deg_to_rad(-100.0))
	if animated and is_inside_tree():
		var t := create_tween()
		t.tween_property(_visual, "transform", target, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		_visual.transform = target
