class_name AmbienceController
extends Node
## AmbienceController — mixes looping ambience from the world state.
##
## Outside: wind, blizzard howl, distant metal and creaks. Inside: muffled wind, room tone,
## generator hum, stove fire. The wind becomes much louder in a blizzard. A low heartbeat
## plays at critical health. Reads WeatherManager / GameState only — no logic of its own.

var _t: float = 0.0
var _oneshot_t: float = 12.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	if Main.instance == null or Main.instance.mode == Main.Mode.TITLE:
		return
	var player := Main.get_player()
	if player == null:
		return
	var level := Main.instance.current_level
	var interior_level := level != null and level.is_interior
	var indoors := player.survival.is_indoors()
	AudioManager.set_muffled(indoors)
	var wind := WeatherManager.wind
	var storm := clampf((WeatherManager.intensity - 0.55) / 0.45, 0.0, 1.0)
	var wind_vol := 0.2 + wind * 0.7
	if indoors:
		wind_vol *= 0.55
	AudioManager.set_layer("wind", "wind", wind_vol)
	AudioManager.set_layer("howl", "wind_howl", storm * (0.45 if indoors else 1.0))
	AudioManager.set_layer("room", "room", 0.35 if interior_level else 0.0)
	var hum := interior_level and GameState.has_flag("generator_repaired") and not GameState.has_flag("generator_failed")
	AudioManager.set_layer("hum", "hum", 0.3 if hum else 0.0)
	var fire := player.survival.heat_strength() > 0.0 or (interior_level and GameState.has_flag("stove_lit"))
	AudioManager.set_layer("fire", "fire_loop", 0.4 if fire else 0.0)
	AudioManager.set_layer("music", "music_drone", 0.3 if not TimeManager.is_dark() else 0.42, "Music")
	AudioManager.set_layer("heartbeat", "heartbeat", 0.8 if GameState.stats.health < 25.0 else 0.0, "SFX")
	if Main.instance.mode != Main.Mode.PLAYING:
		return
	_oneshot_t -= 0.25
	if _oneshot_t <= 0.0:
		_oneshot_t = randf_range(18.0, 40.0)
		if interior_level:
			AudioManager.play_sfx("creak", null, -14.0, randf_range(0.8, 1.2), "Ambient")
		else:
			AudioManager.play_sfx(["metal_distant", "creak"].pick_random(), null, -16.0, randf_range(0.7, 1.1), "Ambient")
