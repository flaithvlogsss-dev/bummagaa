class_name EndingScreen
extends UIPanel
## EndingScreen — shows the reached prototype ending plus epilogue lines that reflect the
## player's choices (who survived, what they learned). Conditions are never shown.

var _title: Label
var _subtitle: Label
var _text: Label
var _epilogue: Label


func _init() -> void:
	closable = false


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.03, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := UIKit.vbox(10)
	col.custom_minimum_size.x = 720
	center.add_child(col)
	_title = UIKit.label("", 40, Color(0.92, 0.95, 1.0))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_subtitle = UIKit.label("", 16, UIKit.ACCENT)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_subtitle)
	col.add_child(UIKit.spacer(8))
	_text = UIKit.label("", 16)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 700
	col.add_child(_text)
	_epilogue = UIKit.label("", 14, UIKit.TEXT_DIM)
	_epilogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_epilogue.custom_minimum_size.x = 700
	col.add_child(_epilogue)
	col.add_child(UIKit.spacer(10))
	var foot := UIKit.label("Конец прототипа. Спасибо, что пережили эти дни.", 13, UIKit.TEXT_DIM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)
	col.add_child(UIKit.button("В главное меню", func(): Main.instance.return_to_title()))


func _on_open(data: Dictionary) -> void:
	var e := EndingDirector.get_ending(str(data.get("ending", "")))
	_title.text = "ENDING: %s" % str(e.get("title", "?"))
	_subtitle.text = str(e.get("subtitle", ""))
	_text.text = GameState.format_text(str(e.get("text", "")))
	_epilogue.text = "\n".join(EndingDirector.epilogue_lines())
	UIRoot.fade_in(1.5)
