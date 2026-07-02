# save_manager.gd
# Singleton de guardado/carga en JSON con soporte de múltiples slots.
#class_name SaveManager
extends Node

signal game_saved(slot_id: String)
signal game_loaded(slot_id: String)
signal save_deleted(slot_id: String)
signal slots_refreshed

const SAVE_DIR: String = "user://saves/"

var _world_time_elapsed: float = 0.0


func _process(delta: float) -> void:
	_world_time_elapsed += delta


## Devuelve metadatos de todos los slots existentes, ordenados por fecha descendente.
## Cada entrada: { "slot_id": String, "display_name": String, "timestamp": String, "agent_count": int }
func list_slots() -> Array[Dictionary]:
	_ensure_save_dir()
	var result: Array[Dictionary] = []

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var slot_id: String = file_name.trim_suffix(".json")
			var meta: Dictionary = _read_slot_metadata(slot_id)
			if not meta.is_empty():
				result.append(meta)
		file_name = dir.get_next()
	dir.list_dir_end()

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["saved_at_unix"] > b["saved_at_unix"]
	)
	return result


func save_game(slot_id: String, display_name: String = "") -> bool:
	_ensure_save_dir()

	var agents: Array[BaseAgent] = _get_all_agents()
	var agents_data: Array = []
	for agent: BaseAgent in agents:
		agents_data.append(_serialize_agent(agent))

	var final_display_name: String = display_name if display_name != "" else slot_id

	var save_data: Dictionary = {
		"meta": {
			"display_name": final_display_name,
			"saved_at_unix": Time.get_unix_time_from_system(),
			"saved_at_readable": Time.get_datetime_string_from_system(),
			"agent_count": agents.size(),
		},
		"world": {
			"time_elapsed": _world_time_elapsed,
		},
		"agents": agents_data,
	}

	var path: String = _slot_path(slot_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: no se pudo escribir '%s'." % path)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	game_saved.emit(slot_id)
	slots_refreshed.emit()
	EventLog.push("Partida guardada en '%s' (%d criaturas)" % [final_display_name, agents.size()])
	return true


func load_game(slot_id: String) -> bool:
	var path: String = _slot_path(slot_id)
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: no existe el slot '%s'." % slot_id)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: no se pudo leer '%s'." % path)
		return false

	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if parsed == null or not (parsed is Dictionary):
		push_error("SaveManager: el slot '%s' está corrupto." % slot_id)
		return false

	var save_data: Dictionary = parsed as Dictionary
	_world_time_elapsed = save_data.get("world", {}).get("time_elapsed", 0.0)

	var agents: Array[BaseAgent] = _get_all_agents()
	var agents_data: Array = save_data.get("agents", [])

	var count: int = mini(agents.size(), agents_data.size())
	for i: int in range(count):
		_deserialize_agent(agents[i], agents_data[i])

	_reconcile_relationships(agents)    # [NUEVO] — fuerza la restauración inmediata

	var display_name: String = save_data.get("meta", {}).get("display_name", slot_id)
	game_loaded.emit(slot_id)
	EventLog.push("Partida '%s' cargada (%d criaturas)" % [display_name, count])
	return true


func delete_save(slot_id: String) -> bool:
	var path: String = _slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return false
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	var err: Error = dir.remove(slot_id + ".json")
	if err != OK:
		push_error("SaveManager: error al eliminar slot '%s'." % slot_id)
		return false
	save_deleted.emit(slot_id)
	slots_refreshed.emit()
	EventLog.push("Partida '%s' eliminada" % slot_id)
	return true


func has_save(slot_id: String) -> bool:
	return FileAccess.file_exists(_slot_path(slot_id))


## Genera un slot_id único basado en timestamp, útil para "Guardar como nuevo".
func generate_new_slot_id() -> String:
	return "save_%d" % Time.get_unix_time_from_system()


func _slot_path(slot_id: String) -> String:
	return SAVE_DIR + slot_id + ".json"


func _ensure_save_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")


