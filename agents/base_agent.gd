# base_agent.gd — Módulo 3.5
class_name BaseAgent
extends CharacterBody2D

# --- Señales ---
signal hunger_critical(level: float)
signal fatigue_critical(level: float)
signal loneliness_critical(level: float)
signal pain_critical(level: float)
signal libido_critical(level: float)
signal chemical_normalized(chem_name: StringName)
signal arrived_at_object(object: SmartObject)
signal action_learned(action: StringName, chemical: StringName, reward: float)
signal became_adult

enum AgentState {
	WANDERING,
	NAVIGATING_TO_OBJECT,
	INTERACTING,
	COURTING,           # navegando hacia amigo para cortejar
	COURTING_ACTIVE,    # en radio, ejecutando cortejo (timer)
	MATING,             # apareándose con pareja vinculada
	SOCIALIZING,
}

enum AgeStage { JUVENILE, ADULT }

# --- Exports ---
@export var move_speed: float = 80.0
@export var chemical_profile: ChemicalProfile
@export var brain: BrainWeights
@export var identity: IdentityData

@export var age_to_adult: float = 60.0  # segundos hasta madurez
@export var start_age: float = 0.0

@export var sprite_texture: Texture2D
@export_range(0.5, 2.0, 0.05) var body_scale: float = 1.0

@export var courtship_pursue_speed_multiplier: float = 1.6



# --- Hijos ---
@onready var _wander: WanderController        = $WanderController
@onready var _monitor: ChemicalMonitor        = $ChemicalMonitor
@onready var _selector: ActionSelector        = $ActionSelector
@onready var _reinforcer: ReinforcementSystem = $ReinforcementSystem
@onready var _nav_agent: NavigationAgent2D    = $NavigationAgent2D
@onready var _memory_node: SocialMemory       = $SocialMemory
@onready var _romance_node: RomanceController = $RomanceController
@onready var _sensor: SocialSensor            = $SocialSensor
@onready var _selection: SelectionComponent   = $SelectionComponent
@onready var _companion: CompanionController  = $CompanionController

@onready var _sprite: Sprite2D                = $Sprite2D
@onready var _particles: AgentParticles       = $AgentParticles

# Accesores públicos para que otros componentes lleguen sin búsquedas
var memory: SocialMemory       :
	get: return _memory_node
var romance: RomanceController :
	get: return _romance_node
var companion: CompanionController :
	get: return _companion

var _state: AgentState = AgentState.WANDERING
var _age_stage: AgeStage = AgeStage.JUVENILE
var _age_timer: float = 0.0
var _social_target: BaseAgent = null
var _courtship_target: BaseAgent = null


var _current_target: SmartObject = null
var _current_action: StringName = &""


func _ready() -> void:
	_age_timer = start_age
	add_to_group("agents")
	_setup_identity()
	_validate_setup()

	_monitor.profile = chemical_profile
	_selector.initialize(brain, chemical_profile)
	_reinforcer.initialize(brain)
	_memory_node.initialize_for(_agent_ref())
	_romance_node.initialize(_memory_node)
	_sensor.initialize(_memory_node, _romance_node)
	if sprite_texture != null:
		_sprite.texture = sprite_texture
	if not is_equal_approx(body_scale, 1.0):
		_apply_body_scale()

	_connect_signals()
	_wander.start(global_position)
	await get_tree().physics_frame
	_nav_agent.velocity_computed.connect(_on_nav_velocity_computed)

	print("[Agente] Nació: %s" % identity.display())


func _physics_process(delta: float) -> void:
	_tick_age(delta)
	chemical_profile.tick(delta)
	_monitor.evaluate()
	_check_survival_interruption()

	match _state:
		AgentState.WANDERING:
			_wander.update(global_position)
			_apply_wander_movement()
		AgentState.NAVIGATING_TO_OBJECT:
			_apply_navigation_movement()
		AgentState.INTERACTING:
			velocity = Vector2.ZERO
			move_and_slide()
		AgentState.COURTING:
			_apply_courting_movement()
		AgentState.COURTING_ACTIVE:
			_apply_courting_active()
		AgentState.MATING:
			_apply_mating_movement()
		AgentState.SOCIALIZING:
			_apply_socializing_movement()

