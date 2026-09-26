class_name PlayerCombat
extends Node3D
## PlayerCombat — aiming, firing, melee and reloading the equipped weapon.
##
## Purpose: firearms: hold RMB to aim at the cursor, LMB to fire, R to reload. Shots are
##   hitscan (shotguns fire several pellets), loud (noise event), kick the camera and wear the
##   weapon. Melee weapons: LMB swings at the cursor direction, quietly, in a short arc.
##   The magazine and the wear live on the weapon's own inventory stack ("data.mag", "cond"),
##   so every weapon keeps its state when swapped or stored.
## Dependencies: GameState (inventory, stats), WeaponData, Stealth, AudioManager.
## Signals: fired, reloaded, ammo_changed

signal fired
signal reloaded
signal ammo_changed

const MELEE_ARC_DEG := 70.0

var aiming: bool = false
var aim_direction: Vector2 = Vector2(0, 1)
var reloading: bool = false

var _cooldown: float = 0.0
var _player: CharacterBody3D
var _muzzle: OmniLight3D
var _aim_line: MeshInstance3D


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	_muzzle = OmniLight3D.new()
	_muzzle.light_color = Color(1.0, 0.8, 0.45)
	_muzzle.omni_range = 9.0
	_muzzle.light_energy = 0.0
	_muzzle.position = Vector3(0, 1.1, 0)
	add_child(_muzzle)
	_aim_line = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.03, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.4, 0.3, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = mat
	_aim_line.mesh = box
	_aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_line.visible = false
	add_child(_aim_line)


func get_weapon() -> WeaponData:
	return GameState.inventory.get_equipped_item("weapon") as WeaponData


func _stack() -> Dictionary:
	return GameState.inventory.get_equipped_stack("weapon")


## Rounds loaded in the equipped firearm.
func get_magazine() -> int:
	var s := _stack()
	return int(s.get("data", {}).get("mag", 0)) if not s.is_empty() else 0


func _set_magazine(n: int) -> void:
	var s := _stack()
	if s.is_empty():
		return
	if not s.has("data"):
		s["data"] = {}
	s.data["mag"] = n
	ammo_changed.emit()


func get_condition() -> float:
	return float(_stack().get("cond", 100.0))


func process_combat(delta: float, input_enabled: bool) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_muzzle.light_energy = move_toward(_muzzle.light_energy, 0.0, delta * 40.0)
	var weapon := get_weapon()
	if weapon == null and input_enabled and Input.is_action_just_pressed("aim"):
		weapon = _auto_equip()
	if input_enabled and Input.is_action_just_pressed("swap_weapon"):
		if GameState.inventory.swap_weapons():
			AudioManager.play_sfx("equip")
			weapon = get_weapon()
	if weapon == null:
		aiming = false
		_aim_line.visible = false
		return
	if weapon.melee:
		aiming = input_enabled and Input.is_action_pressed("aim")
		_aim_line.visible = false
		if input_enabled and Input.is_action_just_pressed("fire"):
			_update_aim_direction()
			swing()
		return
	aiming = input_enabled and Input.is_action_pressed("aim") and not reloading
	_aim_line.visible = aiming
	if aiming:
		_update_aim(weapon)
		if Input.is_action_just_pressed("fire"):
			fire()
	if input_enabled and Input.is_action_just_pressed("reload"):
		reload()


## RMB with empty hands draws the first weapon from the backpack.
func _auto_equip() -> WeaponData:
	for s in GameState.inventory.get_slots():
		if s.is_empty():
			continue
		var item := Data.get_item(s.id)
		if item is WeaponData:
			GameState.inventory.equip(item.id)
			AudioManager.play_sfx("equip")
			return get_weapon()
	return null


func _update_aim_direction() -> void:
	var target: Variant = Main.get_mouse_world_point(1.0)
	if target is Vector3:
		var to: Vector3 = target - _player.global_position
		to.y = 0.0
		if to.length() > 0.2:
			aim_direction = Vector2(to.x, to.z).normalized()


func _update_aim(weapon: WeaponData) -> void:
	_update_aim_direction()
	var len := weapon.weapon_range
	_aim_line.position = Vector3(aim_direction.x, 0, aim_direction.y) * len * 0.5 + Vector3(0, 1.0, 0)
	_aim_line.scale = Vector3(1, 1, len)
	_aim_line.rotation = Vector3(0, atan2(aim_direction.x, aim_direction.y), 0)


func _wear(weapon: WeaponData) -> void:
	if GameState.inventory.damage_equipped("weapon", weapon.durability_per_shot):
		GameState.notify("%s сломалось." % weapon.name if weapon.melee else "%s заклинило — нужен ремонт." % weapon.name, "warning")


