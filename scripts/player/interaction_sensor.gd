class_name InteractionSensor
extends Area3D
## InteractionSensor — finds the best Interactable near the player.
##
## Purpose: overlap sphere on the "interactable" layer; prefers close objects in front of the
##   player. The HUD shows the focused object's prompt.
## Signals: focus_changed(interactable)

signal focus_changed(target: Interactable)

var focused: Interactable
var facing: Vector2 = Vector2(0, 1)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 16
	monitoring = true
	monitorable = false


func _physics_process(_delta: float) -> void:
	var best: Interactable = null
	var best_score := INF
	var origin := global_position
	for area in get_overlapping_areas():
		var it := area as Interactable
		if it == null or not it.is_available() or not it.is_visible_in_tree():
			continue
		var to := it.global_position - origin
		to.y = 0.0
		var dist := to.length()
		var dir := Vector2(to.x, to.z).normalized() if dist > 0.01 else facing
		var score := dist - facing.dot(dir) * 0.8
		if score < best_score:
			best_score = score
			best = it
	if best != focused:
		focused = best
		focus_changed.emit(focused)


func interact(actor: Node) -> void:
	if focused and is_instance_valid(focused) and focused.is_available():
		focused.interact(actor)
		# Prompt text may change after use (e.g. container becomes empty).
		focus_changed.emit(focused if focused.is_available() else null)