# --- Edad ---

func _tick_age(delta: float) -> void:
	if _age_stage == AgeStage.ADULT:
		return
	_age_timer += delta
	if _age_timer >= age_to_adult:
		_age_stage = AgeStage.ADULT
		chemical_profile.set_libido_active(true)
		became_adult.emit()
		print("[Agente] %s alcanzó la madurez." % identity.creature_name)


# --- Identidad ---

func _setup_identity() -> void:
	if identity == null:
		identity = IdentityData.new()
	if identity.creature_name == "":
		identity.generate_random()


# --- Movimiento ---

func _apply_wander_movement() -> void:
	if _wander._is_active:
		var dir: Vector2 = (_wander.current_destination - global_position).normalized()
		velocity = dir * move_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed)
	move_and_slide()


func _apply_navigation_movement() -> void:
	if _nav_agent.is_navigation_finished():
		_on_navigation_finished()
		return
	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var dir: Vector2 = (next_pos - global_position).normalized()
	_nav_agent.set_velocity(dir * move_speed)


func _on_nav_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()


func _on_navigation_finished() -> void:
	if _companion.is_assisting:
		_companion.on_arrived_at_assist_target()
		return
	if _current_target == null or not is_instance_valid(_current_target):
		_return_to_wander()
		return
	arrived_at_object.emit(_current_target)
	_begin_interaction(_current_target)


func _apply_courtship_movement() -> void:
	if _romance_node.current_partner == null:
		return
	var partner_pos: Vector2 = _romance_node.current_partner.global_position
	var dist: float = global_position.distance_to(partner_pos)
	if dist > _romance_node.bonding_radius:
		_nav_agent.target_position = partner_pos
		if not _nav_agent.is_navigation_finished():
			var next_pos: Vector2 = _nav_agent.get_next_path_position()
			var dir: Vector2 = (next_pos - global_position).normalized()
			_nav_agent.set_velocity(dir * move_speed)
	else:
		_nav_agent.set_velocity(Vector2.ZERO)
		velocity = Vector2.ZERO
		move_and_slide()


# --- Interacción con SmartObject ---

func _begin_interaction(target: SmartObject) -> void:
	_state = AgentState.INTERACTING
	_reinforcer.record_before(_current_action, chemical_profile)
	var accepted: bool = target.request_interaction(self)
	if not accepted:
		_return_to_wander()
		_selector.evaluate_now()


func _on_interaction_completed(_agent: BaseAgent) -> void:
	_reinforcer.evaluate_after(chemical_profile)
	_state = AgentState.WANDERING
	_current_target = null
	_current_action = &""
	_wander.start(global_position)


func _on_interaction_cancelled(_agent: BaseAgent) -> void:
	_state = AgentState.WANDERING
	_current_target = null
	_current_action = &""
	_wander.start(global_position)


# --- Cortejo ---

func _check_libido() -> void:
	pass  # Manejado por ActionSelector niveles 2 y 3

func _on_courtship_ended() -> void:
	if _state == AgentState.COURTING:
		_return_to_wander()


func _on_partner_found(partner: BaseAgent) -> void:
	_nav_agent.target_position = partner.global_position


# --- Decisiones (ActionSelector) ---

func _on_action_chosen(action: StringName, target: SmartObject) -> void:
	if _state != AgentState.WANDERING:
		return
	if _companion.is_assisting:
		return

	_current_action = action
	if action == &"wander" or target == null:
		_wander.start(global_position)
		return

	var chemical: StringName = ActionSelector.ACTION_TO_CHEMICAL.get(action, &"")
	if chemical != &"":
		_companion.notify_action_started(target, chemical)

	_current_target = target
	_wander.stop()
	_state = AgentState.NAVIGATING_TO_OBJECT
	_nav_agent.target_position = target.global_position
	if not target.interaction_completed.is_connected(_on_interaction_completed):
		target.interaction_completed.connect(_on_interaction_completed)
	if not target.interaction_cancelled.is_connected(_on_interaction_cancelled):
		target.interaction_cancelled.connect(_on_interaction_cancelled)


