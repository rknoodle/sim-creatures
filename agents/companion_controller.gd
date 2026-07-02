# companion_controller.gd
# Componente Node. Gestiona el comportamiento de acompañamiento entre PARTNERS:
# proximidad pasiva, acompañamiento activo a objetos, y autonomía individual.
class_name CompanionController
extends Node

signal companion_assist_requested(initiator: BaseAgent, target_object: SmartObject)
signal companion_assist_started(partner: BaseAgent)
signal companion_assist_ended

## Distancia máxima tolerada antes de intentar acercarse a la pareja.
@export var max_partner_distance: float = 250.0
## Umbral de urgencia propia por debajo del cual el agente puede interrumpir
## su tarea menor para acompañar a su pareja.
@export var own_urgency_override: float = 80.0
## Umbral de químico ajeno que activa la invitación a acompañar.
@export var partner_action_threshold: float = 70.0

var is_assisting: bool = false
var _assist_target_object: SmartObject = null
var _agent: BaseAgent

const CHEMICALS: Array[StringName] = [
	&"hunger", &"fatigue", &"loneliness", &"pain"
]


func _ready() -> void:
	_agent = get_parent() as BaseAgent
	assert(_agent != null, "CompanionController: debe ser hijo de BaseAgent.")


func _physics_process(_delta: float) -> void:
	var partner: BaseAgent = _get_bonded_partner()
	if partner == null:
		return
	if is_assisting:
		return
	if _agent._state != BaseAgent.AgentState.WANDERING:
		return

	_maintain_proximity(partner)


## Llamado por BaseAgent cuando este agente decide ir a un objeto crítico.
## Notifica a su pareja vinculada para que decida si acompaña.
func notify_action_started(target_object: SmartObject, chemical: StringName) -> void:
	var partner: BaseAgent = _get_bonded_partner()
	if partner == null:
		return
	var level: float = _agent.chemical_profile.get_level(chemical)
	if level < partner_action_threshold:
		return
	partner.companion.companion_assist_requested.emit(_agent, target_object)
	partner.companion._receive_assist_request(_agent, target_object)


## Lógica de decisión al recibir invitación de acompañamiento.
func _receive_assist_request(initiator: BaseAgent, target_object: SmartObject) -> void:
	if is_assisting:
		return
	if _has_critical_own_need():
		return
	if _agent._state == BaseAgent.AgentState.COURTING:
		return
	if _agent._state == BaseAgent.AgentState.COURTING_ACTIVE:
		return
	if _agent._state == BaseAgent.AgentState.INTERACTING:
		return
	if _agent._state == BaseAgent.AgentState.MATING:
		return

	_start_assisting(initiator, target_object)

func _start_assisting(partner: BaseAgent, target_object: SmartObject) -> void:
	is_assisting = true
	_assist_target_object = target_object
	_agent._wander.stop()
	_agent._state = BaseAgent.AgentState.NAVIGATING_TO_OBJECT
	_agent._nav_agent.target_position = target_object.global_position
	companion_assist_started.emit(partner)
	print("[Acompañamiento] %s acompaña a %s" % [
		_agent.identity.creature_name,
		partner.identity.creature_name
	])

	if not target_object.interaction_completed.is_connected(_on_assist_object_completed):
		target_object.interaction_completed.connect(_on_assist_object_completed, CONNECT_ONE_SHOT)
	if not target_object.interaction_cancelled.is_connected(_on_assist_object_cancelled):
		target_object.interaction_cancelled.connect(_on_assist_object_cancelled, CONNECT_ONE_SHOT)


## Al llegar junto al objeto, decide si interactúa preventivamente o espera.
func on_arrived_at_assist_target() -> void:
	if _assist_target_object == null:
		return
	if _assist_target_object.is_available():
		_assist_target_object.request_interaction(_agent)
		_agent._state = BaseAgent.AgentState.INTERACTING
	else:
		_agent._state = BaseAgent.AgentState.INTERACTING
		_agent.velocity = Vector2.ZERO


func _on_assist_object_completed(_agent_who_finished: BaseAgent) -> void:
	_end_assisting()


func _on_assist_object_cancelled(_agent_who_cancelled: BaseAgent) -> void:
	_end_assisting()


func _end_assisting() -> void:
	is_assisting = false
	_assist_target_object = null
	_agent._state = BaseAgent.AgentState.WANDERING
	_agent._wander.start(_agent.global_position)
	companion_assist_ended.emit()


## Comprueba si alguna necesidad propia es absolutamente crítica (rompe acompañamiento).
func _has_critical_own_need() -> bool:
	for chemical: StringName in CHEMICALS:
		if _agent.chemical_profile.get_level(chemical) >= own_urgency_override:
			return true
	return false


## Mantiene proximidad pasiva con la pareja cuando ambos están libres (WANDERING).
func _maintain_proximity(partner: BaseAgent) -> void:
	var dist: float = _agent.global_position.distance_to(partner.global_position)
	if dist <= max_partner_distance:
		return
	if not is_instance_valid(partner):
		return

	# Redirige el wander hacia la zona de la pareja sin pegarse
	_agent._wander._origin = partner.global_position
	_agent._wander._pick_new_destination()


func _get_bonded_partner() -> BaseAgent:
	var p: BaseAgent = _agent.romance.bonded_partner
	if p != null and is_instance_valid(p):
		return p
	return null
