class_name NPCTalk
extends Interactable
## Talk / examine interaction on an NPC; forwards to the owning NPC node.


func _init() -> void:
	interaction_text = "Поговорить"
	interaction_sound = ""
	cooldown = 0.5


func _on_interact(actor: Node) -> bool:
	var npc := get_parent()
	if npc and npc.has_method("talk"):
		npc.talk(actor)
		return true
	return false
