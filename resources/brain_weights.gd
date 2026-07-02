# brain_weights.gd
# Resource persistible que almacena la matriz de pesos asociativos del agente.
# Filas = acciones, Columnas = químicos que las refuerzan.
# Un peso alto significa que el agente aprendió que esa acción alivia ese químico.
class_name BrainWeights
extends Resource

# Pesos iniciales: acción -> { químico -> peso }
# Rango de pesos: -1.0 (asociación negativa) a 1.0 (asociación fuerte)
@export var weights: Dictionary = {
	&"eat": {
		&"hunger":     0.6,
		&"fatigue":    0.0,
		&"loneliness": 0.0,
		&"pain":       0.0,
	},
	&"sleep": {
		&"hunger":     0.0,
		&"fatigue":    0.6,
		&"loneliness": 0.0,
		&"pain":       0.1,
	},
	&"wander": {
		&"hunger":     0.0,
		&"fatigue":   -0.1,
		&"loneliness": 0.3,
		&"pain":       0.0,
	},
}

const WEIGHT_MIN: float = -1.0
const WEIGHT_MAX: float = 1.0
const LEARNING_RATE: float = 0.08


## Devuelve el peso de una acción para un químico concreto.
func get_weight(action: StringName, chemical: StringName) -> float:
	if not weights.has(action) or not weights[action].has(chemical):
		return 0.0
	return weights[action][chemical]


## Ajusta el peso de una acción-químico según la señal de recompensa.
## delta_reward > 0 refuerza, < 0 penaliza.
func adjust(action: StringName, chemical: StringName, delta_reward: float) -> void:
	if not weights.has(action) or not weights[action].has(chemical):
		return
	var current: float = weights[action][chemical]
	weights[action][chemical] = clampf(
		current + delta_reward * LEARNING_RATE,
		WEIGHT_MIN,
		WEIGHT_MAX
	)


## Calcula la puntuación total de una acción dado el estado químico actual.
## Multiplica cada peso por el nivel normalizado del químico correspondiente.
func score_action(action: StringName, profile: ChemicalProfile) -> float:
	if not weights.has(action):
		return 0.0
	var score: float = 0.0
	var action_weights: Dictionary = weights[action]
	for chemical: StringName in action_weights:
		var level_normalized: float = profile.get_level(chemical) / 100.0
		score += action_weights[chemical] * level_normalized
	return score


## Devuelve la acción con mayor puntuación dado el estado químico actual.
func get_best_action(profile: ChemicalProfile) -> StringName:
	var best_action: StringName = &""
	var best_score: float = -INF
	for action: StringName in weights.keys():
		var s: float = score_action(action, profile)
		if s > best_score:
			best_score = s
			best_action = action
	return best_action
