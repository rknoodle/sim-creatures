# romance_controller.gd — Módulo separado: Cortejo (amigos) vs Apareamiento (pareja)
class_name RomanceController
extends Node

# --- Cortejo (entre amigos) ---
signal courtship_attempt_started(target: BaseAgent)
signal courtship_succeeded(target: BaseAgent)
signal courtship_failed(target: BaseAgent)

# --- Apareamiento (entre parejas) ---
signal mating_pleasure(agent_a: BaseAgent, agent_b: BaseAgent)
signal mating_ready(parent_a: BaseAgent, parent_b: BaseAgent)

# --- General ---
signal partner_found(partner: BaseAgent)
signal partner_lost
signal bonding_completed(partner: BaseAgent)

@export var libido_courtship_threshold: float = 50.0  # líbido mínima para cortejar
@export var libido_mating_threshold: float = 80.0     # líbido mínima para aparearse
@export var courtship_duration: float = 5.0           # segundos de cortejo antes del resultado
@export var courtship_success_chance: float = 0.50    # 50/50
@export var affinity_on_success: float = 15.0
@export var affinity_on_failure: float = -10.0

@export var bonding_radius: float = 40.0
@export var bonding_time_required: float = 8.0
@export var bonding_affinity_rate: float = 5.0
@export var bonding_relief_rate: float = 3.0

@export var minimum_acquaintance_time: float = 25.0
@export var reproduction_health_threshold: float = 30.0
@export var base_reproduction_chance: float = 0.35

# Pareja permanente vinculada
var bonded_partner: BaseAgent = null

# Estado de cortejo activo
var is_courting: bool = false
var current_partner: BaseAgent = null

# Estado de bonding (entre parejas)
var is_bonding: bool = false

## true = este agente persigue al objetivo.
## false = este agente espera quieto a que el otro llegue.
var is_pursuer: bool = true

var _courtship_timer: float = 0.0
var _bonding_timer: float = 0.0
var _agent: BaseAgent
var _memory: SocialMemory


func _ready() -> void:
	_agent = get_parent() as BaseAgent
	assert(_agent != null, "RomanceController: debe ser hijo de BaseAgent.")


func initialize(memory: SocialMemory) -> void:
	_memory = memory


func _physics_process(delta: float) -> void:
	if is_bonding:
		_tick_bonding(delta)


# ─── API pública ──────────────────────────────────────────────────────────────

## Intenta iniciar cortejo con un amigo elegible. Devuelve false si no hay candidato.
func try_begin_courtship() -> bool:
	if is_courting or is_bonding:
		return false
	var candidate: BaseAgent = _find_best_courtship_candidate()
	if candidate == null:
		return false

	# Si el candidato ya nos está cortejando a nosotros, negociar roles:
	# uno persigue, el otro espera. Se decide al azar solo una vez.
	if candidate.romance.is_courting and candidate.romance.current_partner == _agent:
		is_pursuer = randf() < 0.5
		candidate.romance.is_pursuer = not is_pursuer
	else:
		is_pursuer = true  # Por defecto perseguimos si el otro no nos corteja aún

	is_courting = true
	current_partner = candidate
	_courtship_timer = 0.0
	return true

## Intenta iniciar apareamiento con la pareja vinculada. Devuelve false si no aplica.
func try_begin_mating() -> bool:
	if is_courting or is_bonding:
		return false
	if bonded_partner == null or not is_instance_valid(bonded_partner):
		return false
	# Notificar a la pareja para que también entre en estado MATING y se detenga
	if not bonded_partner.romance.is_bonding:
		bonded_partner.romance.is_bonding = true
		bonded_partner.romance.current_partner = _agent
		bonded_partner._state = BaseAgent.AgentState.MATING
		bonded_partner._wander.stop()

	is_bonding = true
	current_partner = bonded_partner
	_bonding_timer = 0.0
	return true

func end_courtship() -> void:
	is_courting = false
	current_partner = null
	_courtship_timer = 0.0


func end_bonding() -> void:
	is_bonding = false
	current_partner = null
	_bonding_timer = 0.0


func has_eligible_courtship_candidate() -> bool:
	return _find_best_courtship_candidate() != null


func has_eligible_mating_partner() -> bool:
	if bonded_partner == null or not is_instance_valid(bonded_partner):
		return false
	var dist: float = _agent.global_position.distance_to(bonded_partner.global_position)
	return dist <= bonding_radius * 2.0


# ─── Cortejo (amigos → posible pareja) ───────────────────────────────────────

func _tick_courtship(delta: float) -> void:
	if current_partner == null or not is_instance_valid(current_partner):
		end_courtship()
		return

	# Aliviar soledad y líbido mientras dura el cortejo activo
	_agent.chemical_profile.set_level(&"loneliness",
		_agent.chemical_profile.loneliness - 5.0 * delta)
	_agent.chemical_profile.set_level(&"libido",
		_agent.chemical_profile.libido - 3.0 * delta)

	_courtship_timer += delta
	if _courtship_timer >= courtship_duration:
		_resolve_courtship()


