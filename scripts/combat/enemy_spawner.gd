class_name EnemySpawner
extends Node3D
## EnemySpawner — decides when the Snow Stalker walks the district.
##
## Purpose: no enemies on the first evening except the scripted apparition; from day 2 one
##   stalker patrols in the dark or in heavy snow, two in a blizzard. Patrol routes are the
##   Marker3D children of this node's "Routes/<route>" nodes.
## Handles GameState.world_request: "stalker_apparition", "spawn_stalker".

const SCENE := "res://scenes/enemies/SnowStalker.tscn"

var _check_t: float = 2.0
var _routes: Array = []


func _ready() -> void:
	var routes := get_node_or_null("Routes")
	if routes:
		for r in routes.get_children():
			var pts: Array[Vector3] = []
			for m in r.get_children():
				if m is Node3D:
					pts.append(m.global_position)
			if not pts.is_empty():
				_routes.append(pts)
	GameState.world_request.connect(_on_request)


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 5.0
	_evaluate()


func desired_count() -> int:
	if TimeManager.current_day < 2:
		return 0
	if WeatherManager.is_blizzard():
		return 2
	if TimeManager.is_dark() or WeatherManager.get_state() == "HEAVY":
		return 1
	return 0


func _active() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_ancestor_of(e):
			out.append(e)
	return out


func _evaluate() -> void:
	var active := _active()
	var want := desired_count()
	if active.size() < want and not _routes.is_empty():
		_spawn_patrol()
	elif active.size() > want:
		var player := Main.get_player()
		for e in active:
			if player == null or e.global_position.distance_to(player.global_position) > 30.0:
				e.queue_free()
				break


func _spawn_patrol() -> void:
	var player := Main.get_player()
	var candidates := _routes.duplicate()
	candidates.shuffle()
	for route in candidates:
		var start: Vector3 = route[0]
		if player and start.distance_to(player.global_position) < 25.0:
			continue
		var s := _spawn(start)
		if s:
			s.patrol_points.assign(route)
			s._set_state(SnowStalker.State.PATROL)
		return


func _spawn(pos: Vector3) -> SnowStalker:
	var scene: PackedScene = load(SCENE)
	if scene == null:
		return null
	var s: SnowStalker = scene.instantiate()
	add_child(s)
	s.global_position = pos
	s.home = pos
	return s


func _on_request(kind: String, data: Dictionary) -> void:
	var player := Main.get_player()
	if player == null or GameState.current_location != "district":
		return
	match kind:
		"stalker_apparition":
			var dir := Vector3(player.facing.x, 0, player.facing.y)
			if dir.length() < 0.1:
				dir = Vector3(0, 0, -1)
			var pos := player.global_position + dir.normalized() * 15.0 + dir.cross(Vector3.UP) * randf_range(-3.0, 3.0)
			var s := _spawn(pos)
			if s:
				s.start_apparition()
				AudioManager.play_sfx("stalker_step", pos, 2.0, 0.8)
				GameState.stats.modify("stress", 15.0)
		"spawn_stalker":
			var p := player.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 12.0
			var s2 := _spawn(p)
			if s2 and not _routes.is_empty():
				s2.patrol_points.assign(_routes[0])
