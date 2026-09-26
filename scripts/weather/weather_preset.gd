class_name WeatherPreset
extends Resource
## Parameters for one weather state (CLEAR / LIGHT / HEAVY / BLIZZARD / WHITEOUT).
## WeatherManager blends between presets over time.

@export var id: String = "LIGHT"
@export var display_name: String = "Слабый снег"
## 0..1 snowfall density (drives particles).
@export var intensity: float = 0.2
## 0..1 wind strength.
@export var wind: float = 0.1
## Approximate visibility distance in metres.
@export var visibility: float = 60.0
## Outside air temperature in °C (shown in HUD).
@export var temperature: float = -8.0
## Multiplier for body heat loss outdoors.
@export var cold_rate: float = 1.0
## Multiplier for sprint stamina cost outdoors.
@export var stamina_cost: float = 1.0
## Footprints fade speed multiplier.
@export var footprint_fade: float = 1.0
## 0..1 how much the storm masks sounds (enemies hear less).
@export var noise_mask: float = 0.0
## Stress per minute outdoors.
@export var stress_rate: float = 0.0
## Multiplier for how fast outside air contaminates an unprotected player.
@export var contamination: float = 1.0
## Game minutes of filter used per game minute outdoors.
@export var filter_drain: float = 0.4
## 0..1 extra fog / white-out of the screen (WHITEOUT).
@export var whiteout: float = 0.0
## True when outdoor NPCs seek cover and exposed routes close.
@export var severe: bool = false
