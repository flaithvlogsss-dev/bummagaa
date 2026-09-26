class_name StationInteractable
extends Interactable
## Opens a UI panel: workbench (crafting), storage, shelter upgrade board, radio.

@export_enum("crafting", "storage", "shelter", "radio") var panel: String = "crafting"
## Passed to the panel, e.g. crafting station id or radio station id.
@export var station_id: String = "workbench"


func _on_interact(_actor: Node) -> bool:
	UIRoot.open_panel(panel, {"station": station_id, "source": self})
	return true
