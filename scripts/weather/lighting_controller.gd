class_name LightingController
extends Node
## LightingController — day/night + weather lighting for an outdoor level.
##
## Purpose: day light-grey, evening dusk, night cold and dark, blizzard white-out with low
##   visibility (the distant skyline disappears into fog). Also applies the brightness setting.
## Needs: a WorldEnvironment and a DirectionalLight3D (paths below).

@export var environment_path: NodePath
@export var sun_path: NodePath
@export var outdoor: bool = true

var _env: Environment
var _sun: DirectionalLight3D

# [hour, sun energy, sun colour, ambient colour, sky/fog colour]
const KEYS := [
	[0.0, 0.22, Color(0.55, 0.65, 1.0), Color(0.12, 0.14, 0.24), Color(0.05, 0.06, 0.1)],
	[5.5, 0.22, Color(0.55, 0.65, 1.0), Color(0.13, 0.15, 0.25), Color(0.06, 0.07, 0.11)],
	[7.5, 0.45, Color(1.0, 0.8, 0.7), Color(0.3, 0.32, 0.4), Color(0.4, 0.42, 0.5)],
	[10.0, 0.8, Color(0.92, 0.94, 1.0), Color(0.5, 0.54, 0.62), Color(0.62, 0.66, 0.72)],
	[15.0, 0.75, Color(0.92, 0.94, 1.0), Color(0.48, 0.52, 0.6), Color(0.6, 0.63, 0.7)],
	[17.5, 0.4, Color(1.0, 0.72, 0.55), Color(0.3, 0.3, 0.4), Color(0.38, 0.34, 0.42)],
	[19.5, 0.25, Color(0.7, 0.65, 0.9), Color(0.17, 0.18, 0.28), Color(0.12, 0.12, 0.2)],
	[21.0, 0.22, Color(0.55, 0.65, 1.0), Color(0.13, 0.15, 0.25), Color(0.06, 0.07, 0.11)],
	[24.0, 0.22, Color(0.55, 0.65, 1.0), Color(0.12, 0.14, 0.24), Color(0.05, 0.06, 0.1)],
]


func _ready() -> void:
	var we := get_node_or_null(environment_path) as WorldEnvironment
	_env = we.environment if we else null
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_apply()


func _process(_delta: float) -> void:
	_apply()


func _apply() -> void:
	if _env == null:
		return
	_env.adjustment_enabled = true
	_env.adjustment_brightness = Settings.brightness
	if not outdoor:
		return
	var h := TimeManager.day_fraction() * 24.0
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in KEYS.size() - 1:
		if h >= KEYS[i][0] and h <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t: float = 0.0 if b[0] == a[0] else (h - float(a[0])) / (float(b[0]) - float(a[0]))
	var sun_e: float = lerpf(a[1], b[1], t)
	var sun_c: Color = (a[2] as Color).lerp(b[2], t)
	var amb: Color = (a[3] as Color).lerp(b[3], t)
	var sky: Color = (a[4] as Color).lerp(b[4], t)
	var white := WeatherManager.get_whiteout()
	var storm := clampf(WeatherManager.intensity, 0.0, 1.0)
	sun_e *= 1.0 - storm * 0.55
	var fog_col := sky.lerp(Color(0.75, 0.78, 0.84) * (0.35 + sun_e), white * 0.7)
	amb = amb.lerp(fog_col, white * 0.4)
	if _sun:
		_sun.light_energy = sun_e
		_sun.light_color = sun_c
	_env.background_color = fog_col
	_env.ambient_light_color = amb
	_env.ambient_light_energy = 1.0
	_env.fog_light_color = fog_col
	_env.fog_density = clampf(1.25 / maxf(WeatherManager.visibility, 5.0), 0.004, 0.2)
	_env.volumetric_fog_density = 0.004 + white * 0.03
