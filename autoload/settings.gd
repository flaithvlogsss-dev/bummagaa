extends Node
## Settings — player preferences and accessibility options.
##
## Purpose: volumes per audio bus, text speed, screen shake, brightness, UI scale,
##   pixelation of the 3D view and control remapping. Stored in user://settings.cfg.
## Dependencies: InputBindings.
## Public API: set_volume(), set_option(), save_settings(), load_settings()
## Signals: settings_changed
## Save Data: separate from game saves (ConfigFile).

signal settings_changed

const PATH := "user://settings.cfg"
const BUSES: Array[String] = ["Master", "Music", "Ambient", "SFX", "Dialogue", "Radio"]
const TEXT_SPEEDS := {"slow": 25.0, "normal": 50.0, "fast": 110.0, "instant": 0.0}

var volumes: Dictionary = {"Master": 0.8, "Music": 0.55, "Ambient": 0.8, "SFX": 0.8, "Dialogue": 0.9, "Radio": 0.8}
var text_speed: String = "normal"
var screen_shake: bool = true
var brightness: float = 1.0
var ui_scale: float = 1.0
## 1 = native resolution 3D, 2..4 = chunkier pixel look.
var pixel_scale: int = 2
var debug_enabled: bool = true


func _ready() -> void:
	debug_enabled = OS.is_debug_build()
	load_settings()


func chars_per_second() -> float:
	return float(TEXT_SPEEDS.get(text_speed, 50.0))


func set_volume(bus: String, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	settings_changed.emit()


func set_option(key: String, value: Variant) -> void:
	if not key in self:
		push_warning("Settings: unknown option '%s'" % key)
		return
	set(key, value)
	settings_changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in volumes.keys():
		cfg.set_value("audio", bus, volumes[bus])
	cfg.set_value("game", "text_speed", text_speed)
	cfg.set_value("game", "screen_shake", screen_shake)
	cfg.set_value("video", "brightness", brightness)
	cfg.set_value("video", "ui_scale", ui_scale)
	cfg.set_value("video", "pixel_scale", pixel_scale)
	cfg.set_value("input", "overrides", InputBindings.overrides)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Settings: could not save (%s)" % error_string(err))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var overrides := {}
	if cfg.load(PATH) == OK:
		for bus in BUSES:
			volumes[bus] = clampf(float(cfg.get_value("audio", bus, volumes.get(bus, 0.8))), 0.0, 1.0)
		text_speed = str(cfg.get_value("game", "text_speed", text_speed))
		if not TEXT_SPEEDS.has(text_speed):
			text_speed = "normal"
		screen_shake = bool(cfg.get_value("game", "screen_shake", screen_shake))
		brightness = clampf(float(cfg.get_value("video", "brightness", brightness)), 0.5, 1.6)
		ui_scale = clampf(float(cfg.get_value("video", "ui_scale", ui_scale)), 0.75, 1.5)
		pixel_scale = clampi(int(cfg.get_value("video", "pixel_scale", pixel_scale)), 1, 4)
		var o = cfg.get_value("input", "overrides", {})
		if o is Dictionary:
			overrides = o
	InputBindings.apply(overrides)
	settings_changed.emit()
