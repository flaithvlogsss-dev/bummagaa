class_name UIPanel
extends Control
## UIPanel — base for full-screen modal panels (inventory, crafting, radio, menus...).
##
## Purpose: consistent open/close behaviour. Modal panels pause the world while open.
## Override: _build() once, _on_open(data), _on_close(), _panel_input(event) -> bool

signal closed

@export var pauses_game: bool = true
## Esc closes the panel (menus like death/ending/title set this false).
@export var closable: bool = true

var is_open: bool = false
var open_data: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	pass


func open(data: Dictionary = {}) -> void:
	open_data = data
	is_open = true
	visible = true
	_on_open(data)


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_on_close()
	closed.emit()


func _on_open(_data: Dictionary) -> void:
	pass


func _on_close() -> void:
	pass


## Return true when the panel consumed the event.
func _panel_input(_event: InputEvent) -> bool:
	return false


## Dimmed full-screen backdrop.
func add_backdrop(alpha: float = 0.55) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.01, 0.02, alpha)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	return bg
