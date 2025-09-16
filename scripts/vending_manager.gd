extends Node3D

@export var vending_speed: float = 0.5
@export var node_list: Array[Node3D]

@export var drop_collector: Node3D

func start_vending(id:int):
	node_list[id].activate()
