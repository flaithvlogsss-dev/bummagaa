extends Node
## Runs every tests/unit/test_*.gd and quits with the number of failures as exit code.
## Usage: godot --headless --path . res://tests/TestRunner.tscn

const UNIT_DIR := "res://tests/unit"


func _ready() -> void:
	await get_tree().process_frame
	var total := 0
	var failed: PackedStringArray = PackedStringArray()
	var files := DirAccess.get_files_at(UNIT_DIR)
	var only := OS.get_environment("TEST_FILTER")
	for f in files:
		f = f.trim_suffix(".remap")
		if not f.ends_with(".gd") or not f.begins_with("test_"):
			continue
		if not only.is_empty() and not f.contains(only):
			continue
		var script: GDScript = load(UNIT_DIR.path_join(f))
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			var tc: TestCase = script.new()
			tc.tree = get_tree()
			tc.current_test = "%s::%s" % [f.get_basename(), name]
			tc.before_each()
			await tc.call(name)
			tc.after_each()
			total += 1
			if tc.failures.is_empty():
				print("  PASS ", tc.current_test)
			else:
				for msg in tc.failures:
					print("  FAIL ", msg)
					failed.append(msg)
	print("\n==== TESTS: %d run, %d failed ====" % [total, failed.size()])
	AudioManager.shutdown()
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit(failed.size())
