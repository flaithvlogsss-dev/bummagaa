class_name ShelterController
extends Node
## ShelterController — makes the shelter interior reflect story state.
##
## Purpose: lights follow the power (on before the blackout, off after, on again once the
##   generator is repaired); the stove glows while lit; the generator LED; decorations for
##   shelter levels 2 and 3 appear (groups "shelter_level_2", "shelter_level_3").

var _last_signature: String = ""


func _ready() -> void:
	GameState.story_flag_changed.connect(func(_f, _v): _refresh())
	GameState.shelter_upgraded.connect(func(_l): _refresh())
	_refresh.call_deferred()


static func power_on() -> bool:
	if not GameState.has_flag("power_cut"):
		return true
	return GameState.has_flag("generator_repaired") and not GameState.has_flag("generator_failed")


func _refresh() -> void:
	var sig := "%s|%s|%s|%d|%s" % [power_on(), GameState.has_flag("stove_lit"), GameState.has_flag("shelter_radio_on"), GameState.shelter_level, GameState.has_flag("generator_repaired")]
	if sig == _last_signature:
		return
	_last_signature = sig
	var power := power_on()
	for n in get_tree().get_nodes_in_group("power_light"):
		if n is LowPolyProp:
			n.lit = power
	for n in get_tree().get_nodes_in_group("shelter_stove"):
		if n is LowPolyProp:
			n.lit = GameState.has_flag("stove_lit")
	for n in get_tree().get_nodes_in_group("shelter_generator"):
		if n is LowPolyProp:
			n.lit = power and GameState.has_flag("generator_repaired")
	for n in get_tree().get_nodes_in_group("shelter_radio"):
		if n is LowPolyProp:
			n.lit = GameState.has_flag("shelter_radio_on")
	for lvl in [2, 3]:
		for n in get_tree().get_nodes_in_group("shelter_level_%d" % lvl):
			var show: bool = GameState.shelter_level >= int(lvl)
			n.visible = show
			if n is CollisionObject3D:
				n.collision_layer = (16 if n is Interactable else 1) if show else 0
	for n in get_tree().get_nodes_in_group("shelter_level_1_only"):
		n.visible = GameState.shelter_level < 2
		if n is CollisionObject3D:
			n.collision_layer = 1 if GameState.shelter_level < 2 else 0
