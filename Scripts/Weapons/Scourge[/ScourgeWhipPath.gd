extends Path3D
class_name ScourgeWhipPath

@export var whip_trail: GPUTrail3D
@export var whip_time: float = 1.0
@onready var path_follow: PathFollow3D = $PathFollow3D

func _process(delta: float) -> void:
	path_follow.progress_ratio += whip_time * delta
	whip_trail.position.y = path_follow.position.y
	whip_trail.rotation.x = path_follow.rotation.x
