extends Node3D

var base_speed: float = 0.1

func move_forward(delta):
	translate(Vector3(0, 0, %VendingManager.vending_speed * base_speed * delta))

func _on_drop_area_body_entered(body: Node3D) -> void:
	
	print("detecting:")
	print(body.name)
	
	var drop_item: RigidBody3D = body as RigidBody3D
	if drop_item == null:
		return
		
	#if drop_item.ware_dropped:
		#return
	#else:
		#drop_item.ware_dropped = true
		#get_parent().active = false
	
	drop_item.reparent(%VendingManager.drop_collector)
	get_parent().active = false
	
	drop_item.axis_lock_angular_x = false;
	drop_item.axis_lock_angular_y = false;
	drop_item.axis_lock_angular_z = false;
	drop_item.axis_lock_linear_x = false;
	drop_item.axis_lock_linear_y = false;
	drop_item.axis_lock_linear_z = false;
	
	
