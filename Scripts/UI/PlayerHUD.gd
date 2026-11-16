extends CanvasLayer
class_name PlayerHUD

@onready var crosshair_animation_tree: AnimationTree = $Control/Crosshair/AnimationTree
@onready var crosshair_animation_tree_playback: AnimationNodeStateMachinePlayback = (
	crosshair_animation_tree.get("parameters/playback")
)

func handle_crosshair_shoot() -> void:
	crosshair_animation_tree_playback.travel("Shoot", true)
	crosshair_animation_tree.set("parameters/Shoot/TimeSeek/seek_request", 0.0)
