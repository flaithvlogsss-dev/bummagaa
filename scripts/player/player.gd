class_name Player
extends CharacterBody3D
## Player — movement, interaction, stealth noise, hiding and component wiring for Alex.
##
## Purpose: smooth camera-relative movement (walk / sprint / sneak with acceleration and
##   deceleration), stamina use, interaction, flashlight, footprints and breath.
## Dependencies: SurvivalSystem, InteractionSensor, PlayerFlashlight, PlayerCombat,
##   Footprints, BreathEffect, PixelCharacter (child nodes), GameState.
## Public API: teleport(transform), on_level_changed(level), toggle_hide(spot),
##   take_damage(amount, dir), set_input_enabled(bool)
## Signals: interaction_focus_changed(target), hid(bool)

signal interaction_focus_changed(target: Interactable)
signal hid(hidden: bool)

@export var walk_speed: float = 3.3
@export var sprint_speed: float = 5.8
@export var sneak_speed: float = 1.7
@export var acceleration: float = 22.0
@export var deceleration: float = 16.0
@export var sprint_stamina_per_second: float = 15.0
@export var gravity: float = 22.0

var input_enabled: bool = true
var is_sprinting: bool = false
var is_sneaking: bool = false
## 0..1 continuous noise (read by enemies).
var noise_level: float = 0.0
var facing: Vector2 = Vector2(0, 1)
var current_area: String = ""
var hiding_spot: Node3D = null
var god_mode: bool = false

@onready var sprite: PixelCharacter = $Sprite
@onready var survival: SurvivalSystem = $Survival
@onready var sensor: InteractionSensor = $InteractionSensor
@onready var flashlight: PlayerFlashlight = $Flashlight
@onready var combat: PlayerCombat = $Combat
var thrower: PlayerThrow
@onready var footprints: Footprints = $Footprints
@onready var breath: BreathEffect = $Breath

var _step_t: float = 0.0
var _areas: Array[String] = []


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	sprite.setup_character(Data.get_character("player"))
	breath.survival = survival
	sensor.focus_changed.connect(func(t): interaction_focus_changed.emit(t))
	thrower = PlayerThrow.new()
	thrower.name = "Throw"
	add_child(thrower)


func set_input_enabled(value: bool) -> void:
	input_enabled = value


func _physics_process(delta: float) -> void:
	var can_act := input_enabled and not GameState.stats.dead
	var input := Vector2.ZERO
	if can_act:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if hiding_spot != null:
		if input.length() > 0.3:
			toggle_hide(hiding_spot)
		input = Vector2.ZERO
	var dir3 := Vector3(input.x, 0.0, input.y)
	var cam := get_viewport().get_camera_3d()
	if cam:
		dir3 = Basis(Vector3.UP, cam.global_rotation.y) * dir3
	var moving_input := dir3.length() > 0.1
	is_sneaking = can_act and Input.is_action_pressed("sneak")
	is_sprinting = can_act and moving_input and Input.is_action_pressed("sprint") and not is_sneaking and survival.can_sprint() and not combat.aiming
	var speed := walk_speed
	if is_sprinting:
		speed = sprint_speed
	elif is_sneaking:
		speed = sneak_speed
	if combat.aiming:
		speed *= 0.45
	speed *= survival.get_speed_multiplier()
	var target := dir3.normalized() * speed * minf(1.0, input.length())
	var rate := acceleration if moving_input else deceleration
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	var planar := Vector2(velocity.x, velocity.z)
	var moving := planar.length() > 0.35
	if is_sprinting and moving:
		survival.use_stamina(sprint_stamina_per_second * WeatherManager.stamina_cost * delta)
	survival.sprinting = is_sprinting and moving
	survival.moving = moving
	if combat.aiming:
		facing = combat.aim_direction
	elif moving:
		facing = planar.normalized()
	sprite.face(facing)
	sprite.moving = moving
	sprite.aiming = combat.aiming
	sprite.anim_fps = 10.0 if is_sprinting else 7.0
	sensor.facing = facing
	flashlight.target_yaw = atan2(-facing.x, -facing.y)

	# Continuous noise level for stealth.
	if not moving:
		noise_level = 0.0
	elif is_sneaking:
		noise_level = 0.12
	elif is_sprinting:
		noise_level = 0.8
	else:
		noise_level = 0.35

	var outdoors := not survival.is_indoors()
	footprints.track(global_position, facing, outdoors and moving)
	breath.update_breath(delta, facing)
	_footstep_sounds(delta, moving, outdoors)
	combat.process_combat(delta, can_act and hiding_spot == null)

	if can_act:
		if Input.is_action_just_pressed("interact"):
			sensor.interact(self)
		if Input.is_action_just_pressed("flashlight"):
			flashlight.toggle()
		if Input.is_action_just_pressed("heal_quick"):
			quick_heal()
		if Input.is_action_just_pressed("throw") and hiding_spot == null:
			thrower.throw_item()
		for i in Inventory.QUICK_SLOTS:
			if Input.is_action_just_pressed("quick_%d" % (i + 1)):
				use_quick_slot(i)


