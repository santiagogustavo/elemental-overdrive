extends Area3D
class_name Bullet

@export_subgroup("Properties")
@export var speed: float = 35.0
@export var max_bounces: int = 3
@export var damage: int = 5
@export var lifetime: float = -1
@export_range(0.0, 1.0, 0.05) var ricochet_chance: float = 0.25
@export var spread_angle: float = 0.05
@export var hit_decal: PackedScene
@export var keep_trail: bool = false
@export var trail: GPUTrail3D

@onready var ricochet_sfx: AudioStreamPlayer3D = $Ricochet
@onready var metal_hit_sfx: AudioStreamPlayer3D = $MetalHit

var target_point: Vector3
var velocity: Vector3
var bounces_left: int

func _ready() -> void:
	bounces_left = max_bounces
	if lifetime >= 0.0:
		get_tree().create_timer(lifetime).timeout.connect(func ():
			if is_instance_valid(self):
				clear_instance()
		)

func _physics_process(delta: float) -> void:
	var current_pos = global_position
	var next_pos = current_pos + velocity * delta
	
	var space_state = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(current_pos, next_pos)
	
	query.exclude = [get_rid()]
	query.collision_mask = 2
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if bounces_left > 0 and randf() <= ricochet_chance:
			global_position = result.position + result.normal * 0.01
			velocity = velocity.bounce(result.normal)
			if spread_angle > 0.0:
				velocity = velocity.rotated(Vector3.UP, randf_range(-spread_angle, spread_angle))
				velocity = velocity.rotated(Vector3.RIGHT, randf_range(-spread_angle, spread_angle))
			look_at(global_position + velocity, Vector3.UP, true)
			bounces_left -= 1
			ricochet_sfx.play()
		else:
			_spawn_hit_decal(result.position, result.normal)
			metal_hit_sfx.reparent(get_tree().current_scene)
			metal_hit_sfx.play()
			clear_instance()
	
	else:
		global_position = next_pos

func _spawn_hit_decal(hit_pos: Vector3, hit_normal: Vector3) -> void:
	if not hit_decal:
		return
		
	var decal_instance: Node3D = hit_decal.instantiate()
	get_tree().current_scene.add_child(decal_instance)
	
	decal_instance.global_position = hit_pos + hit_normal * 0.005
	
	var up_dir := Vector3.UP
	if abs(hit_normal.dot(Vector3.UP)) > 0.99:
		up_dir = Vector3.FORWARD
		
	decal_instance.look_at(decal_instance.global_position + hit_normal, up_dir)

func update_velocity() -> void:
	velocity = global_transform.basis * Vector3.BACK * speed

func clear_instance() -> void:
	if keep_trail and trail:
		trail.reparent(get_tree().root)
		get_tree().create_timer(1.0).timeout.connect(trail.queue_free)
	queue_free()
