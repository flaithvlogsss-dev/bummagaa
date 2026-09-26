class_name LocationZone
extends Area3D
## LocationZone — named area of the district ("Small square", "Alley"...).
##
## Purpose: discovers the location on first entry (GameState.discovered_locations), labels
##   the map and tells the HUD where the player is.

@export var location_id: String = ""
@export var display_name: String = ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	add_to_group("location_zone")
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("push_area"):
		body.push_area(display_name)
	if GameState.discover_location(location_id):
		GameState.notify("Обнаружено: %s" % display_name, "location")


func _on_exit(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("pop_area"):
		body.pop_area(display_name)


func get_map_rect() -> Rect2:
	var shape_node := get_child(0) as CollisionShape3D
	if shape_node and shape_node.shape is BoxShape3D:
		var s: Vector3 = shape_node.shape.size
		return Rect2(global_position.x - s.x * 0.5, global_position.z - s.z * 0.5, s.x, s.z)
	return Rect2(global_position.x - 5, global_position.z - 5, 10, 10)