func fire() -> void:
	var weapon := get_weapon()
	if weapon == null or weapon.melee or _cooldown > 0.0 or reloading:
		return
	var mag := get_magazine()
	if mag <= 0:
		AudioManager.play_sfx("empty_click")
		GameState.notify("Пусто — [R] перезарядить.", "warning")
		_cooldown = 0.3
		return
	if get_condition() <= 0.0:
		AudioManager.play_sfx("empty_click")
		GameState.notify("%s заклинило. Нужен ремкомплект." % weapon.name, "warning")
		_cooldown = 0.5
		return
	_cooldown = 1.0 / maxf(weapon.fire_rate, 0.1)
	_set_magazine(mag - 1)
	_wear(weapon)
	var s := GameState.stats
	# Worn weapons and a shaking hand are less accurate.
	var wear_mult := 1.0 + (1.0 - get_condition() / 100.0) * 0.8
	var spread_deg := weapon.spread * (0.3 + s.stress / 100.0 * 0.7) * wear_mult
	var from := _player.global_position + Vector3(0, 1.1, 0)
	var space := _player.get_world_3d().direct_space_state
	for i in maxi(1, weapon.pellets):
		var ang := atan2(aim_direction.x, aim_direction.y) + deg_to_rad(randf_range(-spread_deg, spread_deg))
		var dir := Vector3(sin(ang), 0, cos(ang))
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * weapon.weapon_range, 1 | 8)
		query.exclude = [_player.get_rid()]
		var hit := space.intersect_ray(query)
		if hit and hit.collider and hit.collider.has_method("take_damage"):
			hit.collider.take_damage(weapon.damage, dir)
	_muzzle.light_energy = 6.0
	AudioManager.play_sfx("gunshot", null, 2.0 if weapon.pellets > 1 else 0.0, randf_range(0.92, 1.05) * (0.8 if weapon.weapon_range > 20.0 else 1.0))
	GameState.present("shake", {"amount": 0.15 + weapon.recoil * 0.35})
	GameState.present("flash", {"amount": 0.12})
	Stealth.emit_noise(get_tree(), _player.global_position, weapon.noise * 1.4)
	GameState.stats.modify("stress", 3.0)
	fired.emit()


func swing() -> void:
	var weapon := get_weapon()
	if weapon == null or not weapon.melee or _cooldown > 0.0:
		return
	var s := GameState.stats
	if s.stamina < 6.0:
		GameState.notify("Нет сил замахнуться.", "warning")
		_cooldown = 0.4
		return
	_cooldown = 1.0 / maxf(weapon.fire_rate, 0.1)
	s.modify("stamina", -6.0)
	var broken := get_condition() <= 0.0
	var damage := weapon.damage * (0.4 if broken else 1.0)
	var origin := _player.global_position
	var facing := Vector3(aim_direction.x, 0, aim_direction.y)
	var hit_any := false
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node3D) or not enemy.has_method("take_damage"):
			continue
		var to: Vector3 = enemy.global_position - origin
		to.y = 0.0
		if to.length() > weapon.weapon_range + 0.4:
			continue
		if to.length() > 0.3 and rad_to_deg(facing.angle_to(to.normalized())) > MELEE_ARC_DEG:
			continue
		enemy.take_damage(damage, to.normalized())
		hit_any = true
	AudioManager.play_sfx("melee_hit" if hit_any else "melee_swing", null, 0.0, randf_range(0.9, 1.1))
	if hit_any:
		_wear(weapon)
		GameState.present("shake", {"amount": 0.12})
	Stealth.emit_noise(get_tree(), origin, weapon.noise)
	fired.emit()


func reload() -> void:
	var weapon := get_weapon()
	if weapon == null or not weapon.is_firearm() or reloading:
		return
	var need := weapon.magazine_size - get_magazine()
	if need <= 0:
		return
	if GameState.inventory.count(weapon.ammo_type) <= 0:
		GameState.notify("Нет патронов: %s." % Data.get_item_name(weapon.ammo_type), "warning")
		return
	reloading = true
	var stack := _stack()
	AudioManager.play_sfx("reload")
	await get_tree().create_timer(weapon.reload_time, false).timeout
	reloading = false
	# The weapon may have been swapped or dropped while reloading.
	if _stack() != stack or get_weapon() != weapon:
		return
	var n := mini(need, GameState.inventory.count(weapon.ammo_type))
	if n > 0 and GameState.inventory.remove(weapon.ammo_type, n):
		_set_magazine(get_magazine() + n)
	reloaded.emit()
