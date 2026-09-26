class_name LevelDoor
extends Interactable
## Door / passage that moves the player to another level with a fade transition.

@export var target_level: String = ""
@export var target_spawn: String = "default"


func _init() -> void:
	interaction_text = "Войти"
	interaction_sound = "door"


func _on_interact(_actor: Node) -> bool:
	if target_level.is_empty():
		return false
	Main.request_level_change(target_level, target_spawn)
	return true
