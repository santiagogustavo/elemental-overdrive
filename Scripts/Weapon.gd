extends Node3D
class_name Weapon

signal away

@export var idle_timeout: float = 5.0
@export var holstered: bool = false
@export var is_attacking: bool = false
@export var bullet_prefab: PackedScene
@export var muzzle_node: Node3D
@export var bullets_per_shot: int = 1
@export var target_spread: float = 0.0
@export var muzzle_spread: float = 0.0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")

var ambience_tree_time: float = 0.0
var target_point: Vector3 = Vector3.ZERO

func _process(delta: float) -> void:
	animation_tree.set("parameters/conditions/holster", holstered)
	animation_tree.set("parameters/conditions/draw", !holstered)
	animation_tree.set("parameters/Idle/conditions/is_attacking", is_attacking)
	animation_tree.set("parameters/Idle/conditions/is_not_attacking", !is_attacking)
	ambience_tree_time += delta
	if is_attacking:
		clear_ambience()
	if ambience_tree_time >= idle_timeout:
		handle_idle_timeout()

func handle_attack() -> void:
	for shot in range(bullets_per_shot):
		var bullet_instance: Bullet = bullet_prefab.instantiate()
		get_tree().root.add_child(bullet_instance)
		var spread_target_point = target_point + Vector3(
			randf_range(-target_spread, target_spread),
			randf_range(-target_spread, target_spread),
			randf_range(-target_spread, target_spread),
		)
		var spread_global_position = muzzle_node.global_position + Vector3(
			randf_range(-muzzle_spread, muzzle_spread),
			randf_range(-muzzle_spread, muzzle_spread),
			randf_range(-muzzle_spread, muzzle_spread),
		)
		bullet_instance.target_point = spread_target_point
		bullet_instance.global_position = spread_global_position
		bullet_instance.look_at(spread_target_point + Vector3(0.0, 0.01, 0.0), Vector3.UP, true)
		bullet_instance.update_velocity()

func handle_idle_timeout() -> void:
	animation_tree.set("parameters/Idle/conditions/ambience", true)

func clear_ambience() -> void:
	animation_tree.set("parameters/Idle/conditions/ambience", false)
	ambience_tree_time = 0.0

func emit_away_signal() -> void:
	away.emit()
