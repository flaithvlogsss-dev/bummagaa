class_name DialoguePanel
extends UIPanel
## DialoguePanel — compact bottom dialogue box: speaker, typewriter text, choices.
## Keys: E / Space / Enter / click to continue, 1–9 to pick a choice.

var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _continue: Label
var _portrait: TextureRect
var _full_len: int = 0
var _shown: float = 0.0
var _line: Dictionary = {}


func _init() -> void:
	closable = false


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var anchor := MarginContainer.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	anchor.offset_top = -250
	anchor.add_theme_constant_override("margin_left", 180)
	anchor.add_theme_constant_override("margin_right", 180)
	anchor.add_theme_constant_override("margin_bottom", 24)
	add_child(anchor)
	var p := UIKit.panel()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(_on_panel_click)
	anchor.add_child(p)
	var row := UIKit.hbox(14)
	p.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(72, 84)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_portrait)
	var col := UIKit.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_name = UIKit.label("", 16, UIKit.ACCENT)
	col.add_child(_name)
	_text = UIKit.rich("", 16)
	_text.custom_minimum_size = Vector2(0, 60)
	col.add_child(_text)
	_choices = UIKit.vbox(4)
	col.add_child(_choices)
	_continue = UIKit.label("▼ [E] далее", 12, UIKit.TEXT_DIM)
	_continue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_continue)
	DialogueManager.line_shown.connect(_on_line)


func _on_open(_data: Dictionary) -> void:
	pass


func _on_line(line: Dictionary) -> void:
	_line = line
	_name.text = line.speaker_name
	_name.visible = not str(line.speaker_name).is_empty()
	_text.text = line.text
	_full_len = _text.get_total_character_count()
	_shown = 0.0
	var cps := Settings.chars_per_second()
	_text.visible_characters = -1 if cps <= 0.0 else 0
	_portrait.texture = _portrait_for(str(line.get("portrait", "")))
	_portrait.visible = _portrait.texture != null
	UIKit.clear(_choices)
	var i := 1
	for c in line.choices:
		var b := UIKit.button("%d. %s" % [i, c.text], _choose.bind(i - 1))
		b.disabled = not c.enabled
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_choices.add_child(b)
		i += 1
	_choices.visible = false
	_continue.visible = false
	_update_reveal()


func _portrait_for(npc_id: String) -> Texture2D:
	var data := Data.get_character(npc_id) if not npc_id.is_empty() else null
	if data == null:
		return null
	var sheet := PixelArt.character_sheet(data)
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(0, 0, PixelArt.FRAME_W, 16)
	return at


func _process(delta: float) -> void:
	if not is_open:
		return
	if _text.visible_characters >= 0 and _text.visible_characters < _full_len:
		_shown += delta * Settings.chars_per_second()
		_text.visible_characters = mini(_full_len, int(_shown))
		_update_reveal()


func _update_reveal() -> void:
	var done := _text.visible_characters < 0 or _text.visible_characters >= _full_len
	_choices.visible = done and _choices.get_child_count() > 0
	_continue.visible = done and _choices.get_child_count() == 0
	if _choices.visible and _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()


func _is_typing() -> bool:
	return _text.visible_characters >= 0 and _text.visible_characters < _full_len


func _skip_or_continue() -> void:
	if _is_typing():
		_text.visible_characters = -1
		_update_reveal()
	elif _choices.get_child_count() == 0:
		DialogueManager.advance()


func _choose(index: int) -> void:
	if _is_typing():
		return
	DialogueManager.choose(index)


func _on_panel_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_typing() or _choices.get_child_count() == 0:
			_skip_or_continue()


func _panel_input(event: InputEvent) -> bool:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and event.pressed):
		if _is_typing() or _choices.get_child_count() == 0:
			_skip_or_continue()
			return true
		return false
	if event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		if not _is_typing():
			_choose(event.keycode - KEY_1)
		return true
	return event.is_action_pressed("menu") or event.is_action_pressed("inventory") or event.is_action_pressed("map") or event.is_action_pressed("journal")
