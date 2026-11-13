extends Node3D
class_name QueueFreeTimeout

signal freed

@export var timeout: float

func _ready() -> void:
	get_tree().create_timer(timeout, false).timeout.connect(func (): 
		freed.emit()
		queue_free()
	)
