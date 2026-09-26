extends Level
## District — the outdoor level (Квартал 9). Bakes navigation at load time so the
## Snow Stalker can path around buildings; everything else is generic Level behaviour.

@onready var nav_region: NavigationRegion3D = $NavRegion


func _ready() -> void:
	super._ready()
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh(true)