func _on_no_action_available(_action: StringName) -> void:
	if _state == AgentState.WANDERING:
		_wander.start(global_position)


func _on_reward_applied(action: StringName, chemical: StringName, delta: float) -> void:
	action_learned.emit(action, chemical, delta)


# --- Utilidades ---

func _return_to_wander() -> void:
	_state = AgentState.WANDERING
	_current_target = null
	_current_action = &""
	_wander.start(global_position)


func _agent_ref() -> BaseAgent:
	return self


func _connect_signals() -> void:
	_wander.new_destination_set.connect(func(_t: Vector2) -> void: pass)
	_selector.action_chosen.connect(_on_action_chosen)
	_selector.no_action_available.connect(_on_no_action_available)
	_selector.social_target_chosen.connect(_on_social_target_chosen)
	_selector.courtship_target_chosen.connect(_on_courtship_target_chosen)
	_selector.mating_triggered.connect(_on_mating_triggered)
	_reinforcer.reward_applied.connect(_on_reward_applied)

	_romance_node.courtship_attempt_started.connect(_on_courtship_attempt_started)
	_romance_node.courtship_succeeded.connect(_on_courtship_resolved)
	_romance_node.courtship_failed.connect(_on_courtship_resolved)
	_romance_node.bonding_completed.connect(
		func(partner: BaseAgent) -> void:
			EventLog.push("💑 %s y %s son pareja" % [
				identity.creature_name, partner.identity.creature_name
			])
	)
	_romance_node.mating_pleasure.connect(_on_mating_finished)
	_romance_node.mating_ready.connect(
	func(pa: BaseAgent, pb: BaseAgent) -> void:
		_on_mating_finished(pa, pb)
		get_tree().call_group("world", "on_mating_ready", pa, pb)
)

	_monitor.hunger_critical.connect(
		func(level: float) -> void: hunger_critical.emit(level)
	)
	_monitor.fatigue_critical.connect(
		func(level: float) -> void: fatigue_critical.emit(level)
	)
	_monitor.loneliness_critical.connect(
		func(level: float) -> void: loneliness_critical.emit(level)
	)
	_monitor.pain_critical.connect(
		func(level: float) -> void: pain_critical.emit(level)
	)
	_monitor.chemical_normalized.connect(
		func(chem_name: StringName) -> void: chemical_normalized.emit(chem_name)
	)
	became_adult.connect(func() -> void: _selector.evaluate_now())

func _on_mating_finished(_a: BaseAgent, _b: BaseAgent = null) -> void:
	if _state == AgentState.MATING:
		_state = AgentState.WANDERING
		_wander.start(global_position)

func _validate_setup() -> void:
	assert(chemical_profile != null, "BaseAgent: falta ChemicalProfile.")
	assert(brain != null,            "BaseAgent: falta BrainWeights.")
	assert(_wander != null,          "BaseAgent: falta WanderController.")
	assert(_monitor != null,         "BaseAgent: falta ChemicalMonitor.")
	assert(_selector != null,        "BaseAgent: falta ActionSelector.")
	assert(_reinforcer != null,      "BaseAgent: falta ReinforcementSystem.")
	assert(_nav_agent != null,       "BaseAgent: falta NavigationAgent2D.")
	assert(_memory_node != null,     "BaseAgent: falta SocialMemory.")
	assert(_romance_node != null,    "BaseAgent: falta RomanceController.")
	assert(_sensor != null,          "BaseAgent: falta SocialSensor.")
	assert(_selection != null,       "BaseAgent: falta SelectionComponent.")
	assert(_companion != null,       "BaseAgent: falta CompanionController.")
	
	assert(_sprite != null,          "BaseAgent: falta el nodo Sprite2D.")
	assert(_particles != null,       "BaseAgent: falta AgentParticles.")

	
