# agent_dragger.gd
# Autoload que permite agarrar agentes con clic derecho y moverlos por el mapa.
# Añadir en Project > Autoload como "AgentDragger".
#class_name AgentDragger
extends Node

var _dragged_agent: BaseAgent = null
var _saved_state: BaseAgent.AgentState = BaseAgent.AgentState.WANDERING
var _camera: Camera2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func register_camera(camera: Camera2D) -> void:
	_camera = camera


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_try_grab(mb.position)
			else:
				_release()

	elif event is InputEventMouseMotion and _dragged_agent != null:
		if _camera == null:
			return
		var world_pos: Vector2 = _camera.get_global_transform().affine_inverse() * \
			_camera.get_viewport().get_mouse_position()
		# Ajustar por zoom
		var zoom: float = _camera.zoom.x
		var vp_center: Vector2 = _camera.get_viewport_rect().size * 0.5
		world_pos = _camera.global_position + \
			(_camera.get_viewport().get_mouse_position() - vp_center) / zoom
		_dragged_agent.global_position = world_pos
		get_viewport().set_input_as_handled()


func _try_grab(screen_pos: Vector2) -> void:
	if _camera == null:
		return
	var zoom: float = _camera.zoom.x
	var vp_center: Vector2 = _camera.get_viewport_rect().size * 0.5
	var world_pos: Vector2 = _camera.global_position + \
		(screen_pos - vp_center) / zoom

	# Buscar el agente más cercano al clic
	var best: BaseAgent = null
	var best_dist: float = 40.0  # Radio máximo de selección en píxeles mundo
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
	_saved_state   = best._state

	# Suspender al agente mientras es arrastrado
	best._state = BaseAgent.AgentState.WANDERING
	best._wander.stop()
	best._nav_agent.target_position = best.global_position
	best.velocity = Vector2.ZERO


func _release() -> void:
	if _dragged_agent == null:
		return
	# Reactivar al agente en su nueva posición
	_dragged_agent._wander.start(_dragged_agent.global_position)
	_dragged_agent._state = BaseAgent.AgentState.WANDERING
	_dragged_agent = null
