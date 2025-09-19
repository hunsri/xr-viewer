extends Node3D

func scale_object(new_scale :Vector3) -> void:
	scale = new_scale
	var parent :Node3D = get_parent_node_3d()
	
	# scaling the collision shape that we can assume is a sibling of the node
	# that this script is attached to  
	for child in parent.get_children():
		if child is CollisionShape3D:
			child.scale = new_scale
			break
