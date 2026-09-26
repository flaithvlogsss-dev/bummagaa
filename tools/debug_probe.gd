extends Node3D

func _ready() -> void:
	var lvl: Node3D = load("res://scenes/world/District.tscn").instantiate()
	add_child(lvl)
	for i in 5:
		await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var ground = lvl.get_node("NavRegion/Ground/Snow")
	var cs: CollisionShape3D = ground.get_children(true)[1]
	print("cs disabled ", cs.disabled, " shape ", cs.shape, " size ", cs.shape.size if cs.shape else null, " gpos ", cs.global_position, " owner shapes ", ground.shape_owner_get_shape_count(0))
	print("ground gpos ", ground.global_position, " world ", ground.get_world_3d(), " mine ", get_world_3d())
	var q := PhysicsRayQueryParameters3D.create(Vector3(-51.5, 5, 6), Vector3(-51.5, -5, 6))
	print("hit: ", space.intersect_ray(q))
	var q2 := PhysicsRayQueryParameters3D.create(Vector3(-51.5, 5, 30), Vector3(-51.5, -5, 30))
	print("hit2 (inside shelter bldg): ", space.intersect_ray(q2))
	var body := StaticBody3D.new()
	var c2 := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(10, 1, 10)
	c2.shape = b
	body.add_child(c2)
	add_child(body)
	body.global_position = Vector3(100, 0, 100)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("hit3 plain: ", space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(100, 5, 100), Vector3(100, -5, 100))))
	get_tree().quit()
