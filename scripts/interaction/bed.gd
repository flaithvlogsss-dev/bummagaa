class_name Bed
extends Interactable
## Sleeping skips to 07:00, runs night events and starts a new day.


func _init() -> void:
	interaction_text = "Лечь спать"
	interaction_sound = ""
	display_name = "Кровать"


func _on_interact(_actor: Node) -> bool:
	if not TimeManager.is_hour_between(20, 7) and GameState.stats.stamina > 20.0:
		GameState.notify("Слишком рано. Сон не придёт.")
		return false
	Main.request_sleep()
	return true
