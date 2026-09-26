class_name Stealth
extends RefCounted
## Stealth — noise events and player visibility, shared by all enemies.
##
## Purpose: the player has a continuous noise_level (sneak < walk < sprint) plus discrete
##   noise events (gunshot). Enemies in group "noise_listener" receive hear_noise().
##   Visibility drops with the flashlight off, hiding, sneaking, darkness and whiteout.

## Noise radius in metres for noise level 1.0.
const NOISE_RADIUS := 22.0


static func emit_noise(tree: SceneTree, position: Vector3, loudness: float, source: String = "player") -> void:
	if tree == null:
		return
	var radius := loudness * NOISE_RADIUS * (1.0 - WeatherManager.noise_mask * 0.6)
	for n in tree.get_nodes_in_group("noise_listener"):
		if n.has_method("hear_noise") and n.global_position.distance_to(position) <= radius:
			n.hear_noise(position, loudness, source)


## 0..~2 multiplier on enemy sight range.
static func player_visibility(player: Node) -> float:
	if player == null:
		return 0.0
	var v := 1.0
	var s := GameState.stats
	if player.get("hiding_spot") != null:
		v *= 0.12
	if player.get("is_sneaking"):
		v *= 0.65
	if s.flashlight_on:
		v *= 1.8
	elif TimeManager.is_dark():
		v *= 0.6
	v *= 1.0 - WeatherManager.get_whiteout() * 0.55
	return v


## Noise radius of the player's current movement.
static func player_noise_radius(player: Node) -> float:
	if player == null:
		return 0.0
	return float(player.get("noise_level")) * NOISE_RADIUS * (1.0 - WeatherManager.noise_mask * 0.6)
