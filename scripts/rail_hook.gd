extends Area3D

func release_ware() -> void:
	# unparent all children
	for child in get_children():

		if child.name != "WarePosition": # only release the ware object
			_release_from_rail(child)

func _release_from_rail(node: Node3D) -> void:
	var child_global_transform = node.global_transform
	node.get_parent().remove_child(node)
	get_tree().get_root().add_child(node)
	node.global_transform = child_global_transform

	node.axis_lock_angular_x = false
	node.axis_lock_angular_y = false
	node.axis_lock_angular_z = false
	node.axis_lock_linear_x = false
	node.axis_lock_linear_y = false
	node.axis_lock_linear_z = false


func _on_area_entered(area: Area3D) -> void:
	if area == %DropOffArea:
		release_ware()
		get_parent().get_parent().active = false
