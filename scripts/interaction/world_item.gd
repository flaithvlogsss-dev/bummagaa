class_name WorldItem
extends Interactable
## WorldItem — an item stack lying in the world (dropped, thrown or spilled from a full bag).
##
## Purpose: the physical side of GameState.dropped_items. The Level spawns one WorldItem per
##   entry of its level on load and on "item_dropped" requests; picking it up moves as much as
##   fits into the backpack and updates or removes the entry, so drops survive saves.
## Scene: res://scenes/items/WorldItem.tscn

var entry: Dictionary = {}
var level_id: String = ""

var _icon: Sprite3D
var _t: float = 0.0


func _init() -> void:
	interaction_text = "Подобрать"
	interaction_sound = "pickup"
	cooldown = 0.2


func setup(p_entry: Dictionary, p_level_id: String) -> void:
	entry = p_entry
	level_id = p_level_id
	var p: Array = entry.get("pos", [0, 0, 0])
	position = Vector3(float(p[0]), float(p[1]), float(p[2]))


func _ready() -> void:
	persistent_id = "drop:%d" % get_instance_id()
	super._ready()
	var stack: Dictionary = entry.get("stack", {})
	var item := Data.get_item(str(stack.get("id", "")))
	display_name = item.name if item else "?"
	_icon = Sprite3D.new()
	_icon.texture = IconArt.item_icon(item)
	_icon.pixel_size = 0.022
	_icon.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_icon.shaded = false
	_icon.position = Vector3(0, 0.19, 0)
	add_child(_icon)
	var shadow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.16)
	shadow.mesh = quad
	shadow.rotation_degrees = Vector3(-90, 0, 0)
	shadow.position = Vector3(0, 0.02, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.05, 0.07, 0.12, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	if item and item.rarity in ["rare", "unique"]:
		var glint := OmniLight3D.new()
		glint.light_color = Color(0.95, 0.9, 0.7)
		glint.light_energy = 0.2
		glint.omni_range = 1.2
		glint.position = Vector3(0, 0.5, 0)
		add_child(glint)


func _process(delta: float) -> void:
	_t += delta
	if _icon:
		# A slow glint so items are noticeable on white snow.
		var k := pow(maxf(0.0, sin(_t * 1.7)), 12.0)
		_icon.modulate = Color(1, 1, 1).lerp(Color(1.5, 1.5, 1.4), k)


func get_prompt() -> String:
	var stack: Dictionary = entry.get("stack", {})
	var n := int(stack.get("count", 1))
	return "%s — %s%s" % [interaction_text, display_name, " ×%d" % n if n > 1 else ""]


func _on_interact(_actor: Node) -> bool:
	var stack: Dictionary = entry.get("stack", {})
	if stack.is_empty():
		queue_free()
		return false
	var n := int(stack.count)
	var added := GameState.inventory.add_stack(stack)
	if added <= 0:
		GameState.notify("Не влезет: рюкзак полон или слишком тяжёл.", "warning")
		AudioManager.play_ui("deny")
		return false
	GameState.notify("+%d %s" % [added, display_name], "item")
	if added >= n:
		GameState.remove_dropped(level_id, entry)
		queue_free()
	else:
		stack.count = n - added
	return true