func _resolve_courtship() -> void:
	var target: BaseAgent = current_partner
	if target == null or not is_instance_valid(target):
		end_courtship()
		return

	var target_id: int = target.get_instance_id()
	var my_id: int = _agent.get_instance_id()

	var success: bool = randf() < courtship_success_chance

	if success:
		# El cortejo exitoso ignora el cooldown de afinidad — es un evento especial
		_memory.adjust_affinity_direct(target_id, affinity_on_success)
		target.memory.adjust_affinity_direct(my_id, affinity_on_success)
		courtship_succeeded.emit(target)
		EventLog.push("💕 %s y %s (cortejo exitoso +%.0f afinidad)" % [
			_agent.identity.creature_name,
			target.identity.creature_name,
			affinity_on_success,
		])
		_check_partner_promotion(target)
	else:
		_memory.adjust_affinity_direct(target_id, affinity_on_failure)
		target.memory.adjust_affinity_direct(my_id, affinity_on_failure)
		courtship_failed.emit(target)
		EventLog.push("💔 %s rechazó a %s (cortejo fallido %.0f afinidad)" % [
			target.identity.creature_name,
			_agent.identity.creature_name,
			affinity_on_failure,
		])

	# Cooldown post-cortejo para evitar cortejo inmediato de nuevo
	_memory.start_affinity_cooldown(target_id)
	target.memory.start_affinity_cooldown(my_id)

	end_courtship()

func _check_partner_promotion(target: BaseAgent) -> void:
	# Solo el agente que inició el cortejo promueve la relación,
	# evitando que ambos lados lo hagan simultáneamente.
	if bonded_partner == target:
		return  # Ya son pareja, no repetir

	var target_id: int = target.get_instance_id()
	var my_id: int = _agent.get_instance_id()
	var affinity: float = _memory.get_affinity(target_id)
	var acquaintance_time: float = _memory.get_acquaintance_time(target_id)

	if affinity >= 75.0 and acquaintance_time >= minimum_acquaintance_time:
		bonded_partner = target
		target.romance.bonded_partner = _agent
		_memory.set_relationship(target_id, SocialMemory.Relationship.PARTNER)
		target.memory.set_relationship(my_id, SocialMemory.Relationship.PARTNER)
		bonding_completed.emit(target)

# ─── Apareamiento (entre parejas) ────────────────────────────────────────────

func _tick_bonding(delta: float) -> void:
	if current_partner == null or not is_instance_valid(current_partner):
		end_bonding()
		return
	_bonding_timer += delta
	if _bonding_timer >= bonding_time_required:
		_trigger_mating()

func _trigger_mating() -> void:
	# Capturar referencias ANTES de cualquier end_bonding()
	var partner: BaseAgent = current_partner
	if partner == null or not is_instance_valid(partner):
		end_bonding()
		return

	var partner_id: int = partner.get_instance_id()
	var my_id: int = _agent.get_instance_id()

	# Coste energético
	_agent.chemical_profile.set_level(&"fatigue",
		_agent.chemical_profile.fatigue + 25.0)
	partner.chemical_profile.set_level(&"fatigue",
		partner.chemical_profile.fatigue + 25.0)

	# Vaciar líbido en ambos ANTES de end_bonding
	_agent.chemical_profile.set_level(&"libido", 0.0)
	partner.chemical_profile.set_level(&"libido", 0.0)

	# Ganancia de afinidad por apareamiento (siempre, independiente del resultado)
	_memory.adjust_affinity_direct(partner_id, 10.0)
	partner.memory.adjust_affinity_direct(my_id, 10.0)

	if _check_reproduction_conditions(partner):
		mating_ready.emit(_agent, partner)
		EventLog.push("🥚 %s y %s concibieron descendencia" % [
			_agent.identity.creature_name, partner.identity.creature_name
		])
	else:
		mating_pleasure.emit(_agent, partner)
		EventLog.push("✨ %s y %s se aparearon por placer" % [
			_agent.identity.creature_name, partner.identity.creature_name
		])

	# Terminar bonding en ambos DESPUÉS de aplicar todos los efectos
	end_bonding()
	if is_instance_valid(partner) and partner.romance.is_bonding:
		partner.romance.end_bonding()

func _check_reproduction_conditions(partner: BaseAgent) -> bool:
	var my_ok: bool = (
		_agent.chemical_profile.pain    < reproduction_health_threshold and
		_agent.chemical_profile.hunger  < reproduction_health_threshold and
		_agent.chemical_profile.fatigue < reproduction_health_threshold
	)
	var partner_ok: bool = (
		partner.chemical_profile.pain    < reproduction_health_threshold and
		partner.chemical_profile.hunger  < reproduction_health_threshold and
		partner.chemical_profile.fatigue < reproduction_health_threshold
	)
	return my_ok and partner_ok and randf() < base_reproduction_chance


# ─── Búsqueda de candidatos ───────────────────────────────────────────────────

func _find_best_courtship_candidate() -> BaseAgent:
	var best_id: int = -1
	var best_affinity: float = -INF

	for agent_id: int in _memory.social_memory:
		var entry: Dictionary = _memory.social_memory[agent_id]

		# Solo amigos (no parejas ya establecidas, no desconocidos)
		if entry["relationship"] != SocialMemory.Relationship.FRIEND:
			continue

		var acquaintance_time: float = _memory.get_acquaintance_time(agent_id)
		if acquaintance_time < minimum_acquaintance_time:
			continue

		var candidate: BaseAgent = _find_agent_by_id(agent_id)
		if candidate == null:
			continue
		if candidate.identity.gender == _agent.identity.gender:
			continue
		# Monogamia: no cortejar si cualquiera ya tiene pareja distinta
		if bonded_partner != null:
			continue
		if candidate.romance.bonded_partner != null:
			continue

		if entry["affinity"] > best_affinity:
			best_affinity = entry["affinity"]
			best_id = agent_id

	if best_id == -1:
		return null
	return _find_agent_by_id(best_id)


func _find_agent_by_id(instance_id: int) -> BaseAgent:
	for node: Node in get_tree().get_nodes_in_group("agents"):
		if node.get_instance_id() == instance_id:
			return node as BaseAgent
	return null

func start_courtship_timer() -> void:
	_courtship_timer = 0.0
