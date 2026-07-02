# action_selector.gd — Sistema híbrido: cerebro para supervivencia,
# prioridades explícitas para social/romántico.
class_name ActionSelector
extends Node

signal action_chosen(action: StringName, target: SmartObject)
signal no_action_available(action: StringName)
signal social_target_chosen(target: BaseAgent)
signal courtship_target_chosen(target: BaseAgent)
signal mating_triggered

@export var evaluation_interval: float = 2.5
@export var activation_threshold: float = 0.2
@export var loneliness_social_threshold: float = 60.0

## Umbrales de supervivencia — por encima de estos, el cerebro tiene prioridad absoluta.
@export var survival_fatigue_threshold: float = 65.0
@export var survival_hunger_threshold: float = 65.0

const ACTION_TO_CHEMICAL: Dictionary = {
	&"eat":    &"hunger",
	&"sleep":  &"fatigue",
	&"wander": &"loneliness",
}

var _brain: BrainWeights
var _profile: ChemicalProfile
var _agent: BaseAgent
var _timer: Timer


func _ready() -> void:
	_agent = get_parent() as BaseAgent
	_timer = Timer.new()
	_timer.wait_time = evaluation_interval
	_timer.autostart = true
	_timer.timeout.connect(_evaluate)
	add_child(_timer)


func initialize(brain: BrainWeights, profile: ChemicalProfile) -> void:
	_brain = brain
	_profile = profile


func evaluate_now() -> void:
	_evaluate()


func _evaluate() -> void:
	if _brain == null or _profile == null:
		return

	# ── NIVEL 1: Supervivencia (cerebro asociativo con umbral explícito) ──────
	# Energía primero, luego hambre. Si cualquiera supera el umbral crítico,
	# el cerebro toma el control sin importar nada más.
	if _profile.fatigue >= survival_fatigue_threshold:
		var sleep_target: SmartObject = ObjectRegistry.find_nearest(
			&"fatigue", _agent.global_position
		)
		if sleep_target != null:
			action_chosen.emit(&"sleep", sleep_target)
			return
		no_action_available.emit(&"sleep")
		return

	if _profile.hunger >= survival_hunger_threshold:
		var food_target: SmartObject = ObjectRegistry.find_nearest(
			&"hunger", _agent.global_position
		)
		if food_target != null:
			action_chosen.emit(&"eat", food_target)
			return
		no_action_available.emit(&"eat")
		return

	# ── NIVEL 2: Apareamiento (solo si ya hay pareja vinculada y líbido alta) ─
	if _profile.libido >= _agent.romance.libido_mating_threshold:
		if _agent.romance.has_eligible_mating_partner():
			mating_triggered.emit()
			return

	# ── NIVEL 3: Cortejo (solo si hay amigo elegible y líbido media) ─────────
	if _profile.libido >= _agent.romance.libido_courtship_threshold:
		if _agent._state == BaseAgent.AgentState.COURTING or \
		   _agent._state == BaseAgent.AgentState.COURTING_ACTIVE:
			return
		# Si ya tiene pareja, nunca corteja — el apareamiento (nivel 2) lo maneja
		if _agent.romance.bonded_partner != null:
			pass  # Ignorar nivel 3, caer al nivel 4
		elif _agent.romance.has_eligible_courtship_candidate():
			var candidate: BaseAgent = _agent.romance._find_best_courtship_candidate()
			if candidate != null:
				courtship_target_chosen.emit(candidate)
				return

	# ── NIVEL 4: Socializar (si hay soledad alta) ────────────────────────────
	if _profile.loneliness >= loneliness_social_threshold:
		var social_target: BaseAgent = _find_social_target()
		if social_target != null:
			social_target_chosen.emit(social_target)
			return

	# ── NIVEL 5: Cerebro asociativo para el resto ────────────────────────────
	var best_action: StringName = _brain.get_best_action(_profile)
	var score: float = _brain.score_action(best_action, _profile)
	if score < activation_threshold:
		action_chosen.emit(&"wander", null)
		return
	if best_action == &"wander":
		action_chosen.emit(&"wander", null)
		return
	var chemical: StringName = ACTION_TO_CHEMICAL.get(best_action, &"")
	if chemical == &"":
		action_chosen.emit(&"wander", null)
		return
	var target: SmartObject = ObjectRegistry.find_nearest(chemical, _agent.global_position)
	if target == null:
		no_action_available.emit(best_action)
		return
	action_chosen.emit(best_action, target)


func _find_social_target() -> BaseAgent:
	var best: BaseAgent = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group("agents"):
		var candidate := node as BaseAgent
		if candidate == null or candidate == _agent:
			continue
		var dist: float = _agent.global_position.distance_to(candidate.global_position)
		if dist < best_dist:
			best_dist = dist
			best = candidate
	return best


func _get_agent_position() -> Vector2:
	return _agent.global_position
