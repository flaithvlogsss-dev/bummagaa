class_name Level
extends Node3D
## Level — base script for every location scene (District.tscn, Shelter.tscn).
##
## Purpose: identifies the location, exposes spawn points and camera/map bounds, and
##   spawns the NPCs whose GameState location is this level.
## Spawn points: Marker3D nodes named "spawn_<id>" (player) and "npc_<id>" (NPCs).
## Dependencies: GameState (npc registry), NPC scene.
## Also spawns the WorldItems of GameState.dropped_items for this level.
## Public API: get_spawn_transform(id), is_heated(), refresh_npcs(), get_npc_node(id)
## Signals: level_ready

signal level_ready

const NPC_SCENE := "res://scenes/npc/NPC.tscn"
const WORLD_ITEM_SCENE := "res://scenes/items/WorldItem.tscn"

@export var level_id: String = ""
@export var display_name: String = ""
@export var is_interior: bool = false
## Interior counts as heated while these Conditions pass (empty = always heated).
@export var heated_conditions: Array = []
## XZ limits for the camera and the map.
@export var bounds: Rect2 = Rect2(-80, -65, 160, 120)
@export var default_spawn: String = "default"
## Ambient audio profile: "outdoor" or "indoor".
@export var ambient_profile: String = "outdoor"

var _npc_nodes: Dictionary = {}
var _actors: Node3D


func _ready() -> void:
	add_to_group("level")
	_actors = get_node_or_null("Actors")
	if _actors == null:
		_actors = Node3D.new()
		_actors.name = "Actors"
		add_child(_actors)
	refresh_npcs()
	for entry in GameState.get_dropped(level_id):
		_spawn_world_item(entry)
	GameState.world_request.connect(_on_world_request)
	level_ready.emit()


func is_heated() -> bool:
	return is_interior and Conditions.check_all(heated_conditions)


func get_spawn_transform(spawn_id: String) -> Transform3D:
	var marker := find_child("spawn_" + spawn_id, true, false) as Node3D
	if marker == null:
		marker = find_child("spawn_" + default_spawn, true, false) as Node3D
	if marker == null:
		push_warning("Level %s: no spawn '%s'" % [level_id, spawn_id])
		return Transform3D(Basis(), Vector3(0, 0.1, 0))
	return marker.global_transform


func get_npc_node(npc_id: String) -> Node3D:
	var n = _npc_nodes.get(npc_id)
	return n if is_instance_valid(n) else null


## Makes the spawned NPC set match GameState (alive NPCs here, bodies of NPCs who died here).
func refresh_npcs() -> void:
	var wanted: Dictionary = {}
	for id in GameState.npcs.list_at(level_id, true):
		wanted[id] = true
	for id in _npc_nodes.keys():
		var node = _npc_nodes[id]
		var alive_now := GameState.npcs.is_alive(id)
		var stale: bool = not wanted.has(id) or not is_instance_valid(node) or (node.is_dead_body != (not alive_now))
		if stale:
			if is_instance_valid(node):
				node.queue_free()
			_npc_nodes.erase(id)
	for id in wanted.keys():
		if _npc_nodes.has(id):
			continue
		_spawn_npc(id)


func _spawn_npc(npc_id: String) -> void:
	var data := Data.get_character(npc_id)
	if data == null:
		return
	var scene: PackedScene = load(NPC_SCENE)
	if scene == null:
		return
	var st := GameState.npcs.get_state(npc_id)
	var alive: bool = st.get("alive", false)
	var spawn_id: String = str(st.get("spawn", "")) if alive else str(st.get("death", {}).get("spawn", ""))
	var npc: Node3D = scene.instantiate()
	npc.name = "NPC_" + npc_id
	npc.set("character_id", npc_id)
	npc.set("is_dead_body", not alive)
	_actors.add_child(npc)
	var marker := find_child("npc_" + spawn_id, true, false) as Node3D
	if marker == null:
		marker = find_child("npc_" + npc_id, true, false) as Node3D
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if marker:
		npc.global_transform = marker.global_transform
	elif spawn_id == "debug" and player:
		npc.global_position = player.global_position + Vector3(1.5, 0, 1.0)
	else:
		npc.global_position = get_spawn_transform(default_spawn).origin + Vector3(randf_range(-2, 2), 0, randf_range(1, 2))
	var death_pos: Array = st.get("death", {}).get("position", [])
	if not alive and death_pos.size() == 3:
		npc.global_position = Vector3(death_pos[0], death_pos[1], death_pos[2])
	_npc_nodes[npc_id] = npc


func _spawn_world_item(entry: Dictionary) -> void:
	var scene: PackedScene = load(WORLD_ITEM_SCENE)
	var node: WorldItem = scene.instantiate()
	node.setup(entry, level_id)
	_actors.add_child(node)


func _on_world_request(kind: String, data: Dictionary) -> void:
	match kind:
		"npc_moved":
			refresh_npcs.call_deferred()
		"item_dropped":
			if GameState.current_location == level_id:
				_spawn_world_item(data.entry)
