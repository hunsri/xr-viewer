extends Node3D

var rotation_speed = 180

@export var main_spiral: Node3D
@export var support_spiral: Node3D
@export var rail: Node3D

@export var active: bool = false

var timeout: float = 10000.0
var stop_in = 0

func activate():
	active = true
	stop_in = Time.get_ticks_msec() + timeout

func deactivate():
	active = false

func _process(delta):

	if !active:
		return
	
	if stop_in < Time.get_ticks_msec():
		deactivate()
		
	do_spiral(delta)
	move_rails(delta)
	
func move_rails(delta):
	if rail != null:
		rail.move_forward(delta)
	
func do_spiral(delta):
	if main_spiral != null:
		main_spiral.rotate_z(deg_to_rad(%VendingManager.vending_speed * -rotation_speed  * delta))
	
	if support_spiral != null:
		support_spiral.rotate_z(deg_to_rad(%VendingManager.vending_speed * -rotation_speed * delta))
