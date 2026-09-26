class_name WorldState
extends RefCounted
## WorldState — slow-changing state of the city itself.
##
## Purpose: snow accumulation, threat level, open/closed routes, destroyed buildings,
##   faction attitudes and resource availability. MVP uses a few values; the structure is
##   the extension point for navigation changes, route closures and city simulation.
## Signals: changed(key, value), route_changed(route_id, open)
## Save Data: serialize()/deserialize()

signal changed(key: String, value: Variant)
signal route_changed(route_id: String, open: bool)

const FACTIONS: Array[String] = ["survivors", "unknown"]

var values: Dictionary = {}
var routes: Dictionary = {}
var destroyed_buildings: Array = []
var faction_attitude: Dictionary = {}
var resource_availability: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	values = {"snow_level": 0.12, "threat_level": 0.0, "city_state": "isolated"}
	routes = {"north_road": true, "alley": true, "square": true}
	destroyed_buildings = []
	faction_attitude = {"survivors": 0.0, "unknown": 0.0}
	resource_availability = {"district": 1.0}


func get_value(key: String, default: Variant = null) -> Variant:
	return values.get(key, default)


func set_value(key: String, value: Variant) -> void:
	values[key] = value
	changed.emit(key, value)


func get_snow_level() -> float:
	return float(values.get("snow_level", 0.0))


func is_route_open(route_id: String) -> bool:
	return bool(routes.get(route_id, true))


func set_route(route_id: String, open: bool) -> void:
	routes[route_id] = open
	route_changed.emit(route_id, open)


func change_faction(faction: String, delta: float) -> void:
	faction_attitude[faction] = clampf(float(faction_attitude.get(faction, 0.0)) + delta, -100.0, 100.0)
	changed.emit("faction_" + faction, faction_attitude[faction])


func serialize() -> Dictionary:
	return {
		"values": values.duplicate(true),
		"routes": routes.duplicate(),
		"destroyed_buildings": destroyed_buildings.duplicate(),
		"faction_attitude": faction_attitude.duplicate(),
		"resource_availability": resource_availability.duplicate(),
	}


func deserialize(d: Dictionary) -> void:
	reset()
	values.merge(d.get("values", {}), true)
	routes.merge(d.get("routes", {}), true)
	destroyed_buildings = d.get("destroyed_buildings", []).duplicate()
	faction_attitude.merge(d.get("faction_attitude", {}), true)
	resource_availability.merge(d.get("resource_availability", {}), true)
