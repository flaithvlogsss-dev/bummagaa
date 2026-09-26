class_name SnowStalker
extends CharacterBody3D
## SnowStalker — the first threat. A tall, thin shape that walks in the storm.
##
## Purpose: simple finite-state machine
##   IDLE → PATROL → (hears) INVESTIGATE → (sees) CHASE → ATTACK → SEARCH → RETURN
##   plus RETREAT when wounded and APPARITION for the scripted first sighting.
##   It hears the player's movement noise and gunshots (Stealth), sees worse in whiteout and
##   when the flashlight is off; hiding makes the player almost invisible. Killing it is never
##   required: running, hiding or scaring it off with a shot all work.
## Dependencies: Stealth, Main (player), NavigationAgent3D (optional), AudioManager.
## Public API: take_damage(amount, dir), hear_noise(pos, loudness, source), start_apparition()
## Signals: died, state_changed(state)

signal died
signal state_changed(state: int)

enum State { IDLE, PATROL, INVESTIGATE, CHASE, ATTACK, SEARCH, RETURN, RETREAT, APPARITION }

@export var max_health: float = 70.0
@export var walk_speed: float = 2.3
@export var chase_speed: float = 4.7
@export var attack_range: float = 1.8
@export var attack_damage: float = 14.0
@export var attack_cooldown: float = 1.6
@export var sight_range: float = 13.0
@export var fov_degrees: float = 140.0
@export var lose_sight_time: float = 3.5

var state: State = State.IDLE
var health: float
var patrol_points: Array[Vector3] = []
var home: Vector3

var _patrol_i: int = 0
var _state_t: float = 0.0
var _sense_t: float = 0.0
var _attack_t: float = 0.0
var _windup: float = -1.0
var _step_t: float = 0.0
var _target: Vector3
var _last_seen: Vector3
var _unseen_t: float = 0.0
var _facing: Vector2 = Vector2(0, 1)
var _dying: bool = false
var _chase_budget: float = -1.0

@onready var sprite: PixelCharacter = $Sprite
@onready var agent: NavigationAgent3D = $Agent


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("noise_listener")
	collision_layer = 8
	collision_mask = 1
	health = max_health
	home = global_position
	sprite.setup_sheet(EnemyArt.sheet("stalker"), EnemyArt.W, EnemyArt.H, EnemyArt.COLS, EnemyArt.ROWS, PixelCharacter.LAYOUT_COMPACT)
	sprite.pixel_size = 0.062
	sprite.anim_fps = 5.0
	_set_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)


func start_apparition() -> void:
	_set_state(State.APPARITION)
	_chase_budget = 8.0


func _set_state(s: State) -> void:
	if state == s and _state_t > 0.0:
		return
	state = s
	_state_t = 0.0
	state_changed.emit(s)


# --- Senses ------------------------------------------------------------------------------------

func _player() -> Player:
	var p := Main.get_player()
	return p if p != null and p.is_inside_tree() and GameState.current_location == "district" else null


