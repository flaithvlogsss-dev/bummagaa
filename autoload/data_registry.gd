extends Node
## Data — read-only registry of all game content.
##
## Purpose: loads every content record from res://data/ once and offers lookup by id.
##   Flat records are Godot Resources (.tres, editable in the Inspector):
##     items, recipes, characters, information, weather presets.
##   Graph/scripted records are JSON (conditions + consequences inside):
##     dialogues, quests, events, radio signals, world tables (days, upgrades, endings).
## Dependencies: none (must be the first autoload).
## Public API: get_item(), get_recipe(), get_character(), get_information(), get_weather_preset(),
##   get_quest(), get_dialogue(), get_event(), get_radio_signal(), get_world_table(), has_item(), reload()
## Signals: data_reloaded
## Save Data: none (static content).

signal data_reloaded

const DIR_ITEMS := "res://data/items"
const DIR_RECIPES := "res://data/recipes"
const DIR_CHARACTERS := "res://data/characters"
const DIR_INFORMATION := "res://data/information"
const DIR_WEATHER := "res://data/weather"
const DIR_QUESTS := "res://data/quests"
const DIR_DIALOGUES := "res://data/dialogues"
const DIR_EVENTS := "res://data/events"
const DIR_RADIO := "res://data/radio"
const DIR_WORLD := "res://data/world"

var items: Dictionary = {}
var recipes: Dictionary = {}
var characters: Dictionary = {}
var information: Dictionary = {}
var weather_presets: Dictionary = {}
var quests: Dictionary = {}
var dialogues: Dictionary = {}
var events: Dictionary = {}
var radio_signals: Dictionary = {}
var world_tables: Dictionary = {}

var _warned: Dictionary = {}


func _ready() -> void:
	reload()


func _exit_tree() -> void:
	# Handlers are lambdas bound to autoloads; release them before those are freed.
	Conditions.clear_handlers()
	Consequences.clear_handlers()
	MeshBuilder.clear_cache()
	LowPolyBlock.clear_materials()
	PixelArt.clear_cache()


func reload() -> void:
	items = _load_resources(DIR_ITEMS)
	recipes = _load_resources(DIR_RECIPES)
	characters = _load_resources(DIR_CHARACTERS)
	information = _load_resources(DIR_INFORMATION)
	weather_presets = _load_resources(DIR_WEATHER)
	quests = _load_json_records(DIR_QUESTS)
	dialogues = _load_json_records(DIR_DIALOGUES)
	events = _load_json_records(DIR_EVENTS)
	radio_signals = _load_json_records(DIR_RADIO)
	world_tables = {}
	for path in _list_files(DIR_WORLD, ["json"]):
		world_tables[path.get_file().get_basename()] = load_json(path)
	data_reloaded.emit()


# --- Lookups -----------------------------------------------------------------

func get_item(id: String) -> ItemData:
	return _lookup(items, id, "item") as ItemData


func has_item(id: String) -> bool:
	return items.has(id)


func get_item_name(id: String) -> String:
	var item := get_item(id)
	return item.name if item else id


func get_recipe(id: String) -> RecipeData:
	return _lookup(recipes, id, "recipe") as RecipeData


func get_character(id: String) -> CharacterData:
	return _lookup(characters, id, "character") as CharacterData


func get_character_name(id: String) -> String:
	var c := get_character(id)
	return c.display_name if c else id


func get_information(id: String) -> InformationData:
	return _lookup(information, id, "information") as InformationData


func get_weather_preset(id: String) -> WeatherPreset:
	return _lookup(weather_presets, id, "weather preset") as WeatherPreset


func get_quest(id: String) -> Dictionary:
	var q = _lookup(quests, id, "quest")
	return q if q is Dictionary else {}


func get_dialogue(id: String) -> Dictionary:
	var d = _lookup(dialogues, id, "dialogue")
	return d if d is Dictionary else {}


func get_event(id: String) -> Dictionary:
	var e = _lookup(events, id, "event")
	return e if e is Dictionary else {}


func get_radio_signal(id: String) -> Dictionary:
	var s = _lookup(radio_signals, id, "radio signal")
	return s if s is Dictionary else {}


## World tables are whole JSON documents from data/world (days.json -> "days").
func get_world_table(table_name: String) -> Variant:
	return world_tables.get(table_name, {})


# --- Loading -------------------------------------------------------------------

static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Data: cannot open %s" % path)
		return null
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Data: JSON error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Lists files in a folder, tolerating exported builds (.remap) and imports.
static func _list_files(dir_path: String, extensions: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file_name in dir.get_files():
		var clean := file_name.trim_suffix(".remap")
		if clean.get_extension() in extensions and not out.has(dir_path.path_join(clean)):
			out.append(dir_path.path_join(clean))
	out.sort()
	return out


func _load_resources(dir_path: String) -> Dictionary:
	var result := {}
	for path in _list_files(dir_path, ["tres", "res"]):
		var res := load(path)
		if res == null or not ("id" in res):
			push_warning("Data: %s is not a content resource" % path)
			continue
		var id: String = res.get("id")
		if id.is_empty():
			id = path.get_file().get_basename()
			res.set("id", id)
		if result.has(id):
			push_warning("Data: duplicate id '%s' in %s" % [id, path])
		result[id] = res
	return result


## A JSON file holds either one record ({"id": ...}) or an array of records.
func _load_json_records(dir_path: String) -> Dictionary:
	var result := {}
	for path in _list_files(dir_path, ["json"]):
		var parsed = load_json(path)
		var records: Array = []
		if parsed is Array:
			records = parsed
		elif parsed is Dictionary:
			records = [parsed]
		for rec in records:
			if not (rec is Dictionary) or not rec.has("id"):
				push_warning("Data: record without id in %s" % path)
				continue
			if result.has(rec.id):
				push_warning("Data: duplicate id '%s' in %s" % [rec.id, path])
			result[rec.id] = rec
	return result


func _lookup(table: Dictionary, id: String, kind: String) -> Variant:
	if table.has(id):
		return table[id]
	var key := kind + ":" + id
	if not _warned.has(key) and not id.is_empty():
		_warned[key] = true
		push_warning("Data: unknown %s '%s'" % [kind, id])
	return null
