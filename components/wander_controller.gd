# wander_controller.gd
# Componente que genera destinos de movimiento aleatorio para el agente.
# Se comunica con el agente mediante señales, sin acoplamiento directo.
class_name WanderController
extends Node

signal destination_reached
signal new_destination_set(target: Vector2)

@export var wander_radius: float = 200.0
@export var min_wait_time: float = 1.5
@export var max_wait_time: float = 4.0
@export var arrival_distance: float = 8.0

var current_destination: Vector2 = Vector2.ZERO
var _origin: Vector2 = Vector2.ZERO
var _is_active: bool = false

@onready var _timer: Timer = Timer.new()


func _ready() -> void:
	add_child(_timer)
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)


func start(origin: Vector2) -> void:
	_origin = origin
	_is_active = true
	_pick_new_destination()


func stop() -> void:
	_is_active = false
	_timer.stop()


func update(agent_position: Vector2) -> void:
	if not _is_active:
		return

	if agent_position.distance_to(current_destination) <= arrival_distance:
		_is_active = false
		destination_reached.emit()
		_schedule_next_wander()


func _pick_new_destination() -> void:
	var angle: float = randf() * TAU
	var distance: float = randf_range(wander_radius * 0.3, wander_radius)
	current_destination = _origin + Vector2(cos(angle), sin(angle)) * distance
	new_destination_set.emit(current_destination)


func _schedule_next_wander() -> void:
	_timer.wait_time = randf_range(min_wait_time, max_wait_time)
	_timer.start()


func _on_timer_timeout() -> void:
	_is_active = true
	_pick_new_destination()
