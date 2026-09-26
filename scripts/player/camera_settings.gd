class_name CameraSettings
extends Resource
## Central camera configuration (res://data/config/camera_settings.tres).
## Every camera value lives here instead of being hard-coded in scripts.

@export_range(-89.0, -10.0) var pitch_degrees: float = -52.0
@export_range(-180.0, 180.0) var yaw_degrees: float = 0.0
@export var distance: float = 17.0
## Extra distance when outdoors/sprinting ("slightly pulls back when needed").
@export var outdoor_extra_distance: float = 2.5
@export var sprint_extra_distance: float = 1.5
@export var interior_distance: float = 12.0
@export_range(10.0, 90.0) var fov: float = 38.0
@export var follow_smoothing: float = 6.0
@export var zoom_smoothing: float = 3.0
@export var look_ahead: float = 1.2
@export var min_zoom: float = 0.7
@export var max_zoom: float = 1.4
@export var collision_margin: float = 0.3
@export var shake_max_offset: float = 0.35
@export var shake_decay: float = 1.6
