class_name ItemData
extends Resource
## Definition of one item type. Instances live in res://data/items/*.tres.
## Runtime inventories only store ids + counts; everything else is read from here.

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
## Optional art. When empty the UI draws a procedural pixel icon from icon_shape/icon_color.
@export var icon: Texture2D
@export var icon_shape: String = "box"
@export var icon_color: Color = Color(0.8, 0.8, 0.8)
@export var weight: float = 0.5
@export var stack_size: int = 10
@export_enum("Food", "Water", "Medical", "Material", "Tool", "Weapon", "Ammunition", "Quest", "Equipment", "Electronics") var category: String = "Material"
@export_enum("common", "uncommon", "rare", "unique") var rarity: String = "common"
@export var usable: bool = false
@export var craftable: bool = false
@export var value: int = 1
@export var tags: PackedStringArray = PackedStringArray()

@export_group("Use")
## Verb shown on the Use button ("Съесть", "Выпить", ...).
@export var use_text: String = "Использовать"
## Consequence dictionaries applied when the item is consumed (see Consequences).
@export var use_effects: Array = []

@export_group("Equipment")
## "", "body", "face" or "hand". Equippable items stay in the inventory while equipped.
@export var equip_slot: String = ""
## 0..1 share of cold blocked while equipped.
@export var insulation: float = 0.0


func is_equippable() -> bool:
	return not equip_slot.is_empty()


func has_tag(tag: String) -> bool:
	return tags.has(tag)
