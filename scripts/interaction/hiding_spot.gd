class_name HidingSpot
extends Interactable
## Place to hide from the Snow Stalker (behind bins, in a doorway).


func _init() -> void:
	display_name = "Укрытие"
	interaction_sound = "rustle"
	cooldown = 0.6


func get_interaction_text() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.get("hiding_spot") == self:
		return "Выйти из укрытия"
	return "Спрятаться"


func _on_interact(actor: Node) -> bool:
	if actor.has_method("toggle_hide"):
		actor.toggle_hide(self)
		return true
	return false
