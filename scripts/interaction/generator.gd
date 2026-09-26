class_name GeneratorInteractable
extends Interactable
## The shelter generator: check it, repair it with a repair kit, fix it after a breakdown.
## Flags: generator_checked, generator_repaired (power + heat), generator_failed (event).


func _init() -> void:
	display_name = "Генератор"
	interaction_sound = ""


func _is_broken() -> bool:
	return not GameState.has_flag("generator_repaired") or GameState.has_flag("generator_failed")


func get_interaction_text() -> String:
	if not GameState.has_flag("generator_checked"):
		return "Проверить"
	if GameState.has_flag("generator_failed"):
		return "Починить (металлолом ×1)"
	if _is_broken():
		return "Починить (ремкомплект)"
	return "Осмотреть"


func _on_interact(_actor: Node) -> bool:
	if not GameState.has_flag("generator_checked"):
		GameState.set_flag("generator_checked", true)
		AudioManager.play_sfx("clunk")
		DialogueManager.show_text("Генератор", "Стартер щёлкает впустую. Сгорела плата управления, треснул топливный фильтр.\n\nБез ремкомплекта его не запустить. Ремкомплект можно собрать в мастерской: металлолом и электроника.")
		return true
	if GameState.has_flag("generator_failed"):
		if not GameState.inventory.remove("scrap_metal", 1):
			GameState.notify("Нужен металлолом ×1, чтобы залатать генератор.", "warning")
			return false
		GameState.clear_flag("generator_failed")
		GameState.notify("Генератор снова работает.")
		AudioManager.play_sfx("engine_start")
		return true
	if _is_broken():
		if not GameState.inventory.remove("repair_kit", 1):
			GameState.notify("Нужен ремкомплект.", "warning")
			return false
		GameState.set_flag("generator_repaired", true)
		GameState.set_flag("power_on", true)
		AudioManager.play_sfx("engine_start")
		GameState.present("shake", {"amount": 0.25})
		DialogueManager.show_text("Генератор", "Мотор чихает, кашляет — и заводится. Лампы в убежище вспыхивают жёлтым. Батареи начинают потрескивать, нагреваясь.")
		return true
	GameState.notify("Генератор ровно гудит.")
	return false
