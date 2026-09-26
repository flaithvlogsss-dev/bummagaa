class_name UIRoot
extends CanvasLayer
## UIRoot — owns the HUD, all modal panels, fades and global UI hotkeys.
##
## Purpose: world objects never touch UI nodes directly; they call the static helpers
##   (UIRoot.open_panel("crafting", {...})). Only one modal panel is open at a time and it
##   pauses the world. Hotkeys: I inventory, M map, Q journal, Esc menu, F1 debug.
## Dependencies: all panel scripts, DialogueManager, Main.
## Public API (static): open_panel(name, data), close_all(), is_panel_open(), fade_out(t),
##   fade_in(t), show_title(), show_death(), show_ending(id)

static var instance: UIRoot

const HOTKEYS := {"inventory": "inventory", "map": "map", "journal": "journal", "menu": "pause", "debug": "debug"}

var panels: Dictionary = {}
var current: UIPanel = null
var hud: HUD
var root: Control
var _fade: ColorRect
var _fade_tween: Tween


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)
	hud = HUD.new()
	hud.name = "HUD"
	root.add_child(hud)
	_register("dialogue", DialoguePanel.new())
	_register("inventory", InventoryPanel.new())
	_register("storage", ContainerPanel.new())
	_register("container", ContainerPanel.new())
	_register("crafting", CraftingPanel.new())
	_register("shelter", ShelterPanel.new())
	_register("radio", RadioPanel.new())
	_register("journal", JournalPanel.new())
	_register("map", MapPanel.new())
	_register("pause", PauseMenu.new())
	_register("debug", DebugMenu.new())
	_register("death", DeathScreen.new())
	_register("ending", EndingScreen.new())
	_register("title", TitleScreen.new())
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	DialogueManager.dialogue_started.connect(func(_id): _open("dialogue", {}))
	DialogueManager.dialogue_ended.connect(func(_id):
		if current == panels["dialogue"] and not DialogueManager.is_active():
			panels["dialogue"].close())


func _register(panel_name: String, panel: UIPanel) -> void:
	panel.name = panel_name.capitalize().replace(" ", "")
	root.add_child(panel)
	panels[panel_name] = panel


# --- Static API ----------------------------------------------------------------------------

static func open_panel(panel_name: String, data: Dictionary = {}) -> void:
	if instance:
		instance._open(panel_name, data)


static func close_all() -> void:
	if instance and instance.current:
		instance.current.close()


static func is_panel_open() -> bool:
	return instance != null and instance.current != null


static func show_title() -> void:
	open_panel("title")


static func show_death() -> void:
	open_panel("death")


static func show_ending(ending_id: String) -> void:
	open_panel("ending", {"ending": ending_id})


static func fade_out(duration: float = 0.35) -> void:
	if instance:
		await instance._fade_to(1.0, duration)


static func fade_in(duration: float = 0.35) -> void:
	if instance:
		await instance._fade_to(0.0, duration)


# --- Internals ----------------------------------------------------------------------------------

func _fade_to(alpha: float, duration: float) -> void:
	if _fade_tween and _fade_tween.is_valid() and _fade_tween.is_running():
		# Finish (not kill) the previous fade so whoever awaits it is released.
		_fade_tween.custom_step(1000.0)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", alpha, maxf(duration, 0.01))
	await _fade_tween.finished


func _open(panel_name: String, data: Dictionary) -> void:
	var panel: UIPanel = panels.get(panel_name)
	if panel == null:
		push_warning("UIRoot: unknown panel '%s'" % panel_name)
		return
	if current and current != panel:
		if current == panels["dialogue"] and DialogueManager.is_active():
			return
		current.close()
	current = panel
	if not panel.closed.is_connected(_on_panel_closed):
		panel.closed.connect(_on_panel_closed.bind(panel))
	panel.open(data)
	get_tree().paused = panel.pauses_game
	if panel_name != "dialogue":
		AudioManager.play_ui("ui_open")


func _on_panel_closed(panel: UIPanel) -> void:
	if current == panel:
		current = null
		get_tree().paused = false
		if panel != panels["dialogue"]:
			AudioManager.play_ui("ui_close")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed() or event.is_echo():
		return
	if current:
		if current._panel_input(event):
			get_viewport().set_input_as_handled()
			return
		for action in HOTKEYS.keys():
			if event.is_action_pressed(action) and (HOTKEYS[action] == _name_of(current) or action == "menu") and current.closable:
				current.close()
				get_viewport().set_input_as_handled()
				return
		return
	if Main.instance == null or Main.instance.mode != Main.Mode.PLAYING or Main.instance.transitioning:
		return
	for action in HOTKEYS.keys():
		if event.is_action_pressed(action):
			if action == "debug" and not Settings.debug_enabled:
				return
			_open(HOTKEYS[action], {})
			get_viewport().set_input_as_handled()
			return


func _name_of(panel: UIPanel) -> String:
	for k in panels.keys():
		if panels[k] == panel:
			return k
	return ""
