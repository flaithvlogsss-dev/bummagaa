class_name ItemPickup
extends Interactable
## A single item lying in the world, shown as a floating pixel icon.

@export var item_id: String = ""
@export var count: int = 1

var _icon: Sprite3D
var _t: float = 0.0


func _init() -> void:
	interaction_text = "Подобрать"
	interaction_sound = "pickup"
	one_time_use = true
	hide_when_unavailable = true


func _ready() -> void:
	super._ready()
	if display_name == "Объект" or display_name.is_empty():
		display_name = Data.get_item_name(item_id)
	_icon = Sprite3D.new()
	_icon.texture = PixelArt.item_icon(Data.get_item(item_id))
	_icon.pixel_size = 0.03
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_icon.shaded = false
	_icon.position = Vector3(0, 0.5, 0)
	add_child(_icon)
	var glint := OmniLight3D.new()
	glint.light_color = Color(0.9, 0.95, 1.0)
	glint.light_energy = 0.25
	glint.omni_range = 1.4
	glint.position = Vector3(0, 0.7, 0)
	add_child(glint)


func _process(delta: float) -> void:
	if _icon and visible:
		_t += delta
		_icon.position.y = 0.5 + sin(_t * 2.2) * 0.06


func get_prompt() -> String:
	return "%s — %s%s" % [interaction_text, display_name, " ×%d" % count if count > 1 else ""]


func _on_interact(_actor: Node) -> bool:
	if GameState.inventory.add(item_id, count) <= 0:
		return false
	GameState.notify("+%d %s" % [count, Data.get_item_name(item_id)], "item")
	return true
