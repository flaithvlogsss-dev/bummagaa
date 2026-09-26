class_name InfoPickup
extends Interactable
## A note, document or photo. Reading it stores an Information entry in the journal.

@export var info_id: String = ""


func _init() -> void:
	interaction_text = "Прочитать"
	interaction_sound = "paper"


func _ready() -> void:
	super._ready()
	var info := Data.get_information(info_id)
	if info and (display_name == "Объект" or display_name.is_empty()):
		display_name = info.title


func _on_interact(_actor: Node) -> bool:
	var info := Data.get_information(info_id)
	if info == null:
		return false
	DialogueManager.show_text(info.title, info.content)
	GameState.add_information(info_id)
	return true
