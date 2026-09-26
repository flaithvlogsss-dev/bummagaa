class_name ItemPickup
extends Interactable
## A single authored item lying in the level, shown as a floating pixel icon.
## Takes as many as fit; the rest stays (remaining count is saved in the object state).

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
	_icon.texture = IconArt.item_icon(Data.get_item(item_id))
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


func remaining() -> int:
	return int(get_state("left", count))


func get_prompt() -> String:
	var n := remaining()
	return "%s — %s%s" % [interaction_text, display_name, " ×%d" % n if n > 1 else ""]


func _on_interact(_actor: Node) -> bool:
	var n := remaining()
	var added := GameState.inventory.add(item_id, n)
	if added <= 0:
		GameState.notify("Не влезет: рюкзак полон или слишком тяжёл.", "warning")
		AudioManager.play_ui("deny")
		return false
	GameState.notify("+%d %s" % [added, Data.get_item_name(item_id)], "item")
	if added < n:
		set_state("left", n - added)
		AudioManager.play_sfx(interaction_sound)
		return false
	return true
