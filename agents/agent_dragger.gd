# agent_dragger.gd
# Autoload. La cámara delega aquí el agarre y movimiento de agentes.
#class_name AgentDragger
extends Node

var _dragged_agent: BaseAgent = null
var _camera: Camera2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func register_camera(camera: Camera2D) -> void:
	_camera = camera


func try_grab_at(screen_pos: Vector2) -> void:
	if _camera == null:
		return
	var world_pos: Vector2 = (_camera as FreeCamera).screen_to_world(screen_pos)
	var best: BaseAgent = null
	var best_dist: float = 32.0
	for node: Node in get_tree().get_nodes_in_group("agents"):
		var agent := node as BaseAgent
		if agent == null:
			continue
		var dist: float = world_pos.distance_to(agent.global_position)
		if dist < best_dist:
			best_dist = dist
			best = agent
	if best == null:
		return
	_dragged_agent = best
	best._wander.stop()
	best._nav_agent.target_position = best.global_position
	best.velocity = Vector2.ZERO


func drag_to(world_pos: Vector2) -> void:
	if _dragged_agent == null or not is_instance_valid(_dragged_agent):
		return
	_dragged_agent.global_position = world_pos


func release() -> void:
	if _dragged_agent == null:
		return
	_dragged_agent._wander.start(_dragged_agent.global_position)
	_dragged_agent._state = BaseAgent.AgentState.WANDERING
	_dragged_agent = null
