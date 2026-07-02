# free_camera.gd
# Cámara 2D con desplazamiento por clic-y-arrastre y zoom con la rueda.
class_name FreeCamera
extends Camera2D

@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT
@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.5
## Distancia mínima de arrastre (px) antes de considerar que es "drag" y no un clic de selección.
@export var drag_threshold: float = 6.0

var _is_dragging: bool = false
var _drag_started_on_button: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO
var _press_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	make_current()
	add_to_group("main_camera")   # [AÑADIR]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == drag_button:
		if event.pressed:
			_drag_started_on_button = true
			_is_dragging = false
			_press_position = event.position
			_last_mouse_position = event.position
		else:
			_drag_started_on_button = false
			_is_dragging = false

	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_apply_zoom(-zoom_step)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_apply_zoom(zoom_step)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _drag_started_on_button:
		return

	if not _is_dragging:
		var moved: float = event.position.distance_to(_press_position)
		if moved < drag_threshold:
			return
		_is_dragging = true
		# Una vez confirmado el drag, consumimos el evento para que
		# SelectionComponent no reciba un clic de selección accidental.
		get_viewport().set_input_as_handled()

	var delta: Vector2 = (event.position - _last_mouse_position) / zoom
	global_position -= delta
	_last_mouse_position = event.position
	get_viewport().set_input_as_handled()


func _apply_zoom(step: float) -> void:
	var new_zoom: float = clampf(zoom.x + step, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
