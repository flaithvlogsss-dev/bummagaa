class_name IndoorZone
extends Area3D
## IndoorZone — marks the inside of an enterable building.
##
## Purpose: the player counts as indoors (sheltered from snow and wind) and the building's
##   roof / front wall (nodes in group "cutaway:<building_id>") are dithered away.
## Dependencies: SurvivalSystem on the player.

@export var building_id: String = ""
## Heated interiors warm the player faster (e.g. a lit stove inside).
@export var heated_flag: String = "__never__"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func is_heated() -> bool:
	return heated_flag.is_empty() or GameState.has_flag(heated_flag)


func _on_enter(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var survival = body.get("survival")
	if survival:
		survival.enter_indoor(self)
	if not building_id.is_empty():
		get_tree().call_group("cutaway:" + building_id, "set_cutaway", true)


func _on_exit(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var survival = body.get("survival")
	if survival:
		survival.exit_indoor(self)
	if not building_id.is_empty():
		get_tree().call_group("cutaway:" + building_id, "set_cutaway", false)
