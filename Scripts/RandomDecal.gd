extends Decal
class_name RandomDecal

@export_group("Rotation Randomization")
@export var randomize_x: bool = false
@export var randomize_y: bool = true  # Usually the most useful for decals on horizontal/vertical surfaces
@export var randomize_z: bool = false
@export var min_angle_degrees: float = 0.0
@export var max_angle_degrees: float = 360.0

@export_group("Scale Randomization")
@export var enable_scale: bool = true
@export var min_scale: float = 0.8
@export var max_scale: float = 1.2
@export var keep_proportion: bool = true  # Keeps X and Y uniform (avoids stretching)

func _ready() -> void:
	randomize_decal()

func randomize_decal() -> void:
	# 1. Randomize Rotation
	var rot_x = randf_range(deg_to_rad(min_angle_degrees), deg_to_rad(max_angle_degrees)) if randomize_x else rotation.x
	var rot_y = randf_range(deg_to_rad(min_angle_degrees), deg_to_rad(max_angle_degrees)) if randomize_y else rotation.y
	var rot_z = randf_range(deg_to_rad(min_angle_degrees), deg_to_rad(max_angle_degrees)) if randomize_z else rotation.z
	
	rotation = Vector3(rot_x, rot_y, rot_z)
	
	# 2. Randomize Scale
	if enable_scale:
		if keep_proportion:
			var scale_factor = randf_range(min_scale, max_scale)
			scale = scale * scale_factor
		else:
			var scale_x = randf_range(min_scale, max_scale)
			var scale_y = randf_range(min_scale, max_scale)
			scale.x *= scale_x
			scale.y *= scale_y
