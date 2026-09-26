class_name RecipeData
extends Resource
## Crafting recipe. Stored in res://data/recipes/*.tres.

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
## item_id -> count
@export var ingredients: Dictionary = {}
@export var result_item: String = ""
@export var result_count: int = 1
## Game minutes spent crafting.
@export var crafting_time: int = 20
@export var required_station: String = "workbench"
@export var required_shelter_level: int = 1
## Known without a book / teacher (otherwise learned via GameState.learn_recipe).
@export var known_from_start: bool = true
## Extra data-driven conditions (see Conditions), e.g. [{"flag": "shelter_heated"}].
@export var conditions: Array = []
