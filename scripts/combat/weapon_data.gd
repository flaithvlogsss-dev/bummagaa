class_name WeaponData
extends ItemData
## Weapon definition. Firearms are loud and ammo is rare; melee weapons are quiet and short.

@export_group("Weapon")
@export var damage: float = 20.0
@export var weapon_range: float = 16.0
## Shots (or swings) per second.
@export var fire_rate: float = 2.0
## "" for melee weapons.
@export var ammo_type: String = ""
@export var magazine_size: int = 0
## 0..1, radius of the noise event is noise * Stealth.NOISE_RADIUS.
@export var noise: float = 1.0
## Condition lost per use.
@export var durability_per_shot: float = 1.5
## Spread in degrees (accuracy); multiplied by stress and condition.
@export var spread: float = 6.0
## Camera kick per shot.
@export var recoil: float = 0.3
@export var reload_time: float = 1.4
## Projectiles per shot (shotgun).
@export var pellets: int = 1
@export var melee: bool = false


func is_firearm() -> bool:
	return not melee and not ammo_type.is_empty()
