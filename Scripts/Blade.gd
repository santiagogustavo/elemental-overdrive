extends Node3D
class_name Blade

@export_group("Referências")
@export var camera: Camera3D
@export var blade_target: Node3D # Marker3D filho do BoneAttachment3D da arma/mão
@export var impact_scene: PackedScene # Cena (GPUParticles3D, Decal, etc.) orientada no eixo -Z

@export_group("Configurações do Ataque")
@export var reach: float = 2.4
@export var sweep_radius: float = 0.35
@export var steps_per_frame: int = 4 # Sub-passos entre o frame anterior e o atual
@export var damage: float = 25.0

@export_group("Múltiplos Hits no Mesmo Alvo")
@export var allow_multiple_hits: bool = true
@export var hit_cooldown: float = 0.25 # Tempo em segundos que o alvo precisa esperar para tomar outro dano do mesmo swing
@export var max_hits_per_target: int = 3 # Limite de vezes que o mesmo alvo pode ser atingido no mesmo swing

@export_group("Camadas de Colisão")
@export_flags_3d_physics var world_mask: int = 1 # Camada de paredes/cenário
@export_flags_3d_physics var hit_mask: int = 2 # Camada de inimigos/hurtboxes

var is_swinging: bool = false
var prev_aim_direction: Vector3 = Vector3.ZERO
var hit_wall_this_swing: bool = false

# Dicionário para rastrear: { TargetNode: { "count": int, "last_hit_time": float } }
var hit_tracking_data: Dictionary = {}
var swing_start_time: float = 0.0

func start_swing() -> void:
	if not camera or not blade_target:
		push_warning("Camera ou Blade Target não atribuídos no script de Melee.")
		return

	is_swinging = true
	hit_tracking_data.clear()
	hit_wall_this_swing = false
	swing_start_time = Time.get_ticks_msec() / 1000.0

	# Captura a direção inicial logo no início do golpe para não haver salto no primeiro frame
	prev_aim_direction = _get_current_aim_direction()

func end_swing() -> void:
	is_swinging = false

func _physics_process(_delta: float) -> void:
	if not is_swinging or not camera or not blade_target:
		return

	var current_aim_direction = _get_current_aim_direction()

	# Interpola a direção entre o frame de física anterior e o atual
	for i in range(steps_per_frame):
		var t = float(i + 1) / steps_per_frame
		var step_direction = prev_aim_direction.slerp(current_aim_direction, t).normalized()
		_perform_camera_sweep(step_direction)

	prev_aim_direction = current_aim_direction

func _get_current_aim_direction() -> Vector3:
	var dir = blade_target.global_position - camera.global_position
	if dir.is_zero_approx():
		return -camera.global_transform.basis.z
	return dir.normalized()

func _perform_camera_sweep(direction: Vector3) -> void:
	var space_state = camera.get_world_3d().direct_space_state
	var origin = camera.global_position
	var target_pos = origin + (direction * reach)

	# 1. Checagem de parede
	var wall_query = PhysicsRayQueryParameters3D.create(origin, target_pos, world_mask)
	var wall_hit = space_state.intersect_ray(wall_query)
	if wall_hit:
		target_pos = wall_hit.position
		if not hit_wall_this_swing:
			hit_wall_this_swing = true
			_spawn_impact(wall_hit.position, wall_hit.normal)

	# 2. Varredura esférica (Sphere Sweep)
	var shape = SphereShape3D.new()
	shape.radius = sweep_radius

	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = hit_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.transform = Transform3D(Basis(), origin)
	params.motion = target_pos - origin

	var cast_result = space_state.cast_motion(params)
	if cast_result[0] < 1.0:
		params.transform.origin = origin + params.motion * cast_result[1]

		var rest_info = space_state.get_rest_info(params)
		if not rest_info.is_empty():
			var collider = instance_from_id(rest_info.collider_id) as Node3D
			if collider:
				_evaluate_and_apply_hit(collider, rest_info.point, rest_info.normal)

func _evaluate_and_apply_hit(target: Node3D, hit_point: Vector3, hit_normal: Vector3) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0

	if not hit_tracking_data.has(target):
		# Primeiro hit neste alvo durante este swing
		hit_tracking_data[target] = {
			"count": 1,
			"last_hit_time": current_time
		}
		_apply_melee_hit(target, hit_point, hit_normal)
	else:
		# O alvo já foi atingido antes neste mesmo swing
		if not allow_multiple_hits:
			return

		var data = hit_tracking_data[target]

		# Valida o limite máximo de hits e o cooldown de tempo entre os golpes
		var elapsed_since_last_hit = current_time - data["last_hit_time"]
		if data["count"] < max_hits_per_target and elapsed_since_last_hit >= hit_cooldown:
			data["count"] += 1
			data["last_hit_time"] = current_time
			_apply_melee_hit(target, hit_point, hit_normal)

func _apply_melee_hit(target: Node3D, hit_point: Vector3, hit_normal: Vector3) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage, hit_point)

	_spawn_impact(hit_point, hit_normal)

func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	if not impact_scene:
		return

	var impact = impact_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(impact)
	impact.global_position = pos

	var up_dir = Vector3.UP
	if abs(normal.dot(Vector3.UP)) > 0.99:
		up_dir = Vector3.RIGHT

	impact.look_at(pos + normal, up_dir)
