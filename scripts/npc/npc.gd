class_name NPC
extends CharacterBody3D
## NPC — a survivor in the world (or their body).
##
## Purpose: visual + talk interaction for a CharacterData id. Behaviour is deliberately
##   simple: idle, short wanders near home, huddling in severe weather, sitting when
##   injured, lying when dead. Story state lives in GameState.npcs, not here.
## Dependencies: Data, GameState, DialogueManager, PixelCharacter, NPCTalk (child).
## Public API: talk(actor), character_id, is_dead_body

@export var character_id: String = ""
@export var is_dead_body: bool = false

var data: CharacterData
var _home: Vector3
var _home_set: bool = false
var _target: Vector3
var _wander_t: float = 0.0
var _talk_face_t: float = 0.0

@onready var sprite: PixelCharacter = $Sprite
@onready var talk_area: Interactable = $Talk
@onready var name_label: Label3D = $Name


func _ready() -> void:
	data = Data.get_character(character_id)
	if data == null:
		queue_free()
		return
	add_to_group("npc")
	collision_layer = 4
	collision_mask = 1
	sprite.setup_character(data)
	talk_area.persistent_id = "npc:" + character_id
	_refresh_labels()
	GameState.npcs.npc_changed.connect(func(id):
		if id == character_id:
			_refresh_labels())
	if is_dead_body:
		sprite.pose = "lie"
		$Shape.disabled = true
	elif GameState.npcs.get_state(character_id).get("injured", false):
		sprite.pose = "sit"


func _refresh_labels() -> void:
	var met: bool = GameState.npcs.get_state(character_id).get("met", false)
	var shown := data.display_name if met else data.unknown_name
	talk_area.display_name = shown
	name_label.text = shown
	if is_dead_body:
		talk_area.interaction_text = "Осмотреть тело"
		name_label.text = ""
	else:
		talk_area.interaction_text = "Поговорить"
		sprite.pose = "sit" if GameState.npcs.get_state(character_id).get("injured", false) else ""


func talk(actor: Node) -> void:
	if is_dead_body:
		_search_body()
		return
	if actor is Node3D:
		var to: Vector3 = actor.global_position - global_position
		sprite.face(Vector2(to.x, to.z))
		_talk_face_t = 3.0
	if not DialogueManager.start(data.dialogue_id, {"npc": character_id}):
		DialogueManager.show_text(data.display_name, data.unique_line)


func _search_body() -> void:
	var st := GameState.npcs.get_state(character_id)
	var death: Dictionary = st.get("death", {})
	GameState.npcs.set_value(character_id, "met", true)
	if death.get("looted", false) or data.death_loot.is_empty():
		DialogueManager.show_text(data.display_name, "%s. Снег уже почти скрыл лицо." % data.display_name)
		return
	death["looted"] = true
	var lines: PackedStringArray = []
	for id in data.death_loot.keys():
		GameState.give_or_drop(str(id), int(data.death_loot[id]), false)
		lines.append("%s ×%d" % [Data.get_item_name(str(id)), int(data.death_loot[id])])
	DialogueManager.show_text(data.display_name, "%s больше не дышит. Иней на ресницах.\n\nВ сумке: %s." % [data.display_name, ", ".join(lines)])
	GameState.set_flag("searched_body_" + character_id, true)


func _physics_process(delta: float) -> void:
	if not _home_set:
		_home = global_position
		_target = _home
		_home_set = true
	if is_dead_body:
		return
	var player := Main.get_player()
	var near := player != null and player.global_position.distance_to(global_position) < 5.0
	name_label.visible = near
	var injured: bool = GameState.npcs.get_state(character_id).get("injured", false)
	var huddle := WeatherManager.is_severe() and GameState.current_location == "district"
	_talk_face_t -= delta
	if injured or huddle or _talk_face_t > 0.0:
		velocity = Vector3.ZERO
		sprite.moving = false
		if near and player:
			var to := player.global_position - global_position
			sprite.face(Vector2(to.x, to.z))
		if huddle and not injured:
			sprite.position.x = sin(Time.get_ticks_msec() * 0.05) * 0.015
		return
	sprite.position.x = 0.0
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(4.0, 9.0)
		_target = _home + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0)) if randf() < 0.6 else _home
	var to_target := _target - global_position
	to_target.y = 0
	if to_target.length() > 0.3 and not near:
		velocity = to_target.normalized() * 1.1
		sprite.face(Vector2(velocity.x, velocity.z))
		sprite.moving = true
	else:
		velocity = Vector3.ZERO
		sprite.moving = false
		if near and player:
			var tp := player.global_position - global_position
			sprite.face(Vector2(tp.x, tp.z))
	velocity.y = -1.0
	move_and_slide()