## [H]: the cheapest thing that helps — bandages for bleeding, medicine for illness,
## a first aid kit or painkillers for low health.
func quick_heal() -> void:
	var s := GameState.stats
	var inv := GameState.inventory
	var options: Array = []
	if s.bleeding > 0.0:
		options = ["rag_bandage", "bandage", "first_aid_kit"]
	elif s.illness:
		options = ["medicine"]
	elif s.health < 70.0:
		options = ["bandage", "rag_bandage", "splint", "painkillers", "first_aid_kit"]
	var id := ""
	for o in options:
		if inv.count_in_grid(o) > 0:
			id = o
			break
	if id.is_empty():
		GameState.notify("Нечем лечиться (или незачем).", "warning")
		return
	inv.consume(id)
	AudioManager.play_sfx("rustle")
	GameState.notify("Использовано: %s" % Data.get_item_name(id), "item")


## Keys 1..5: throw, draw or use the bound item.
func use_quick_slot(index: int) -> void:
	var inv := GameState.inventory
	var id := inv.get_quick(index)
	if id.is_empty():
		GameState.notify("Слот %d пуст. Назначь предмет в рюкзаке: наведи и нажми %d." % [index + 1, index + 1], "info")
		return
	var item := Data.get_item(id)
	if item == null or not inv.has_item(id):
		GameState.notify("Нет: %s" % Data.get_item_name(id), "warning")
		return
	if item.throwable:
		thrower.throw_item(id)
	elif item.is_equippable():
		if inv.is_equipped(id):
			inv.unequip(item.equip_slot)
		else:
			inv.equip(id)
		AudioManager.play_sfx("equip")
	elif item.is_usable() and inv.consume(id):
		AudioManager.play_sfx("eat" if item.category in ["Food", "Water"] else "rustle")
		GameState.notify("%s: %s" % [item.use_text, item.name], "item")


func _footstep_sounds(delta: float, moving: bool, outdoors: bool) -> void:
	if not moving:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.28 if is_sprinting else (0.55 if is_sneaking else 0.4)
		var vol := -16.0 if is_sneaking else (-8.0 if is_sprinting else -12.0)
		AudioManager.play_sfx("footstep_snow" if outdoors else "footstep_hard", null, vol, randf_range(0.85, 1.15))


func push_area(area_name: String) -> void:
	_areas.append(area_name)
	current_area = area_name


func pop_area(area_name: String) -> void:
	var i := _areas.rfind(area_name)
	if i >= 0:
		_areas.remove_at(i)
	current_area = _areas[-1] if not _areas.is_empty() else ""


func teleport(t: Transform3D) -> void:
	global_position = t.origin + Vector3(0, 0.05, 0)
	velocity = Vector3.ZERO
	var fwd := -t.basis.z
	if Vector2(fwd.x, fwd.z).length() > 0.1:
		facing = Vector2(fwd.x, fwd.z).normalized()
	footprints.clear()


func on_level_changed(level: Level) -> void:
	survival.set_level(level)
	_areas.clear()
	current_area = ""
	if hiding_spot:
		toggle_hide(hiding_spot)


func toggle_hide(spot: Node3D) -> void:
	if hiding_spot == spot:
		hiding_spot = null
		sprite.pose = ""
		sprite.modulate = Color.WHITE
		hid.emit(false)
		return
	hiding_spot = spot
	velocity = Vector3.ZERO
	global_position = Vector3(spot.global_position.x, global_position.y, spot.global_position.z)
	sprite.pose = "crouch"
	sprite.modulate = Color(0.55, 0.6, 0.7)
	if GameState.stats.flashlight_on:
		GameState.stats.flashlight_on = false
	hid.emit(true)


func take_damage(amount: float, _dir: Vector3 = Vector3.ZERO) -> void:
	if god_mode:
		return
	GameState.stats.modify("health", -amount)
	GameState.stats.modify("stress", amount * 0.6)
	if randf() < 0.45:
		GameState.stats.bleeding = maxf(GameState.stats.bleeding, 40.0)
		GameState.notify("Кровотечение! Нужен бинт.", "danger")
	sprite.flash()
	AudioManager.play_sfx("hurt")
	GameState.present("shake", {"amount": 0.6})
	GameState.present("hurt", {"amount": amount})
