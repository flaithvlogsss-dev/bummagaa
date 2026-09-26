class_name PlayerFlashlight
extends SpotLight3D
## PlayerFlashlight — cone light with a limited battery (GameState.stats.flashlight_*).
## Turning it off makes the player much harder to see (see Stealth.player_visibility).

var target_yaw: float = 0.0


func _ready() -> void:
	rotation_degrees.x = -14.0
	spot_range = 17.0
	spot_angle = 30.0
	spot_attenuation = 0.9
	light_energy = 3.2
	light_color = Color(1.0, 0.95, 0.82)
	shadow_enabled = true
	light_volumetric_fog_energy = 1.5
	visible = GameState.stats.flashlight_on


func toggle() -> void:
	var s := GameState.stats
	if not s.flashlight_on and not GameState.inventory.has_item("flashlight"):
		GameState.notify("Нет фонаря.", "warning")
		return
	if not s.flashlight_on and s.flashlight_battery <= 0.5:
		GameState.notify("Батарея фонаря пуста.", "warning")
		AudioManager.play_ui("empty_click")
		return
	s.flashlight_on = not s.flashlight_on
	AudioManager.play_ui("click")


func _process(delta: float) -> void:
	var s := GameState.stats
	if s.flashlight_on and not GameState.inventory.has_item("flashlight"):
		s.flashlight_on = false
	visible = s.flashlight_on
	if not visible:
		return
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 12.0, 0.0, 1.0))
	var energy := 3.2
	if s.flashlight_battery < 15.0 and randf() < 0.08:
		energy = 0.4
	light_energy = energy