func _on_creature_selected(creature: BaseAgent) -> void:            # [M3.6]
	_selection.set_selected(creature == self)

# — Métodos nuevos:

func _on_social_target_chosen(target: BaseAgent) -> void:
	if _state != AgentState.WANDERING:
		return
	_social_target = target
	_wander.stop()
	_state = AgentState.SOCIALIZING
	_nav_agent.target_position = target.global_position


func _apply_socializing_movement() -> void:
	if _social_target == null or not is_instance_valid(_social_target):
		_return_to_wander()
		return

	var dist: float = global_position.distance_to(_social_target.global_position)

	if dist <= 50.0:
		var delta: float = get_physics_process_delta_time()

		chemical_profile.set_level(&"loneliness",
			chemical_profile.loneliness - 8.0 * delta)

		var my_id: int = get_instance_id()
		var target_id: int = _social_target.get_instance_id()

		_memory_node.adjust_affinity(target_id, _memory_node.affinity_gain_per_contact * delta)
		_social_target.memory.adjust_affinity(my_id, _memory_node.affinity_gain_per_contact * delta)

		velocity = Vector2.ZERO
		move_and_slide()

		if chemical_profile.loneliness <= 20.0:
			_memory_node.start_affinity_cooldown(target_id)
			_particles.emit_socialize()          # [NUEVO]
			if is_instance_valid(_social_target):
				_social_target._particles.emit_socialize()  # [NUEVO] en ambos
			EventLog.push("%s y %s socializaron" % [
				identity.creature_name, _social_target.identity.creature_name
			])
			_social_target = null
			_return_to_wander()
		return

	# [FIX] Si se alejaron del rango (por colisión física u otra causa),
	# siempre reasignamos el target_position para forzar recálculo de ruta,
	# en vez de confiar en is_navigation_finished() que puede haber quedado
	# "true" desde el primer acercamiento.
	_nav_agent.target_position = _social_target.global_position

	if _nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var dir: Vector2 = (next_pos - global_position).normalized()
	_nav_agent.set_velocity(dir * move_speed)

func _apply_body_scale() -> void:
	scale = Vector2(body_scale, body_scale)

	# El radio de detección social también crece con el tamaño,
	# para que criaturas grandes "sientan" antes a otras
	if _sensor != null:
		_sensor.detection_radius *= body_scale

	if _selection != null:
		_selection.indicator_radius *= body_scale
		

func _check_survival_interruption() -> void:
	if _state == AgentState.INTERACTING:
		return  # Nunca interrumpir una interacción ya iniciada con un objeto
	if _state == AgentState.WANDERING or _state == AgentState.NAVIGATING_TO_OBJECT:
		return  # El ActionSelector ya maneja estas prioridades

	var fatigue_critical: bool = chemical_profile.fatigue >= _selector.survival_fatigue_threshold
	var hunger_critical: bool  = chemical_profile.hunger  >= _selector.survival_hunger_threshold

	if fatigue_critical or hunger_critical:
		_cancel_social_state()
		_selector.evaluate_now()

func _cancel_social_state() -> void:
	match _state:
		AgentState.COURTING, AgentState.COURTING_ACTIVE:
			_romance_node.end_courtship()
			_courtship_target = null
		AgentState.MATING:
			_romance_node.end_bonding()
		AgentState.SOCIALIZING:
			_social_target = null
	_return_to_wander()

