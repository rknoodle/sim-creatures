# smart_object.gd
# Nodo base para todos los objetos interactivos del entorno.
# Extiende Area2D para detectar proximidad física.
class_name SmartObject
extends Area2D

signal interaction_started(agent: BaseAgent)
signal interaction_completed(agent: BaseAgent)
signal interaction_cancelled(agent: BaseAgent)

@export var object_label: String = "Objeto"
@export var interaction: InteractionDefinition

## Si false, ningún agente puede reservar ni usar este objeto.
@export var is_enabled: bool = true

var _current_user: BaseAgent = null
var _is_reserved: bool = false

@onready var _interaction_timer: Timer = Timer.new()


func _ready() -> void:
	_validate_setup()
	add_child(_interaction_timer)
	_interaction_timer.one_shot = true
	_interaction_timer.timeout.connect(_on_interaction_complete)

	# Auto-registro en el singleton global
	ObjectRegistry.register(self)


## Devuelve los nombres de los químicos que este objeto puede aliviar.
func get_target_chemicals() -> Array[StringName]:
	var result: Array[StringName] = []
	if interaction == null:
		return result
	if interaction.hunger_change < 0.0:    result.append(&"hunger")
	if interaction.fatigue_change < 0.0:   result.append(&"fatigue")
	if interaction.loneliness_change < 0.0: result.append(&"loneliness")
	if interaction.pain_change < 0.0:      result.append(&"pain")
	return result


## Comprueba si el objeto está libre y habilitado.
func is_available() -> bool:
	return is_enabled and not _is_reserved


## El agente llama a este método cuando llega al objeto.
func request_interaction(agent: BaseAgent) -> bool:
	if not is_available():
		return false

	_is_reserved = true
	_current_user = agent
	_interaction_timer.wait_time = interaction.duration_seconds
	_interaction_timer.start()
	interaction_started.emit(agent)
	return true


## Permite al agente cancelar la interacción antes de completarse.
func cancel_interaction(agent: BaseAgent) -> void:
	if _current_user != agent:
		return
	_interaction_timer.stop()
	interaction_cancelled.emit(agent)
	_release()


func _on_interaction_complete() -> void:
	if _current_user == null or not is_instance_valid(_current_user):
		_release()
		return

	interaction.apply_to(_current_user.chemical_profile)
	interaction_completed.emit(_current_user)
	_release()


func _release() -> void:
	_current_user = null
	_is_reserved = false


func _validate_setup() -> void:
	assert(interaction != null,
		"SmartObject '%s': requiere un InteractionDefinition asignado." % name)
