extends Node3D

var base_speed: float = 0.05

func move_forward(delta):
	translate(Vector3(0, 0, %VendingManager.vending_speed * base_speed * delta))

func _on_drop_area_body_entered(body: Node3D) -> void:
	
	pass
	
