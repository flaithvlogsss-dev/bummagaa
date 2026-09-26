class_name SaveSlotsView
extends VBoxContainer
## SaveSlotsView — lists save slots for saving or loading.

var saving: bool = false


func refresh() -> void:
	UIKit.clear(self)
	add_theme_constant_override("separation", 6)
	var slots: Array = ["1", "2", "3"] if saving else ["auto", "1", "2", "3"]
	for slot in slots:
		var info := SaveManager.slot_info(slot)
		var name := "Автосохранение" if slot == "auto" else "Слот %s" % slot
		var desc := "— пусто —"
		if not info.is_empty():
			var date := Time.get_datetime_string_from_unix_time(int(info.timestamp), true)
			desc = "День %d, %s • %s • %s" % [int(info.get("day", 1)), info.get("time", "?"), "убежище" if info.get("location") == "shelter" else "квартал", date]
		var b := UIKit.button("%s:  %s" % [name, desc], _on_slot.bind(slot))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not saving and info.is_empty()
		add_child(b)


func _on_slot(slot: String) -> void:
	if saving:
		if SaveManager.save_to_slot(slot):
			GameState.notify("Игра сохранена (слот %s)." % slot)
		refresh()
	elif Main.instance:
		Main.instance.load_slot(slot)
