extends Node
## Loads every script, scene and resource in the project to surface parse/load errors.
## Usage: godot --headless --path . res://tools/CheckScripts.tscn

var failures := 0


func _ready() -> void:
	_scan("res://")
	print("check_scripts: %d failures" % failures)
	get_tree().quit(failures)


func _scan(dir_path: String) -> void:
	for d in DirAccess.get_directories_at(dir_path):
		if d.begins_with("."):
			continue
		_scan(dir_path.path_join(d))
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			var res := ResourceLoader.load(dir_path.path_join(f), "", ResourceLoader.CACHE_MODE_REUSE)
			if res == null:
				failures += 1
				printerr("FAILED: ", dir_path.path_join(f))
			elif res is GDScript and not res.can_instantiate():
				failures += 1
				printerr("CANNOT INSTANTIATE: ", dir_path.path_join(f))
