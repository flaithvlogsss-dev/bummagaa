class_name ScreenEffects
extends CanvasLayer
## ScreenEffects — full-screen overlay for cold frost, low-health pulse, stress tunnel,
## snow on the lens during blizzards and short flashes. Kept subtle so it never hides gameplay.

var _rect: ColorRect
var _mat: ShaderMaterial
var _flash: float = 0.0
var _hurt_flash: float = 0.0
var _values: Dictionary = {"cold": 0.0, "hurt": 0.0, "stress": 0.0, "lens_snow": 0.0}


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/screen_effects.gdshader")
	_rect.material = _mat
	add_child(_rect)
	GameState.presentation_requested.connect(_on_presentation)


func _on_presentation(kind: String, data: Dictionary) -> void:
	if kind == "flash":
		_flash = maxf(_flash, float(data.get("amount", 0.2)))
	elif kind == "hurt":
		_hurt_flash = 1.0


func _process(delta: float) -> void:
	var playing := Main.instance != null and Main.instance.mode == Main.Mode.PLAYING
	_rect.visible = playing
	if not playing:
		return
	var s := GameState.stats
	var player := Main.get_player()
	var outdoors := player != null and not player.survival.is_indoors()
	var target := {
		"cold": clampf((40.0 - s.temperature) / 40.0, 0.0, 1.0),
		"hurt": clampf((35.0 - s.health) / 35.0, 0.0, 1.0) * 0.8 + _hurt_flash * 0.5,
		"stress": clampf((s.stress - 60.0) / 40.0, 0.0, 1.0),
		"lens_snow": clampf((WeatherManager.intensity - 0.45) / 0.55, 0.0, 1.0) if outdoors else 0.0,
	}
	for k in target.keys():
		_values[k] = move_toward(_values[k], target[k], delta * 1.5)
		_mat.set_shader_parameter(k, _values[k])
	_hurt_flash = move_toward(_hurt_flash, 0.0, delta * 2.0)
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	_mat.set_shader_parameter("flash", _flash)
	_mat.set_shader_parameter("time_offset", Time.get_ticks_msec() / 1000.0)
