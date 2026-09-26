class_name CharacterData
extends Resource
## Static description of a character (NPC or the player avatar).
## Runtime state (health, location, memory) lives in GameState.npcs.

@export var id: String = ""
@export var display_name: String = ""
## Shown before the player learns the name.
@export var unknown_name: String = "Незнакомец"
@export var age: int = 30
@export var occupation: String = ""
@export_multiline var bio: String = ""
## Signature line shown in the journal and when first met.
@export var unique_line: String = ""
@export_multiline var personal_need: String = ""
@export var skills: PackedStringArray = PackedStringArray()
@export_enum("survivors", "unknown", "player") var faction: String = "survivors"
@export var is_npc: bool = true

@export_group("Story")
@export var dialogue_id: String = ""
@export var start_location: String = "district"
@export var start_spawn: String = ""
@export var start_injured: bool = false
@export var max_health: float = 100.0
## trust / fear / respect / affinity starting values (-100..100)
@export var relationship_start: Dictionary = {"trust": 0, "fear": 0, "respect": 0, "affinity": 0}
## Items left behind if the character dies (container on the body).
@export var death_loot: Dictionary = {}

@export_group("Look")
## Optional hand-made sheet (4 cols x 5 rows, same layout as the procedural one).
@export var sprite_sheet: Texture2D
@export_enum("average", "tall", "broad", "short", "slim") var silhouette: String = "average"
@export_enum("none", "glasses", "scarf", "cap", "hood", "bag", "helmet", "armband") var accessory: String = "none"
@export var coat_color: Color = Color(0.3, 0.35, 0.45)
@export var pants_color: Color = Color(0.2, 0.2, 0.25)
@export var hair_color: Color = Color(0.25, 0.18, 0.12)
@export var skin_color: Color = Color(0.93, 0.78, 0.66)
@export var accent_color: Color = Color(0.8, 0.2, 0.2)
