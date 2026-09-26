class_name StoveInteractable
extends Interactable
## Wood stove: burns wood for several hours of heat (flag stove_lit, cleared by an event).

@export var wood_cost: int = 2
@export var burn_minutes: int = 480


func _init() -> void:
	display_name = "Печь"
	interaction_sound = "fire"


func get_interaction_text() -> String:
	if GameState.has_flag("stove_lit"):
		return "Печь горит"
	return "Растопить (дерево ×%d)" % wood_cost


func _on_interact(_actor: Node) -> bool:
	if GameState.has_flag("stove_lit"):
		GameState.notify("Печь гудит. Тепло расходится по комнате.")
		return false
	if not GameState.inventory.remove("wood", wood_cost):
		GameState.notify("Нужно дерево ×%d." % wood_cost, "warning")
		return false
	GameState.set_flag("stove_lit", true)
	EventManager.schedule("stove_burns_out", burn_minutes)
	GameState.notify("Огонь занялся. В убежище станет теплее.")
	return true
