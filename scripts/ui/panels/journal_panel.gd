class_name JournalPanel
extends UIPanel
## JournalPanel (Q) — quests, collected information (notes, documents, photos, radio) and
## people met. Relationships are shown as words, never numbers.

var _tabs: TabContainer
var _quests: RichTextLabel
var _info_list: ItemList
var _info_text: Label
var _people: RichTextLabel


func _build() -> void:
	add_backdrop()
	var p := UIKit.centered(self, Vector2(820, 500))
	var col := UIKit.vbox(8)
	p.add_child(col)
	var head := UIKit.hbox(8)
	col.add_child(head)
	var t := UIKit.title("ЖУРНАЛ")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Закрыть [Q]", close))
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(790, 420)
	col.add_child(_tabs)
	var qs := ScrollContainer.new()
	qs.name = "Задания"
	_tabs.add_child(qs)
	_quests = UIKit.rich("", 15)
	_quests.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qs.add_child(_quests)
	var info := UIKit.hbox(10)
	info.name = "Записи"
	_tabs.add_child(info)
	_info_list = ItemList.new()
	_info_list.custom_minimum_size = Vector2(260, 360)
	_info_list.item_selected.connect(_on_info_selected)
	info.add_child(_info_list)
	var info_scroll := ScrollContainer.new()
	info_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(info_scroll)
	_info_text = UIKit.label("", 14)
	_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_text.custom_minimum_size.x = 480
	info_scroll.add_child(_info_text)
	var ps := ScrollContainer.new()
	ps.name = "Люди"
	_tabs.add_child(ps)
	_people = UIKit.rich("", 14)
	_people.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ps.add_child(_people)


func _on_open(_data: Dictionary) -> void:
	_fill_quests()
	_fill_info()
	_fill_people()


func _fill_quests() -> void:
	var s := ""
	for id in QuestManager.get_active_quests():
		var q := Data.get_quest(id)
		s += "[color=#ffb35a][b]%s[/b][/color]\n[color=#9aa3ae]%s[/color]\n" % [q.get("title", id), GameState.format_text(str(QuestManager.get_current_stage(id).get("description", q.get("description", ""))))]
		for o in QuestManager.get_objectives(id):
			s += ("  [color=#8fe39a]✓ %s[/color]\n" if o.done else "  • %s\n") % o.text
		s += "\n"
	var finished := QuestManager.get_finished_quests()
	if not finished.is_empty():
		s += "[color=#9aa3ae]— Завершённые —[/color]\n"
		for id in finished:
			var q := Data.get_quest(id)
			s += "[color=#7d858f]%s  (%s)[/color]\n" % [q.get("title", id), "выполнено" if QuestManager.is_completed(id) else "провалено"]
	_quests.text = s if not s.is_empty() else "Пока нет заданий."


func _fill_info() -> void:
	_info_list.clear()
	var type_names := {"note": "Записка", "document": "Документ", "photo": "Фото", "radio": "Радио"}
	for id in GameState.discovered_information:
		var info := Data.get_information(id)
		if info == null:
			continue
		var idx := _info_list.add_item("[%s] %s" % [type_names.get(info.info_type, "?"), info.title])
		_info_list.set_item_metadata(idx, id)
	_info_text.text = "Выберите запись." if _info_list.item_count > 0 else "Вы пока ничего не нашли."


func _on_info_selected(index: int) -> void:
	var info := Data.get_information(str(_info_list.get_item_metadata(index)))
	if info:
		_info_text.text = "%s\n\n%s" % [info.title, GameState.format_text(info.content)]


func _fill_people() -> void:
	var s := ""
	for id in GameState.npcs.all_ids():
		var st := GameState.npcs.get_state(id)
		if not st.get("met", false):
			continue
		var c := Data.get_character(id)
		if c == null:
			continue
		var where := "мёртв(а)" if not st.get("alive", true) else ("в убежище" if st.get("location") == "shelter" else "в квартале")
		s += "[color=#ffb35a][b]%s[/b][/color], %d — %s   [color=#9aa3ae](%s • %s)[/color]\n" % [c.display_name, c.age, c.occupation, GameState.relationships.get_tier_name(id), where]
		s += "[i]«%s»[/i]\n%s\n[color=#9aa3ae]Нужно: %s[/color]\n\n" % [c.unique_line, c.bio, c.personal_need]
	_people.text = s if not s.is_empty() else "Вы пока ни с кем не встретились."
