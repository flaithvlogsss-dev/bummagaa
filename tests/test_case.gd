class_name TestCase
extends RefCounted
## Minimal test base. Methods named test_* are run by tests/test_runner.gd.

var failures: PackedStringArray = PackedStringArray()
var current_test: String = ""
## Scene tree access for integration tests.
var tree: SceneTree


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])


func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		fail(msg)


func assert_false(cond: bool, msg: String = "expected false") -> void:
	if cond:
		fail(msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) in [TYPE_FLOAT, TYPE_INT] and typeof(expected) in [TYPE_FLOAT, TYPE_INT]:
		if not is_equal_approx(float(actual), float(expected)):
			fail("%s expected %s got %s" % [msg, expected, actual])
		return
	if actual != expected:
		fail("%s expected %s got %s" % [msg, expected, actual])


func assert_gt(a: float, b: float, msg: String = "") -> void:
	if not a > b:
		fail("%s expected %s > %s" % [msg, a, b])


func assert_lt(a: float, b: float, msg: String = "") -> void:
	if not a < b:
		fail("%s expected %s < %s" % [msg, a, b])


## Resets every global system to a fresh new game.
func fresh_game() -> void:
	DialogueManager.reset()
	GameState.new_game()
	TimeManager.reset()
