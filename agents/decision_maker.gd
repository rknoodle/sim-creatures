# decision_maker.gd
# Componente Node del agente. Evalúa el estado químico y elige
# el objetivo más urgente y el objeto más cercano que lo satisfaga.
class_name DecisionMaker
extends Node

signal target_selected(object: SmartObject, chemical: StringName)
signal no_target_found(chemical: StringName)

@export var evaluation_interval: float = 2.0
@export var critical_threshold: float = 60.0  # A partir de aquí busca objeto

var _agent: BaseAgent
var _timer: Timer

const CHEMICALS: Array[StringName] = [
	&"hunger", &"fatigue", &"loneliness", &"pain"
]


func _ready() -> void:
	_agent = get_parent() as BaseAgent
	assert(_agent != null,
		"DecisionMaker: debe ser hijo directo de BaseAgent.")

	_timer = Timer.new()
	_timer.wait_time = evaluation_interval
	_timer.autostart = true
	_timer.timeout.connect(_evaluate)
	add_child(_timer)


## Fuerza una evaluación inmediata fuera del ciclo del timer.
func evaluate_now() -> void:
	_evaluate()


func _evaluate() -> void:
	var most_critical: StringName = _get_most_critical_chemical()
	if most_critical == &"":
		return

	var level: float = _agent.chemical_profile.get_level(most_critical)
	if level < critical_threshold:
		return

	var target: SmartObject = ObjectRegistry.find_nearest(
		most_critical, _agent.global_position
	)

	if target == null:
		no_target_found.emit(most_critical)
		return

	target_selected.emit(target, most_critical)


## Devuelve el nombre del químico con el nivel más alto.
func _get_most_critical_chemical() -> StringName:
	var highest_level: float = -1.0
	var highest_chemical: StringName = &""

	for chemical: StringName in CHEMICALS:
		var level: float = _agent.chemical_profile.get_level(chemical)
		if level > highest_level:
			highest_level = level
			highest_chemical = chemical

	return highest_chemical
