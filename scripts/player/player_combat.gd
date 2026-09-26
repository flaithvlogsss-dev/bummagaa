class_name PlayerCombat
extends Node3D
## PlayerCombat — aiming, firing and reloading the equipped weapon.
##
## Purpose: hold RMB to aim at the mouse cursor, LMB to fire, R to reload. Shots are hitscan,
##   loud (noise event), shake the camera and flash. Ammo is rare; the pistol is weak.
## Dependencies: GameState (inventory, stats), WeaponData, Stealth, AudioManager.
## Signals: fired, reloaded, ammo_changed

signal fired
signal reloaded
signal ammo_changed

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
	var id := GameState.inventory.get_equipped("hand")
	return Data.get_item(id) as WeaponData if not id.is_empty() else null


func process_combat(delta: float, input_enabled: bool) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_muzzle.light_energy = move_toward(_muzzle.light_energy, 0.0, delta * 40.0)
	var weapon := get_weapon()
	if weapon == null and input_enabled and Input.is_action_just_pressed("aim") and GameState.inventory.has_item("pistol"):
		GameState.inventory.equip("pistol")
		weapon = get_weapon()
	aiming = input_enabled and weapon != null and Input.is_action_pressed("aim") and not reloading
	_aim_line.visible = aiming
	if aiming:
		_update_aim(weapon)
		if Input.is_action_just_pressed("fire"):
			fire()
	if input_enabled and weapon != null and Input.is_action_just_pressed("reload"):
		reload()


func _update_aim(weapon: WeaponData) -> void:
	var target: Variant = Main.get_mouse_world_point(1.0)
	if target is Vector3:
		var to: Vector3 = target - _player.global_position
		to.y = 0.0
		if to.length() > 0.2:
			aim_direction = Vector2(to.x, to.z).normalized()
	var len := weapon.weapon_range
	_aim_line.position = Vector3(aim_direction.x, 0, aim_direction.y) * len * 0.5 + Vector3(0, 1.0, 0)
	_aim_line.scale = Vector3(1, 1, len)
	_aim_line.rotation = Vector3(0, atan2(aim_direction.x, aim_direction.y), 0)


func fire() -> void:
	var weapon := get_weapon()
	if weapon == null or _cooldown > 0.0 or reloading:
		return
	var s := GameState.stats
	if s.magazine <= 0:
		AudioManager.play_sfx("empty_click")
		GameState.notify("Магазин пуст — [R] перезарядить.", "warning")
		_cooldown = 0.3
		return
	if s.weapon_durability <= 0.0:
		AudioManager.play_sfx("empty_click")
		GameState.notify("Пистолет заклинило. Нужен ремкомплект.", "warning")
		return
	_cooldown = 1.0 / maxf(weapon.fire_rate, 0.1)
	s.magazine -= 1
	s.weapon_durability = maxf(0.0, s.weapon_durability - weapon.durability_per_shot)
	ammo_changed.emit()
	var spread_deg := weapon.spread * (0.3 + s.stress / 100.0 * 0.7)
	var ang := atan2(aim_direction.x, aim_direction.y) + deg_to_rad(randf_range(-spread_deg, spread_deg))
	var dir := Vector3(sin(ang), 0, cos(ang))
	var from := _player.global_position + Vector3(0, 1.1, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * weapon.weapon_range, 1 | 8)
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(weapon.damage, dir)
	_muzzle.light_energy = 6.0
	AudioManager.play_sfx("gunshot", null, 0.0, randf_range(0.92, 1.05))
	GameState.present("shake", {"amount": 0.3})
	GameState.present("flash", {"amount": 0.12})
	Stealth.emit_noise(get_tree(), _player.global_position, weapon.noise * 1.4)
	GameState.stats.modify("stress", 3.0)
	fired.emit()


func reload() -> void:
	var weapon := get_weapon()
	if weapon == null or reloading:
		return
	var s := GameState.stats
	var need := weapon.magazine_size - s.magazine
	var have := GameState.inventory.count(weapon.ammo_type)
	if need <= 0:
		return
	if have <= 0:
		GameState.notify("Нет патронов.", "warning")
		return
	reloading = true
	AudioManager.play_sfx("reload")
	await get_tree().create_timer(weapon.reload_time, false).timeout
	var n := mini(need, GameState.inventory.count(weapon.ammo_type))
	if n > 0 and GameState.inventory.remove(weapon.ammo_type, n):
		s.magazine += n
	reloading = false
	ammo_changed.emit()
	reloaded.emit()
