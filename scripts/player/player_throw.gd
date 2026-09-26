class_name PlayerThrow
extends Node3D
## PlayerThrow — throwing bottles, stones and flares to distract enemies ([T] or a quick slot).
##
## Purpose: the thrown item flies in an arc to the cursor (at most MAX_RANGE away) and makes
##   a noise where it lands, so enemies investigate there instead of the player:
##   bottle — loud glass (consumed), stone — quiet knock (stays on the ground),
##   flare — burns red for FLARE_TIME seconds and keeps pulsing noise (consumed).
## Dependencies: GameState (inventory, drop_stack), Stealth, AudioManager, Main (mouse point).

const MAX_RANGE := 13.0
const FLARE_TIME := 60.0
## Preferred order when [T] has to pick something.
const PRIORITY := ["empty_bottle", "stone", "flare"]

var _player: Node3D
var _cooldown: float = 0.0


func _ready() -> void:
	_player = get_parent() as Node3D


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


## The throwable [T] uses: a throwable bound to a quick slot first, then PRIORITY.
func pick_throwable() -> String:
	var inv := GameState.inventory
	for i in Inventory.QUICK_SLOTS:
		var id := inv.get_quick(i)
		var item := Data.get_item(id) if not id.is_empty() else null
		if item and item.throwable and inv.count_in_grid(id) > 0:
			return id
	for id in PRIORITY:
		if inv.count_in_grid(id) > 0:
			return id
	for s in inv.get_slots():
		if not s.is_empty():
			var item := Data.get_item(s.id)
			if item and item.throwable:
				return str(s.id)
	return ""


func throw_item(item_id: String = "") -> bool:
	if _cooldown > 0.0 or _player == null:
		return false
	if item_id.is_empty():
		item_id = pick_throwable()
	if item_id.is_empty():
		GameState.notify("Нечего бросить. Подойдут бутылка, камень или фальшфейер.", "warning")
		return false
	var item := Data.get_item(item_id)
	if item == null or not item.throwable or GameState.inventory.count_in_grid(item_id) <= 0:
		return false
	var taken := GameState.inventory.take(item_id, 1)
	if taken.is_empty():
		return false
	_cooldown = 0.8
	var from := _player.global_position + Vector3(0, 1.2, 0)
	var target: Vector3 = _player.global_position + Vector3(0, 0, 4)
	var mouse: Variant = Main.get_mouse_world_point(0.0)
	if mouse is Vector3:
		target = mouse
	var flat := target - _player.global_position
	flat.y = 0.0
	if flat.length() > MAX_RANGE:
		flat = flat.normalized() * MAX_RANGE
	target = _player.global_position + flat
	target.y = 0.05
	var proj := ThrownItem.new()
	proj.stack = taken[0]
	proj.level = _player.get_parent()
	_player.get_parent().add_child(proj)
	proj.launch(from, target)
	AudioManager.play_sfx("throw", _player.global_position, -4.0)
	GameState.stats.modify("stamina", -4.0)
	return true


## The flying object and what happens where it lands.
class ThrownItem:
	extends Node3D

	var stack: Dictionary = {}
	var level: Node

	var _sprite: Sprite3D
	var _light: OmniLight3D
	var _burning: float = 0.0
	var _pulse: float = 0.0
	var _from: Vector3
	var _to: Vector3
	var _t: float = 0.0
	var _duration: float = 0.6
	var _landed: bool = false

	func launch(from: Vector3, to: Vector3) -> void:
		_from = from
		_to = to
		_duration = clampf(from.distance_to(to) / 14.0, 0.25, 0.9)
		global_position = from
		_sprite = Sprite3D.new()
		_sprite.texture = IconArt.item_icon(Data.get_item(str(stack.id)))
		_sprite.pixel_size = 0.02
		_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_sprite.shaded = false
		add_child(_sprite)

	func _process(delta: float) -> void:
		if _burning > 0.0:
			_burning -= delta
			_pulse -= delta
			_light.light_energy = randf_range(2.2, 3.4) * clampf(_burning / 5.0, 0.2, 1.0)
			if _pulse <= 0.0:
				_pulse = 2.0
				Stealth.emit_noise(get_tree(), global_position, 0.7, "decoy")
			if _burning <= 0.0:
				queue_free()
			return
		if _landed:
			return
		_t += delta / _duration
		var k := minf(_t, 1.0)
		var p := _from.lerp(_to, k)
		p.y += sin(PI * k) * (1.2 + _from.distance_to(_to) * 0.12)
		global_position = p
		_sprite.rotation.z -= delta * 14.0
		if k >= 1.0:
			_landed = true
			_land()

	func _land() -> void:
		var id := str(stack.id)
		_snow_puff()
		match id:
			"empty_bottle":
				AudioManager.play_sfx("glass_break", global_position, 4.0)
				Stealth.emit_noise(get_tree(), global_position, 1.15, "decoy")
				queue_free()
			"flare":
				_burn_flare()
			_:
				AudioManager.play_sfx("stone_hit", global_position, 0.0)
				Stealth.emit_noise(get_tree(), global_position, 0.55, "decoy")
				GameState.drop_stack(stack, global_position)
				queue_free()

	func _snow_puff() -> void:
		var puff := CPUParticles3D.new()
		puff.one_shot = true
		puff.amount = 14
		puff.lifetime = 0.7
		puff.explosiveness = 0.95
		puff.direction = Vector3.UP
		puff.spread = 70.0
		puff.initial_velocity_min = 1.0
		puff.initial_velocity_max = 2.4
		puff.gravity = Vector3(0, -5, 0)
		puff.scale_amount_min = 0.05
		puff.scale_amount_max = 0.1
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.92, 0.95, 1.0)
		mesh.material = mat
		puff.mesh = mesh
		get_parent().add_child(puff)
		puff.global_position = global_position
		puff.emitting = true
		get_tree().create_timer(1.5, false).timeout.connect(puff.queue_free)

	func _burn_flare() -> void:
		_sprite.rotation.z = PI * 0.5
		_sprite.position.y = 0.08
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.25, 0.15)
		_light.light_energy = 3.0
		_light.omni_range = 9.0
		_light.position = Vector3(0, 0.5, 0)
		add_child(_light)
		var sparks := CPUParticles3D.new()
		sparks.amount = 24
		sparks.lifetime = 0.6
		sparks.direction = Vector3.UP
		sparks.spread = 25.0
		sparks.initial_velocity_min = 1.0
		sparks.initial_velocity_max = 2.0
		sparks.gravity = Vector3(0, -1, 0)
		sparks.scale_amount_min = 0.03
		sparks.scale_amount_max = 0.06
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.5, 0.3)
		mesh.material = mat
		sparks.mesh = mesh
		sparks.position = Vector3(0, 0.1, 0)
		add_child(sparks)
		var stream := AudioManager.get_stream("flare_burn")
		if stream and not AudioManager.is_silent():
			var hiss := AudioStreamPlayer3D.new()
			hiss.stream = stream
			hiss.bus = "SFX"
			hiss.volume_db = -3.0
			hiss.unit_size = 4.0
			add_child(hiss)
			hiss.play()
		_burning = PlayerThrow.FLARE_TIME
		_pulse = 0.0
