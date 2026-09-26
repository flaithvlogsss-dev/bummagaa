class_name Main
extends Node
## Main — boots the game and owns the flow between title, play, death and ending.
##
## Purpose: the only scene you need to run. Holds the persistent Player, CameraRig and UI;
##   swaps location scenes inside LevelContainer with a fade transition; runs sleep, death and
##   endings. The 3D world renders inside a low-resolution SubViewport (nearest filtering)
##   so pixel-art sprites and low-poly geometry share one look; UI stays crisp on top.
## Dependencies: every autoload; UIRoot; Level scenes.
## Public API (static, null-safe): request_level_change(), request_sleep(), get_player(),
##   get_mouse_world_point(); instance: new_game(), continue_game(), change_level(), sleep()
## Signals: level_changed(level_id), game_started

signal level_changed(level_id: String)
signal game_started

enum Mode { TITLE, PLAYING, DEAD, ENDING }

const LEVELS := {
	"shelter": "res://scenes/shelter/Shelter.tscn",
	"district": "res://scenes/world/District.tscn",
}
const START_ITEMS := {}

static var instance: Main

var mode: Mode = Mode.TITLE
var current_level: Level
var current_level_id: String = ""
var transitioning: bool = false
var _pending_ending: String = ""

@onready var world_view: SubViewportContainer = $WorldView
@onready var world_viewport: SubViewport = $WorldView/WorldViewport
@onready var level_container: Node3D = $WorldView/WorldViewport/World/LevelContainer
@onready var player: Player = $WorldView/WorldViewport/World/Player
@onready var camera_rig: CameraRig = $WorldView/WorldViewport/World/CameraRig
@onready var weather_visuals: WeatherVisuals = $WorldView/WorldViewport/World/WeatherVisuals


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world_view.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera_rig.set_target(player)
	Settings.settings_changed.connect(_apply_video_settings)
	_apply_video_settings()
	GameState.stats.died.connect(_on_player_died)
	GameState.ending_requested.connect(_on_ending_requested)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_set_world_active(false)
	if OS.get_environment("LASTSNOW_AUTOSTART") == "1":
		new_game.call_deferred()
	else:
		UIRoot.show_title()


func _apply_video_settings() -> void:
	world_view.stretch_shrink = clampi(Settings.pixel_scale, 1, 4)
	get_tree().root.content_scale_factor = Settings.ui_scale


func _set_world_active(active: bool) -> void:
	player.set_physics_process(active)
	player.visible = active
	player.set_input_enabled(active)
	TimeManager.running = active and GameState.has_flag("intro_done")


# --- Static helpers --------------------------------------------------------------------------

static func request_level_change(level_id: String, spawn_id: String) -> void:
	if instance:
		instance.change_level(level_id, spawn_id)


static func request_sleep() -> void:
	if instance:
		instance.sleep()


static func get_player() -> Player:
	return instance.player if instance else null


## Mouse cursor projected onto the horizontal plane at `height` (world space), or null.
static func get_mouse_world_point(height: float = 0.0) -> Variant:
	if instance == null:
		return null
	var cam := instance.world_viewport.get_camera_3d()
	if cam == null:
		return null
	# Map the window mouse position into the low-resolution SubViewport explicitly.
	var view := instance.world_view
	var local := view.get_global_transform_with_canvas().affine_inverse() * view.get_viewport().get_mouse_position()
	var mouse := local / float(maxi(view.stretch_shrink, 1))
	var origin := cam.project_ray_origin(mouse)
	var normal := cam.project_ray_normal(mouse)
	var plane := Plane(Vector3.UP, height)
	return plane.intersects_ray(origin, normal)


# --- Game flow ---------------------------------------------------------------------------------

func _reset_systems() -> void:
	DialogueManager.reset()
	GameState.new_game()
	TimeManager.reset()
	WeatherManager.reset()
	QuestManager.reset()
	EventManager.reset()
	RadioManager.reset()
	AudioManager.stop_all_layers()


func new_game() -> void:
	UIRoot.close_all()
	_reset_systems()
	for id in START_ITEMS.keys():
		GameState.inventory.add(id, START_ITEMS[id], true)
	mode = Mode.PLAYING
	await change_level("shelter", "start", false)
	_set_world_active(true)
	get_tree().paused = false
	UIRoot.fade_in(1.5)
	EventManager.trigger("intro_start", true)
	game_started.emit()