func _apply_courting_movement() -> void:
	if _courtship_target == null or not is_instance_valid(_courtship_target):
		_romance_node.end_courtship()
		_return_to_wander()
		return

	var dist: float = global_position.distance_to(_courtship_target.global_position)

	if dist <= _romance_node.bonding_radius:
		_state = AgentState.COURTING_ACTIVE
		_romance_node.start_courtship_timer()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# El receptor se queda completamente quieto
	if not _romance_node.is_pursuer:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# El perseguidor usa velocidad aumentada
	_nav_agent.target_position = _courtship_target.global_position

	if _nav_agent.is_navigation_finished():
		_nav_agent.target_position = global_position
		_nav_agent.target_position = _courtship_target.global_position
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var dir: Vector2 = (next_pos - global_position).normalized()
	_nav_agent.set_velocity(dir * move_speed * courtship_pursue_speed_multiplier)

func _on_courtship_target_chosen(target: BaseAgent) -> void:
	# Si ya estamos cortejando a este mismo objetivo, no interrumpir ni resetear roles
	if _state == AgentState.COURTING and _courtship_target == target:
		return
	if _state == AgentState.COURTING_ACTIVE and _courtship_target == target:
		return
	if _state != AgentState.WANDERING:
		return

	_courtship_target = target
	_romance_node.current_partner = target
	_romance_node.is_courting = true
	_romance_node._courtship_timer = 0.0

	# Negociar rol solo una vez al inicio
	if target.romance.is_courting and target.romance.current_partner == self:
		_romance_node.is_pursuer = randf() < 0.5
		target.romance.is_pursuer = not _romance_node.is_pursuer
	else:
		_romance_node.is_pursuer = true

	_wander.stop()
	_state = AgentState.COURTING

	EventLog.push("%s va a cortejar a %s (%s)" % [
		identity.creature_name,
		target.identity.creature_name,
		"persigue" if _romance_node.is_pursuer else "espera",
	])

func _on_courtship_attempt_started(_target: BaseAgent) -> void:
	pass  # El estado ya lo maneja _apply_courting_movement al llegar al radio


func _on_courtship_resolved(_target: BaseAgent) -> void:
	_state = AgentState.WANDERING
	_courtship_target = null
	_romance_node.is_courting = false
	_wander.start(global_position)


func _on_mating_triggered() -> void:
	if _state != AgentState.WANDERING:
		return
	if not _romance_node.try_begin_mating():
		return

	_state = AgentState.MATING
	_wander.stop()
	_companion.is_assisting = false  # Cancelar acompañamiento activo si lo había

	EventLog.push("💞 %s busca a %s para aparearse" % [
		identity.creature_name,
		_romance_node.bonded_partner.identity.creature_name \
		if _romance_node.bonded_partner != null else "?"
	])

func _apply_courting_active() -> void:
	if _courtship_target == null or not is_instance_valid(_courtship_target):
		_romance_node.end_courtship()
		_return_to_wander()
		return

	var dist: float = global_position.distance_to(_courtship_target.global_position)

	if dist > _romance_node.bonding_radius:
		# Se alejaron (colisión física u otro agente los separó): volver a navegar
		_state = AgentState.COURTING
		return

	# En rango: ejecutar timer del cortejo
	_romance_node._tick_courtship(get_physics_process_delta_time())

	velocity = Vector2.ZERO
	move_and_slide()

func _apply_mating_movement() -> void:
	var partner: BaseAgent = _romance_node.bonded_partner
	if partner == null or not is_instance_valid(partner):
		_romance_node.end_bonding()
		_return_to_wander()
		return

	# Si somos el que inició (is_bonding fue true primero aquí), navegamos.
	# La pareja ya está quieta porque try_begin_mating() la detuvo.
	var dist: float = global_position.distance_to(partner.global_position)

	if dist <= _romance_node.bonding_radius:
		# Llegamos: ambos quietos, el timer de bonding corre en _physics_process
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Navegar hacia la pareja
	_nav_agent.target_position = partner.global_position
	if _nav_agent.is_navigation_finished():
		_nav_agent.target_position = global_position
		_nav_agent.target_position = partner.global_position
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var dir: Vector2 = (next_pos - global_position).normalized()
	_nav_agent.set_velocity(dir * move_speed)
