extends CharacterBody3D
class_name Player

@export_group("Movement")
@export var jump_height: float = 20.0
@export var walk_speed: float = 10.0
@export var crouch_speed: float = 5.0
@export var weight: float = 10.0

@export_group("Look Settings")
@export var mouse_sensitivity: float = 0.003
@export var controller_sensitivity: float = 3.0
@export var zoom_fov_factor: float = 20.0

@export_group("Crouch Settings")
@export var standing_height: float = 2.0
@export var crouching_height: float = 1.0
@export var camera_stand_y: float = 1.5
@export var camera_crouch_y: float = 0.8
@export var crouch_transition_speed: float = 10.0

@export_group("Head Bobbing")
@export var bob_freq: float = 12.0
@export var bob_amp: float = 0.08
@export var bob_amp_h: float = 0.04
@export var crouch_bob_freq: float = 8.0
@export var crouch_bob_amp: float = 0.04

@export_group("Weapon Bobbing & Sway")
@export var weapon_bob_freq: float = 12.0
@export var weapon_bob_amp_v: float = 0.02
@export var weapon_bob_amp_h: float = 0.025
@export var sway_amount: float = 0.004
@export var sway_smoothness: float = 10.0

@export_group("Idle Sway (Breathing)")
@export var idle_sway_speed: float = 2.0
@export var idle_sway_amp_v: float = 0.008
@export var idle_sway_amp_h: float = 0.009

@export_group("Weapons")
@export var available_weapons: Array[PackedScene]

@onready var world_camera: Camera3D = $WorldCamera
@onready var weapon_camera: Camera3D = $WeaponContainer/SubViewport/WeaponCamera
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var target_raycast: RayCast3D = $WorldCamera/TargetRaycast
@onready var debug_raycast_target: MeshInstance3D = $WorldCamera/TargetRaycast/MeshInstance3D

var direction: Vector3 = Vector3.ZERO
var input_direction: Vector2 = Vector2.ZERO

var is_walking: bool = false
var is_jumping: bool = false
var is_crouching: bool = false
var is_attacking: bool = false
var is_zooming: bool = false
var crouch_input: bool = false

var camera_pitch: float = 0.0
var bob_timer: float = 0.0

var mouse_input: Vector2 = Vector2.ZERO
var current_sway: Vector2 = Vector2.ZERO

var weapon_instances: Array[Weapon]
var selected_weapon: int = 0
var can_change_weapon: bool = true

@onready var initial_world_camera_fov: float = world_camera.fov
@onready var initial_weapon_camera_fov: float = weapon_camera.fov

func _ready() -> void:
	for available_weapon in available_weapons:
		var weapon_instance = available_weapon.instantiate() as Weapon
		weapon_instances.append(weapon_instance)
		weapon_instance.away.connect(func ():
			weapon_camera.remove_child(weapon_instance)
			weapon_instances[selected_weapon].holstered = false
			weapon_camera.add_child(weapon_instances[selected_weapon])
			can_change_weapon = true
		)
	weapon_camera.add_child(weapon_instances[selected_weapon])
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_input = event.relative
		rotation.y -= event.relative.x * mouse_sensitivity
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		world_camera.rotation.x = camera_pitch

func _process(delta: float) -> void:
	compute_input(delta)
	compute_crouch(delta)
	compute_movement()
	compute_gravity(delta)
	
	move_and_slide()
	
	compute_head_bobbing(delta)
	compute_weapon_camera(delta)
	compute_camera_fov(delta)
	weapon_instances[selected_weapon].is_attacking = is_attacking
	weapon_instances[selected_weapon].target_point = (
		target_raycast.get_collision_point()
		if target_raycast.is_colliding()
		else target_raycast.to_global(target_raycast.target_position)
	)
	debug_raycast_target.global_position = weapon_instances[selected_weapon].target_point

