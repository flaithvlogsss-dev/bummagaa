class_name Bed
extends Interactable
## A bed: rest for an hour or three, or sleep until 07:00 (runs night events, starts a new day).
## Sleeping needs night-time (20:00-07:00) or real exhaustion.


func _init() -> void:
	interaction_text = "Отдохнуть"
	interaction_sound = ""
	display_name = "Кровать"


func can_sleep() -> bool:
	return TimeManager.is_hour_between(20, 7) or GameState.stats.stamina < 20.0


func _on_interact(_actor: Node) -> bool:
	var sleep_choice := {"text": "Спать до утра", "consequences": [{"sleep": true}]}
	if not can_sleep():
		sleep_choice["requires"] = [{"flag": "__never"}]
		sleep_choice["requires_text"] = "сон придёт после 20:00"
	DialogueManager.start_data({
		"id": "__bed",
		"start": "ask",
		"nodes": {"ask": {
			"speaker_name": display_name,
			"text": "Сейчас %s. Сколько отдыхать?" % TimeManager.format_clock(),
			"choices": [
				{"text": "Час — перевести дух", "consequences": [{"rest": 1}]},
				{"text": "Три часа", "consequences": [{"rest": 3}]},
				sleep_choice,
				{"text": "Не сейчас"},
			],
		}},
	})
	return true
