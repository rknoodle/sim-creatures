# reinforcement_system.gd
# Componente Node del agente. Compara el estado químico antes y después
# de una acción y envía señales de recompensa/penalización al BrainWeights.
class_name ReinforcementSystem
extends Node

signal reward_applied(action: StringName, chemical: StringName, delta: float)
signal penalty_applied(action: StringName, chemical: StringName, delta: float)

## Umbral de cambio químico para considerar que la acción "funcionó".
@export var relief_threshold: float = 5.0

var _brain: BrainWeights
var _pending_snapshot: ActionSnapshot = null


func initialize(brain: BrainWeights) -> void:
	_brain = brain


## Llamar justo ANTES de ejecutar una acción para guardar el estado inicial.
func record_before(action: StringName, profile: ChemicalProfile) -> void:
	_pending_snapshot = ActionSnapshot.new()
	_pending_snapshot.capture(action, profile)


## Llamar justo DESPUÉS de que la acción termina para calcular el aprendizaje.
func evaluate_after(profile: ChemicalProfile) -> void:
	if _pending_snapshot == null or _brain == null:
		return

	var action: StringName = _pending_snapshot.action_name
	var deltas: Dictionary = _pending_snapshot.compute_deltas(profile)

	for chemical: StringName in deltas:
		var delta: float = deltas[chemical]
		# Alivio real: el químico bajó significativamente
		if delta <= -relief_threshold:
			var reward: float = abs(delta) / 100.0  # Normalizado
			_brain.adjust(action, chemical, reward)
			reward_applied.emit(action, chemical, delta)
		# Efecto nulo o perjudicial: el químico subió o no cambió
		elif delta >= 0.0:
			var penalty: float = -0.1
			_brain.adjust(action, chemical, penalty)
			penalty_applied.emit(action, chemical, delta)

	_pending_snapshot = null
