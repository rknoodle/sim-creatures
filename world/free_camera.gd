# free_camera.gd
# Click derecho: arrastrar cámara.
# Click izquierdo corto: seleccionar agente.
# Click izquierdo sostenido: mover agente (delegado a AgentDragger).
# Rueda: zoom con indicador de porcentaje.
class_name FreeCamera
extends Camera2D

signal zoom_changed(percent: int)

@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.3
@export var max_zoom: float = 3.0
@export var drag_threshold: float = 6.0
@export var hold_threshold: float = 0.18  # segundos para considerar "sostenido"

# Estado drag cámara (click derecho)
var _cam_dragging: bool = false
var _cam_last_pos: Vector2 = Vector2.ZERO

# Estado click izquierdo
var _left_press_pos: Vector2 = Vector2.ZERO
var _left_press_time: float = 0.0
var _left_held: bool = false
var _left_is_agent_drag: bool = false


func _ready() -> void:
	make_current()
	add_to_group("main_camera")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _process(delta: float) -> void:
	# Detectar si el click izquierdo sostenido supera el umbral de tiempo
	if _left_held and not _left_is_agent_drag:
		_left_press_time += delta
		if _left_press_time >= hold_threshold:
			_left_is_agent_drag = true
			AgentDragger.try_grab_at(_left_press_pos)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_cam_dragging = true
				_cam_last_pos = event.position
			else:
				_cam_dragging = false

		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_left_press_pos  = event.position
				_left_press_time = 0.0
				_left_held       = true
				_left_is_agent_drag = false
			else:
				if _left_held and not _left_is_agent_drag \
				and _left_press_time < hold_threshold:
					# Click corto: seleccionar agente
					_try_select_agent(event.position)
				if _left_is_agent_drag:
					AgentDragger.release()
				_left_held = false
				_left_is_agent_drag = false

		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_apply_zoom(-zoom_step)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_apply_zoom(zoom_step)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# Arrastrar cámara con click derecho
	if _cam_dragging:
		var delta: Vector2 = (event.position - _cam_last_pos) / zoom
		global_position -= delta
		_cam_last_pos = event.position
		get_viewport().set_input_as_handled()
		return

	# Mover agente con click izquierdo sostenido
	if _left_is_agent_drag:
		AgentDragger.drag_to(screen_to_world(event.position))
		get_viewport().set_input_as_handled()


func _apply_zoom(step: float) -> void:
	var new_zoom: float = clampf(zoom.x + step, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
	var percent: int = int(new_zoom * 100.0)
	zoom_changed.emit(percent)


func _try_select_agent(screen_pos: Vector2) -> void:
	var world_pos: Vector2 = screen_to_world(screen_pos)
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
	if best != null:
		EventBus.creature_selected.emit(best)
	else:
		EventBus.creature_deselected.emit()


func screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp_center: Vector2 = get_viewport_rect().size * 0.5
	return global_position + (screen_pos - vp_center) / zoom
