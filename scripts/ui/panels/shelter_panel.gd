class_name ShelterPanel
extends UIPanel
## ShelterPanel — shelter status, survivors living here and the next upgrade.

var _level: Label
var _level_desc: Label
var _next: Label
var _next_desc: Label
var _cost: RichTextLabel
var _hint: Label
var _upgrade: Button
var _people: Label


func _build() -> void:
	add_backdrop()
	var p := UIKit.centered(self, Vector2(640, 440))
	var col := UIKit.vbox(8)
	p.add_child(col)
	var head := UIKit.hbox(8)
	col.add_child(head)
	var t := UIKit.title("УБЕЖИЩЕ")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Закрыть [Esc]", close))
	_level = UIKit.label("", 17)
	col.add_child(_level)
	_level_desc = UIKit.label("", 13, UIKit.TEXT_DIM)
	_level_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_level_desc)
	_people = UIKit.label("", 13)
	_people.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_people)
	col.add_child(UIKit.separator())
	_next = UIKit.label("", 16, UIKit.ACCENT)
	col.add_child(_next)
	_next_desc = UIKit.label("", 13)
	_next_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_desc.custom_minimum_size.x = 600
	col.add_child(_next_desc)
	_cost = UIKit.rich("", 15)
	col.add_child(_cost)
	_hint = UIKit.label("", 13, UIKit.DANGER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)
	_upgrade = UIKit.button("УЛУЧШИТЬ", _do_upgrade, 200)
	col.add_child(_upgrade)


func _on_open(_data: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	var cur := ShelterSystem.level_info(GameState.shelter_level)
	_level.text = "Уровень %d — %s" % [GameState.shelter_level, cur.get("name", "Убежище")]
	_level_desc.text = str(cur.get("description", ""))
	var names: PackedStringArray = []
	for id in GameState.survivors_in_shelter():
		names.append("%s (%s)" % [Data.get_character_name(id), GameState.relationships.get_tier_name(id)])
	_people.text = "Живут здесь: " + (", ".join(names) if not names.is_empty() else "только вы")
	var n := ShelterSystem.next_level()
	if n < 0:
		_next.text = "Убежище улучшено полностью."
		_next_desc.text = ""
		_cost.text = ""
		_hint.text = ""
		_upgrade.visible = false
		return
	_upgrade.visible = true
	var info := ShelterSystem.level_info(n)
	_next.text = "Следующий уровень %d — %s" % [n, info.get("name", "")]
	_next_desc.text = str(info.get("description", ""))
	var lines: PackedStringArray = []
	var cost: Dictionary = info.get("cost", {})
	for id in cost.keys():
		var have := CraftingSystem.available_count(str(id))
		var color := "#8fe39a" if have >= int(cost[id]) else "#ff7a6e"
		lines.append("[color=%s]%s  %d / %d[/color]" % [color, Data.get_item_name(str(id)), have, int(cost[id])])
	_cost.text = "\n".join(lines)
	_hint.text = "" if ShelterSystem.conditions_met(n) else str(info.get("hint", "Чего-то не хватает."))
	_upgrade.disabled = not ShelterSystem.can_upgrade()


func _do_upgrade() -> void:
	if ShelterSystem.upgrade():
		AudioManager.play_ui("craft")
		var info := ShelterSystem.level_info(GameState.shelter_level)
		GameState.present("quest_banner", {"title": "УБЕЖИЩЕ УЛУЧШЕНО", "text": str(info.get("name", ""))})
	_refresh()
