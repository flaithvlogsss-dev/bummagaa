class_name WeaponData
extends ItemData
## Weapon definition. The pistol is intentionally weak and ammo is rare.

@export_group("Weapon")
@export var damage: float = 20.0
@export var weapon_range: float = 16.0
## Shots per second.
@export var fire_rate: float = 2.0
@export var ammo_type: String = "pistol_ammo"
@export var magazine_size: int = 6
## 0..1, radius of the noise event is noise * 30 m.
@export var noise: float = 1.0
@export var durability: float = 100.0
@export var durability_per_shot: float = 1.5
## Spread in degrees at full stress.
@export var spread: float = 6.0
@export var reload_time: float = 1.4