func _read_slot_metadata(slot_id: String) -> Dictionary:
	var file := FileAccess.open(_slot_path(slot_id), FileAccess.READ)
	if file == null:
		return {}
	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if parsed == null or not (parsed is Dictionary):
		return {}

	var data: Dictionary = parsed as Dictionary
	var meta: Dictionary = data.get("meta", {})
	return {
		"slot_id":          slot_id,
		"display_name":     meta.get("display_name", slot_id),
		"saved_at_readable": meta.get("saved_at_readable", "—"),
		"saved_at_unix":    meta.get("saved_at_unix", 0),
		"agent_count":      meta.get("agent_count", 0),
	}


func _get_all_agents() -> Array[BaseAgent]:
	var result: Array[BaseAgent] = []
	for node: Node in get_tree().get_nodes_in_group("agents"):
		var agent := node as BaseAgent
		if agent != null:
			result.append(agent)
	return result


func _serialize_agent(agent: BaseAgent) -> Dictionary:
	var memory_data: Array = []
	for agent_id: int in agent.memory.social_memory:
		var entry: Dictionary = agent.memory.social_memory[agent_id]
		memory_data.append({
			"name":         entry["name"],
			"affinity":     entry["affinity"],
			"relationship": int(entry["relationship"]),
			"met_at_unix":  entry.get("met_at_unix", Time.get_unix_time_from_system()),  # [NUEVO]
		})

	return {
		"name":         agent.identity.creature_name,
		"gender":       int(agent.identity.gender),
		"position_x":   agent.global_position.x,
		"position_y":   agent.global_position.y,
		"chemicals":    agent.chemical_profile.to_dict(),
		"age_stage":    int(agent._age_stage),
		"age_timer":    agent._age_timer,
		"social_memory": memory_data,
	}


func _deserialize_agent(agent: BaseAgent, data: Dictionary) -> void:
	agent.identity.creature_name = data.get("name", agent.identity.creature_name)
	agent.identity.gender = data.get("gender", int(agent.identity.gender)) as IdentityData.Gender

	agent.global_position = Vector2(
		data.get("position_x", agent.global_position.x),
		data.get("position_y", agent.global_position.y)
	)

	agent.chemical_profile.from_dict(data.get("chemicals", {}))

	agent._age_stage = data.get("age_stage", int(agent._age_stage)) as BaseAgent.AgeStage
	agent._age_timer = data.get("age_timer", agent._age_timer)
	agent.chemical_profile.set_libido_active(agent._age_stage == BaseAgent.AgeStage.ADULT)

	agent.memory.pending_restore = data.get("social_memory", [])

# — Añadir este método nuevo a save_manager.gd:

## Tras cargar todos los agentes, fuerza la reconciliación de memoria social
## y bonded_partner sin depender de que el SocialSensor los vuelva a detectar.
func _reconcile_relationships(agents: Array[BaseAgent]) -> void:
	for agent: BaseAgent in agents:
		if agent.memory.pending_restore.is_empty():
			continue
		for entry: Dictionary in agent.memory.pending_restore:
			var match_agent: BaseAgent = _find_agent_by_name(agents, entry["name"])
			if match_agent == null or match_agent == agent:
				continue

			var target_id: int = match_agent.get_instance_id()
			if not agent.memory.has_agent(target_id):
				agent.memory.meet(match_agent)

			agent.memory.social_memory[target_id]["affinity"] = entry["affinity"]
			agent.memory.social_memory[target_id]["met_at_unix"] = entry.get(
				"met_at_unix", Time.get_unix_time_from_system()
			)
			var relationship: SocialMemory.Relationship = entry["relationship"] as SocialMemory.Relationship
			agent.memory.set_relationship(target_id, relationship)

			if relationship == SocialMemory.Relationship.PARTNER:
				agent.romance.bonded_partner = match_agent

		agent.memory.pending_restore.clear()


func _find_agent_by_name(agents: Array[BaseAgent], creature_name: String) -> BaseAgent:
	for agent: BaseAgent in agents:
		if agent.identity.creature_name == creature_name:
			return agent
	return null