func compute_input(delta: float) -> void:
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_jumping = Input.is_action_just_pressed("jump")
	
	crouch_input = Input.is_action_pressed("crouch")
	
	var look_input = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_input.length() > 0.1:
		rotation.y -= look_input.x * controller_sensitivity * delta
		camera_pitch -= look_input.y * controller_sensitivity * delta
		camera_pitch = clamp(camera_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		world_camera.rotation.x = camera_pitch
		mouse_input = look_input * 15.0
		
	if Input.is_action_just_pressed("next_weapon") and can_change_weapon:
		weapon_instances[selected_weapon].holstered = true
		selected_weapon = selected_weapon + 1 if selected_weapon < weapon_instances.size() - 1 else 0
		can_change_weapon = false
	if Input.is_action_just_pressed("prev_weapon") and can_change_weapon:
		weapon_instances[selected_weapon].holstered = true
		selected_weapon = selected_weapon - 1 if selected_weapon > 0 else weapon_instances.size() - 1
		can_change_weapon = false
	is_attacking = Input.is_action_pressed("attack")
	is_zooming = Input.is_action_pressed("zoom")
	mouse_input = mouse_input.lerp(Vector2.ZERO, delta * 20.0)

func compute_head_bobbing(delta: float) -> void:
	var base_cam_y = camera_crouch_y if is_crouching else camera_stand_y
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z).length()
	
	if is_on_floor() and horizontal_velocity > 0.1:
		var current_freq = crouch_bob_freq if is_crouching else bob_freq
		var current_amp_v = crouch_bob_amp if is_crouching else bob_amp
		var current_amp_h = (crouch_bob_amp * 0.5) if is_crouching else bob_amp_h
		
		bob_timer += delta * horizontal_velocity * (current_freq / walk_speed)
		
		var target_offset_y = sin(bob_timer) * current_amp_v
		var target_offset_x = cos(bob_timer * 0.5) * current_amp_h
		
		world_camera.position.y = move_toward(world_camera.position.y, base_cam_y + target_offset_y, delta * 10.0)
		world_camera.position.x = move_toward(world_camera.position.x, target_offset_x, delta * 10.0)
	else:
		bob_timer = 0.0
		world_camera.position.y = move_toward(world_camera.position.y, base_cam_y, delta * 10.0)
		world_camera.position.x = move_toward(world_camera.position.x, 0.0, delta * 10.0)

func compute_crouch(delta: float) -> void:
	var has_ceiling = check_ceiling()
	
	if crouch_input or has_ceiling:
		is_crouching = true
	else:
		is_crouching = false
		
	var target_height = crouching_height if is_crouching else standing_height
	
	if collision_shape.shape is CapsuleShape3D:
		collision_shape.shape.height = move_toward(collision_shape.shape.height, target_height, crouch_transition_speed * delta)
		var target_shape_y = collision_shape.shape.height / 2.0
		collision_shape.position.y = move_toward(collision_shape.position.y, target_shape_y, crouch_transition_speed * delta)

func check_ceiling() -> bool:
	if not is_crouching:
		return false
		
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position + Vector3(0, crouching_height, 0)
	var ray_end = global_position + Vector3(0, standing_height, 0)
	
	var query = PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_end,
		collision_mask,
		[get_rid()]
	)
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

func compute_movement() -> void:
	var current_speed = crouch_speed if is_crouching else walk_speed
	is_walking = input_direction.length() != 0.0
	
	direction = (
		transform.basis
		* Vector3(input_direction.x, 0, input_direction.y)
	).normalized()
	
	if is_walking:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(direction.x, 0, current_speed)
		velocity.z = move_toward(direction.z, 0, current_speed)
	
	if is_jumping and is_on_floor() and not is_crouching:
		velocity.y = jump_height

func compute_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= weight * ProjectSettings.get_setting("physics/3d/default_gravity") * delta

func compute_weapon_camera(delta: float) -> void:
	weapon_camera.global_transform = world_camera.global_transform
	
	# 1. Sway do Mouse
	var target_sway_x = -mouse_input.x * sway_amount
	var target_sway_y = mouse_input.y * sway_amount
	
	current_sway.x = lerp(current_sway.x, target_sway_x, delta * sway_smoothness)
	current_sway.y = lerp(current_sway.y, target_sway_y, delta * sway_smoothness)
	
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z).length()
	var weapon_offset_x = current_sway.x
	var weapon_offset_y = current_sway.y
	
	# 2. Bobbing ao Andar vs Idle Sway (Respiração) ao Parar
	if is_on_floor() and horizontal_velocity > 0.1:
		var weapon_timer = Time.get_ticks_msec() * 0.001 * weapon_bob_freq
		weapon_offset_x += cos(weapon_timer * 0.5) * weapon_bob_amp_h
		weapon_offset_y += sin(weapon_timer) * weapon_bob_amp_v
	else:
		# Respiração sutil quando o player está parado no chão
		var idle_timer = Time.get_ticks_msec() * 0.001 * idle_sway_speed
		weapon_offset_x += cos(idle_timer * 0.5) * idle_sway_amp_h
		weapon_offset_y += sin(idle_timer) * idle_sway_amp_v
	
	# 3. Aplicação fluida na câmera da arma
	weapon_camera.h_offset = move_toward(weapon_camera.h_offset, weapon_offset_x, delta * 10.0)
	weapon_camera.v_offset = move_toward(weapon_camera.v_offset, weapon_offset_y, delta * 10.0)

func compute_camera_fov(delta: float) -> void:
	var new_world_camera_fov = (
		initial_world_camera_fov - zoom_fov_factor
		if is_zooming
		else initial_world_camera_fov
	)
	var new_weapon_camera_fov = (
		initial_weapon_camera_fov - zoom_fov_factor
		if is_zooming
		else initial_weapon_camera_fov
	)
	world_camera.fov = lerp(world_camera.fov, new_world_camera_fov, delta * 30.0)
	weapon_camera.fov = lerp(weapon_camera.fov, new_weapon_camera_fov, delta * 30.0)
