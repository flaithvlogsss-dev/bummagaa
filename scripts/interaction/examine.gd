class_name Examine
extends Interactable
## Generic "look at / use" object: shows a text or starts a dialogue, then applies consequences.
## Used for the window, phone, the Unknown's symbol, tracks, the north barricade, transmitter...

@export_multiline var text: String = ""
@export var title: String = ""
@export var dialogue_id: String = ""


func _on_interact(_actor: Node) -> bool:
	if not dialogue_id.is_empty():
		DialogueManager.start(dialogue_id, {"source": self})
	elif not text.is_empty():
		DialogueManager.show_text(title, GameState.format_text(text))
	return true
