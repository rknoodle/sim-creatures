# social_memory.gd
# Módulo 3.7: añade estados de relación explícitos (Relationship enum).
class_name SocialMemory
extends Node

enum Relationship { STRANGER, ACQUAINTANCE, FRIEND, PARTNER }

signal affinity_changed(agent_id: int, new_affinity: float)
signal new_agent_met(agent_id: int, agent_name: String)
signal relationship_changed(agent_id: int, new_relationship: Relationship)

const AFFINITY_MIN: float = -100.0
const AFFINITY_MAX: float = 100.0
const AFFINITY_BASE: float = 0.0
#const AFFINITY_GAIN_COOLDOWN: float = 30.0 ## Segundos que deben pasar entre ganancias de afinidad con el mismo agente.

const FRIEND_THRESHOLD: float = 40.0
const ACQUAINTANCE_THRESHOLD: float = 10.0

@export var affinity_gain_cooldown: float = 30.0   # configurable desde Inspector
@export var affinity_gain_per_contact: float = 2.0 # tasa de ganancia por segundo

# { instance_id: int -> { "name": String, "affinity": float, "relationship": Relationship } }
var social_memory: Dictionary = {}
var _affinity_cooldowns: Dictionary = {}

var _owner_agent: BaseAgent = null


func initialize_for(agent: BaseAgent) -> void:
	_owner_agent = agent


func meet(agent: BaseAgent) -> bool:
	var agent_id: int = agent.get_instance_id()
	if social_memory.has(agent_id):
		return false
	social_memory[agent_id] = {
		"name":          agent.identity.creature_name,
		"affinity":      AFFINITY_BASE,
		"relationship":  Relationship.STRANGER,
		"met_at_unix":   Time.get_unix_time_from_system(),   # [NUEVO]
	}
	new_agent_met.emit(agent_id, agent.identity.creature_name)
	return true


func adjust_affinity(agent_id: int, delta: float) -> void:
	if not social_memory.has(agent_id):
		return

	if delta > 0.0:
		var cooldown: float = _affinity_cooldowns.get(agent_id, 0.0)
		if cooldown > 0.0:
			return

	var current: float = social_memory[agent_id]["affinity"]
	var next: float = clampf(current + delta, AFFINITY_MIN, AFFINITY_MAX)
	social_memory[agent_id]["affinity"] = next
	affinity_changed.emit(agent_id, next)
	_recalculate_relationship(agent_id)


func get_affinity(agent_id: int) -> float:
	if not social_memory.has(agent_id):
		return AFFINITY_BASE
	return social_memory[agent_id]["affinity"]


func get_relationship(agent_id: int) -> Relationship:
	if not social_memory.has(agent_id):
		return Relationship.STRANGER
	return social_memory[agent_id]["relationship"]


## Fuerza el estado de relación manualmente (usado para PARTNER tras mating).
func set_relationship(agent_id: int, relationship: Relationship) -> void:
	if not social_memory.has(agent_id):
		return
	social_memory[agent_id]["relationship"] = relationship
	relationship_changed.emit(agent_id, relationship)


## Devuelve el id del agente con relación PARTNER, o -1 si no existe.
func get_partner_id() -> int:
	for agent_id: int in social_memory:
		if social_memory[agent_id]["relationship"] == Relationship.PARTNER:
			return agent_id
	return -1


func get_most_affine_id() -> int:
	var best_id: int = -1
	var best_affinity: float = -INF
	for agent_id: int in social_memory:
		var affinity: float = social_memory[agent_id]["affinity"]
		if affinity > best_affinity:
			best_affinity = affinity
			best_id = agent_id
	return best_id


func get_entry(agent_id: int) -> Dictionary:
	return social_memory.get(agent_id, {})


func has_agent(agent_id: int) -> bool:
	return social_memory.has(agent_id)


## Recalcula el estado de relación según afinidad, sin sobrescribir PARTNER.
func _recalculate_relationship(agent_id: int) -> void:
	var entry: Dictionary = social_memory[agent_id]
	if entry["relationship"] == Relationship.PARTNER:
		return  # PARTNER es un estado permanente, no se degrada automáticamente

	var affinity: float = entry["affinity"]
	var new_relationship: Relationship

	if affinity >= FRIEND_THRESHOLD:
		new_relationship = Relationship.FRIEND
	elif affinity >= ACQUAINTANCE_THRESHOLD:
		new_relationship = Relationship.ACQUAINTANCE
	else:
		new_relationship = Relationship.STRANGER

	if new_relationship != entry["relationship"]:
		set_relationship(agent_id, new_relationship)

# — Añadir esta variable y este método al final de social_memory.gd:

## Datos de memoria pendientes de reconciliar tras un load_game().
## Se aplican cuando el agente vuelve a detectar (por SocialSensor) a alguien con el mismo nombre.
var pending_restore: Array = []


func try_restore_pending(agent: BaseAgent) -> void:
	if pending_restore.is_empty():
		return
	for entry: Dictionary in pending_restore:
		if entry["name"] == agent.identity.creature_name:
			var agent_id: int = agent.get_instance_id()
			if not social_memory.has(agent_id):
				meet(agent)
			social_memory[agent_id]["affinity"] = entry["affinity"]
			set_relationship(agent_id, entry["relationship"] as Relationship)
			return

## Devuelve los segundos transcurridos desde que se conocieron, o 0.0 si no hay registro.
func get_acquaintance_time(agent_id: int) -> float:
	if not social_memory.has(agent_id):
		return 0.0
	var met_at: float = social_memory[agent_id].get("met_at_unix", 0.0)
	if met_at <= 0.0:
		return 0.0
	return Time.get_unix_time_from_system() - met_at
	
func _process(delta: float) -> void:
	for agent_id: int in _affinity_cooldowns.keys():
		_affinity_cooldowns[agent_id] = maxf(
			_affinity_cooldowns[agent_id] - delta, 0.0
		)
		
func start_affinity_cooldown(agent_id: int) -> void:
	_affinity_cooldowns[agent_id] = affinity_gain_cooldown

## Usar solo para eventos discretos (cortejo, bonding) no para acumulación continua.
func adjust_affinity_direct(agent_id: int, delta: float) -> void:
	if not social_memory.has(agent_id):
		return
	var current: float = social_memory[agent_id]["affinity"]
	var next: float = clampf(current + delta, AFFINITY_MIN, AFFINITY_MAX)
	social_memory[agent_id]["affinity"] = next
	affinity_changed.emit(agent_id, next)
	_recalculate_relationship(agent_id)
