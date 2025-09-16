extends Area3D

@export var buttonID: int = 0
@export var button_mesh: MeshInstance3D

var mat
signal clicked

func _ready():
	
	# Try to grab its existing material on surface 0
	mat = button_mesh.get_active_material(0)
	if mat:
		# Duplicate so we don’t change the shared resource
		mat = mat.duplicate() as StandardMaterial3D
	else:
		# Or create a fresh StandardMaterial3D
		mat = StandardMaterial3D.new()
	
	# This is the correct method in Godot 4
	monitoring = true
	monitorable = true

func _on_entered():
	print("entered")
	mat.albedo_color = Color(0, 0, 1)
	button_mesh.set_surface_override_material(0, mat)
	
	%VendingManager.start_vending(buttonID)
	emit_signal("clicked")
	#button_mesh.mesh.material.albedo_color = Color(0, 0, 1)
	# Optional: Visual feedback


func _on_exited():
	print("exited")
	mat.albedo_color = Color(1, 1, 1)
	button_mesh.set_surface_override_material(0, mat)
	# Optional: Reset visual feedback

func _on_area_entered(area: Area3D) -> void:
	if area.name == "RightHandSelector" || area.name == "LeftHandSelector":
		_on_entered()

func _on_area_exited(area: Area3D) -> void:
	if area.name == "RightHandSelector" || area.name == "LeftHandSelector":
		_on_exited()