func continue_game() -> void:
	var slot := SaveManager.latest_slot()
	if slot.is_empty():
		new_game()
		return
	load_slot(slot)


func load_slot(slot: String) -> bool:
	var data := SaveManager.read_slot(slot)
	if data.is_empty():
		GameState.notify("Не удалось загрузить сохранение.", "danger")
		return false
	UIRoot.close_all()
	await UIRoot.fade_out(0.3)
	_reset_systems()
	SaveManager.apply(data)
	mode = Mode.PLAYING
	var loc := GameState.current_location if LEVELS.has(GameState.current_location) else "shelter"
	await change_level(loc, "default", false, GameState.player_position)
	_set_world_active(true)
	get_tree().paused = false
	UIRoot.fade_in(0.6)
	GameState.present("title_card", {"text": TimeManager.format_day()})
	game_started.emit()
	return true


func return_to_title() -> void:
	UIRoot.close_all()
	await UIRoot.fade_out(0.4)
	_clear_level()
	_set_world_active(false)
	AudioManager.stop_all_layers()
	mode = Mode.TITLE
	get_tree().paused = false
	UIRoot.show_title()
	UIRoot.fade_in(0.4)


func _clear_level() -> void:
	if current_level:
		level_container.remove_child(current_level)
		current_level.queue_free()
		current_level = null
	current_level_id = ""


## Swaps the active location. position overrides the spawn point (used by loading saves).
func change_level(level_id: String, spawn_id: String = "default", fade: bool = true, position: Variant = null) -> void:
	if transitioning:
		return
	if not LEVELS.has(level_id):
		push_warning("Main: unknown level '%s'" % level_id)
		return
	transitioning = true
	if fade:
		await UIRoot.fade_out(0.35)
	_clear_level()
	var scene: PackedScene = load(LEVELS[level_id])
	current_level = scene.instantiate()
	level_container.add_child(current_level)
	current_level_id = level_id
	GameState.set_location(level_id)
	var t := current_level.get_spawn_transform(spawn_id)
	if position is Vector3 and position != Vector3.ZERO:
		t.origin = position
	player.teleport(t)
	player.on_level_changed(current_level)
	camera_rig.set_bounds(current_level.bounds)
	camera_rig.set_interior(current_level.is_interior)
	weather_visuals.interior = current_level.is_interior
	camera_rig.snap()
	AudioManager.set_muffled(current_level.is_interior)
	await get_tree().physics_frame
	EventManager.on_location_entered(level_id)
	if level_id == "shelter" and GameState.has_flag("intro_done"):
		SaveManager.autosave("shelter")
	if fade:
		await UIRoot.fade_in(0.35)
	transitioning = false
	level_changed.emit(level_id)


func sleep() -> void:
	if transitioning:
		return
	transitioning = true
	player.set_input_enabled(false)
	await UIRoot.fade_out(1.2)
	var night_event := EventManager.pick_night_event()
	var before := TimeManager.total_minutes
	TimeManager.skip_to_hour(TimeManager.DAY_START_HOUR)
	var hours := (TimeManager.total_minutes - before) / 60.0
	player.survival.apply_sleep(hours)
	if not night_event.is_empty():
		EventManager.trigger(night_event, true)
	player.set_input_enabled(true)
	transitioning = false
	if mode != Mode.PLAYING:
		return
	GameState.present("title_card", {"text": TimeManager.format_day()})
	SaveManager.autosave("morning")
	await UIRoot.fade_in(1.2)


func _on_player_died() -> void:
	if mode != Mode.PLAYING:
		return
	mode = Mode.DEAD
	player.set_input_enabled(false)
	AudioManager.play_sfx("heartbeat")
	await get_tree().create_timer(1.2).timeout
	UIRoot.show_death()


func _on_ending_requested(ending_id: String) -> void:
	if mode != Mode.PLAYING:
		return
	if DialogueManager.is_active():
		_pending_ending = ending_id
		return
	_show_ending(ending_id)


func _on_dialogue_ended(_id: String) -> void:
	if not _pending_ending.is_empty() and not DialogueManager.is_active():
		var e := _pending_ending
		_pending_ending = ""
		_show_ending.call_deferred(e)


func _show_ending(ending_id: String) -> void:
	mode = Mode.ENDING
	player.set_input_enabled(false)
	SaveManager.autosave("ending", true)
	await UIRoot.fade_out(1.5)
	UIRoot.show_ending(ending_id)