func _can_see(p: Player) -> bool:
	var to := p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var range_m := sight_range * Stealth.player_visibility(p)
	if dist > range_m:
		return false
	if dist > 3.0:
		var ang := rad_to_deg(_facing.angle_to(Vector2(to.x, to.z).normalized()))
		if absf(ang) > fov_degrees * 0.5:
			return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.8, 0), p.global_position + Vector3(0, 1.0, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _can_hear(p: Player) -> bool:
	return p.global_position.distance_to(global_position) <= Stealth.player_noise_radius(p)


func hear_noise(pos: Vector3, _loudness: float, _source: String) -> void:
	if _dying:
		return
	if state in [State.IDLE, State.PATROL, State.SEARCH, State.RETURN, State.APPARITION]:
		_target = pos
		_set_state(State.INVESTIGATE)


# --- Update -----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _dying:
		return
	_state_t += delta
	_attack_t = maxf(0.0, _attack_t - delta)
	var p := _player()
	_sense_t -= delta
	var sees := false
	if p and _sense_t <= 0.0:
		_sense_t = 0.2
		sees = _can_see(p)
		if sees:
			_last_seen = p.global_position
			_unseen_t = 0.0
		_react(p, sees)
	elif p and state == State.CHASE:
		_unseen_t += delta
	var speed := 0.0
	match state:
		State.IDLE:
			if _state_t > 6.0 and not patrol_points.is_empty():
				_set_state(State.PATROL)
		State.PATROL:
			if patrol_points.is_empty():
				_set_state(State.IDLE)
			else:
				_target = patrol_points[_patrol_i]
				speed = walk_speed
				if _flat_dist(_target) < 1.2:
					_patrol_i = (_patrol_i + 1) % patrol_points.size()
		State.INVESTIGATE:
			speed = walk_speed * 1.3
			if _flat_dist(_target) < 1.5 or _state_t > 14.0:
				_set_state(State.SEARCH)
		State.CHASE:
			if p:
				_target = p.global_position
			speed = chase_speed
			if _chase_budget > 0.0:
				_chase_budget -= delta
				if _chase_budget <= 0.0:
					_set_state(State.RETREAT)
			if p and _flat_dist(p.global_position) < attack_range and _attack_t <= 0.0:
				_set_state(State.ATTACK)
				_windup = 0.45
		State.ATTACK:
			speed = 0.0
			sprite.aiming = true
			_windup -= delta
			if _windup <= 0.0 and _state_t < 1.0:
				if p and _flat_dist(p.global_position) < attack_range + 0.5:
					p.take_damage(attack_damage, (p.global_position - global_position).normalized())
				_attack_t = attack_cooldown
				_windup = 99.0
			if _state_t > 0.9:
				sprite.aiming = false
				_set_state(State.CHASE)
		State.SEARCH:
			speed = walk_speed
			if _state_t > 1.0 and _flat_dist(_target) < 1.2 or fmod(_state_t, 3.0) < delta:
				_target = _last_seen + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			if _state_t > 9.0:
				_set_state(State.RETURN)
		State.RETURN:
			_target = home
			speed = walk_speed
			if _flat_dist(home) < 1.5:
				_set_state(State.PATROL)
		State.RETREAT:
			if p:
				var away := global_position - p.global_position
				away.y = 0
				_target = global_position + away.normalized() * 10.0
			speed = chase_speed
			sprite.modulate.a = clampf(1.0 - (_state_t - 3.0) / 3.0, 0.0, 1.0)
			if _state_t > 6.0:
				queue_free()
		State.APPARITION:
			if p:
				var to := p.global_position - global_position
				_facing = Vector2(to.x, to.z).normalized()
			if _state_t > 7.0:
				_set_state(State.RETREAT)
	_move(speed, delta)
	GameState.stats.modify("stress", delta * (1.2 if p and sees else 0.0))


func _react(p: Player, sees: bool) -> void:
	match state:
		State.IDLE, State.PATROL, State.SEARCH, State.RETURN, State.INVESTIGATE:
			if sees:
				_start_chase()
			elif _can_hear(p) and state != State.INVESTIGATE:
				_target = p.global_position
				_set_state(State.INVESTIGATE)
		State.APPARITION:
			if _flat_dist(p.global_position) < 7.0:
				_start_chase()
		State.CHASE:
			if not sees:
				_unseen_t += 0.2
				if _unseen_t > lose_sight_time:
					_target = _last_seen
					_set_state(State.SEARCH)


func _start_chase() -> void:
	if state != State.CHASE:
		AudioManager.play_sfx("stalker_scream", global_position, -2.0, randf_range(0.9, 1.1))
		GameState.present("shake", {"amount": 0.25})
		GameState.stats.modify("stress", 10.0)
		GameState.set_flag("stalker_encountered", true)
	_unseen_t = 0.0
	_set_state(State.CHASE)


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _move(speed: float, delta: float) -> void:
	var dir := Vector3.ZERO
	if speed > 0.0:
		var next := _target
		if agent and NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
			agent.target_position = _target
			if not agent.is_navigation_finished():
				next = agent.get_next_path_position()
		dir = next - global_position
		dir.y = 0.0
		if dir.length() > 0.05:
			dir = dir.normalized()
			_facing = Vector2(dir.x, dir.z)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = -2.0
	move_and_slide()
	sprite.face(_facing)
	sprite.moving = speed > 0.0 and velocity.length() > 0.2
	sprite.anim_fps = 7.0 if state == State.CHASE else 4.0
	if sprite.moving:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.45 if state == State.CHASE else 0.7
			AudioManager.play_sfx("stalker_step", global_position, -4.0, randf_range(0.8, 1.0))


func take_damage(amount: float, _dir: Vector3 = Vector3.ZERO) -> void:
	if _dying:
		return
	health -= amount
	sprite.flash(Color(0.8, 0.9, 1.0))
	AudioManager.play_sfx("stalker_scream", global_position, -6.0, 1.4)
	if health <= 0.0:
		_die()
	elif health < max_health * 0.4:
		_set_state(State.RETREAT)
	else:
		_last_seen = Main.get_player().global_position if Main.get_player() else global_position
		_start_chase()


func _die() -> void:
	_dying = true
	GameState.set_flag("stalker_killed", true)
	GameState.world.set_value("threat_level", maxf(0.0, float(GameState.world.get_value("threat_level", 0.0)) - 1.0))
	died.emit()
	$Shape.set_deferred("disabled", true)
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color(0.5, 0.6, 0.8, 0.0), 1.5)
	t.tween_callback(queue_free)
