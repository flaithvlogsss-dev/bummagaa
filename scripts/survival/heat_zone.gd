class_name HeatZone
extends Area3D
## HeatZone — area around a fire, stove or radiator that warms the player.
##
## Purpose: SurvivalSystem sums active heat zones. A zone can require a story flag
##   (e.g. the stove only warms once "stove_lit" is set).
## Consequences on first warm-up can drive tutorials/quests (first_warm_flag).

@export var strength: float = 1.5
@export var active_flag: String = ""
## Set once when the player first warms up here (quest hook, e.g. "found_heat_source").
@export var first_warm_flag: String = ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	add_to_group("heat_zone")
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func is_active() -> bool:
	return active_flag.is_empty() or GameState.has_flag(active_flag)


func _on_enter(body: Node3D) -> void:
	if body.is_in_group("player") and body.get("survival"):
		body.survival.enter_heat(self)
		if is_active() and not first_warm_flag.is_empty():
			GameState.set_flag(first_warm_flag, true)


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player") and body.get("survival"):
		body.survival.exit_heat(self)
